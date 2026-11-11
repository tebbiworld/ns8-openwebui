*** Settings ***
Library     SSHLibrary
Resource    api.resource

*** Test Cases ***
Seed probe data
    # A plain file in the volume (restored by restic's file restore) ...
    Run on node    runagent -m ${module_id} podman exec openwebui sh -c 'echo pre-backup > /app/backend/data/ci_probe.txt'
    # ... and a row inside the SQLite database, which this module backs up as a
    # consistent snapshot (module-dump-state) and restores with 40restore_db.
    Run on node    runagent -m ${module_id} podman exec openwebui python3 -c "import sqlite3; c=sqlite3.connect('/app/backend/data/webui.db'); c.execute('CREATE TABLE IF NOT EXISTS ci_probe (v TEXT)'); c.execute('INSERT INTO ci_probe VALUES (?)', ('db-pre-backup',)); c.commit(); c.close()"

Back up the module
    ${repo}    ${path} =    Back up the module to the cluster repository    ${module_id}
    Set Global Variable    ${BACKUP_REPO}    ${repo}
    Set Global Variable    ${BACKUP_PATH}    ${path}

Free the memory of the first instance
    Run on node    runagent -m ${module_id} systemctl --user stop openwebui.service

Restore into a new instance
    ${rid} =    Restore the module from the cluster repository    ${BACKUP_REPO}    ${BACKUP_PATH}
    Set Global Variable    ${restored_id}    ${rid}
    Should Not Be Equal    ${restored_id}    ${module_id}

The restored instance has data, settings and secrets
    ${out} =    Wait Until Keyword Succeeds    60 times    10 seconds
    ...    Run on node    runagent -m ${restored_id} podman exec openwebui cat /app/backend/data/ci_probe.txt
    Should Contain    ${out}    pre-backup
    # Content that lives only in the database: proves the snapshot taken by
    # module-dump-state was restored over the volume copy by 40restore_db.
    ${db} =    Run on node    runagent -m ${restored_id} podman exec openwebui python3 -c "import sqlite3; print(sqlite3.connect('/app/backend/data/webui.db').execute('SELECT v FROM ci_probe').fetchone()[0])"
    Should Contain    ${db}    db-pre-backup
    ${cfg} =    Run task    module/${restored_id}/get-configuration    {}
    Should Be Equal    ${cfg['webui_name']}    CI WebUI
    Should Be True    ${cfg['ldap_bind_password_set']}
    Secrets are kept out of the module environment    ${restored_id}
    ${a} =    Run on node    runagent -m ${module_id} bash -c 'grep ^WEBUI_SECRET_KEY= "$AGENT_STATE_DIR/passwords.env" | sha256sum'
    ${b} =    Run on node    runagent -m ${restored_id} bash -c 'grep ^WEBUI_SECRET_KEY= "$AGENT_STATE_DIR/passwords.env" | sha256sum'
    Should Be Equal    ${a}    ${b}

module-dump-state snapshots the database when the instance is stopped
    [Documentation]    state-include.conf always lists state/webui.db, so the
    ...                dump hook must produce a valid snapshot even with the
    ...                container stopped (it was stopped above); a missing file
    ...                would make restic abort the whole backup.
    ${head} =    Run on node    runagent -m ${module_id} bash -c 'cd "$AGENT_STATE_DIR" && module-dump-state && head -c 15 webui.db'
    Should Contain    ${head}    SQLite format 3
    Run on node    runagent -m ${module_id} bash -c 'cd "$AGENT_STATE_DIR" && module-cleanup-state'
