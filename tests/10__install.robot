*** Settings ***
Library     SSHLibrary
Resource    api.resource

*** Variables ***
${CONFIG}    {"host":"openwebui.ci.test","lets_encrypt":false,"http2https":true,"webui_name":"CI WebUI","ollama_base_url":"http://127.0.0.1:11434","enable_signup":true,"default_user_role":"pending","enable_openai_api":false,"timezone":"Europe/Berlin","ldap_enabled":true,"ldap_label":"CI LDAP","ldap_url":"ldaps://ldap.ci.test:636","ldap_base_dn":"dc=ci,dc=test","ldap_bind_dn":"cn=reader,dc=ci,dc=test","ldap_bind_password":"Bind#Pass 1","ldap_user_attribute":"uid","ldap_mail_attribute":"mail","ldap_search_filter":"","ldap_validate_cert":false}

*** Test Cases ***
Install the module
    IF    '${SCENARIO}' == 'update'
        ${output}  ${rc} =    Execute Command    add-module ${UPDATE_FROM} 1    return_rc=True
    ELSE
        ${output}  ${rc} =    Execute Command    add-module ${IMAGE_URL} 1    return_rc=True
    END
    Should Be Equal As Integers    ${rc}  0
    &{output} =    Evaluate    ${output}
    Set Global Variable    ${module_id}    ${output.module_id}

Configure the module
    Run task    module/${module_id}/configure-module    ${CONFIG}    decode_json=${FALSE}

Open WebUI answers behind Traefik
    Wait Until Keyword Succeeds    90 times    10 seconds    Application config is served

Update to the image under test
    Skip If    '${SCENARIO}' != 'update'    scenario is ${SCENARIO}
    # Up to 1.1.x Open WebUI took its settings from openwebui.env at every
    # start; a line appended by hand is taken over into the database by the
    # update. From 1.2.0 the database holds the settings and the line has no
    # effect any more, so the check only applies when updating from 1.1.x.
    ${from} =    Evaluate    tuple(int(x) for x in "${UPDATE_FROM}".rsplit(":", 1)[1].split("."))
    Run on node    runagent -m ${module_id} bash -c 'echo CHUNK_SIZE=1234 >> "$AGENT_STATE_DIR/openwebui.env"'
    Run on node    api-cli run update-module --data '{"force":true,"module_url":"${IMAGE_URL}","instances":["${module_id}"]}'
    Wait Until Keyword Succeeds    90 times    10 seconds    Application config is served
    ${chunk_size} =    Config value    rag.chunk_size
    IF    ${from} < (1, 2, 0)
        Should Be Equal    ${chunk_size}    1234
    ELSE
        Should Be Equal    ${chunk_size}    1000
    END

Configuration reads back
    ${cfg} =    Run task    module/${module_id}/get-configuration    {}
    Should Be Equal    ${cfg['host']}    openwebui.ci.test
    Should Be Equal    ${cfg['webui_name']}    CI WebUI
    Should Be True    ${cfg['ldap_enabled']}
    Should Be True    ${cfg['ldap_bind_password_set']}

The container receives the bind password
    ${out} =    Run on node    runagent -m ${module_id} podman exec openwebui printenv LDAP_APP_PASSWORD
    Should Be Equal    ${out.strip()}    Bind#Pass 1

Secrets are stored in passwords.env only
    Secrets are kept out of the module environment    ${module_id}
    ${mode} =    Run on node    runagent -m ${module_id} bash -c 'stat -c \%a "$AGENT_STATE_DIR/openwebui.env"'
    Should Be Equal As Strings    ${mode.strip()}    600

Admin panel settings survive a restart, module settings win
    # One setting owned by the module, one owned by the Open WebUI admin panel
    Run on node    runagent -m ${module_id} podman exec openwebui python3 -c "import json, sqlite3; db = sqlite3.connect('/app/backend/data/webui.db'); db.execute('UPDATE config SET value = ? WHERE key = ?', (json.dumps('Changed'), 'ldap.server.label')); db.execute('UPDATE config SET value = ? WHERE key = ?', ('9', 'rag.top_k')); db.commit()"
    Run on node    runagent -m ${module_id} systemctl --user restart openwebui.service
    Wait Until Keyword Succeeds    90 times    10 seconds    Application config is served
    ${label} =    Config value    ldap.server.label
    Should Be Equal    ${label}    CI LDAP
    ${top_k} =    Config value    rag.top_k
    Should Be Equal    ${top_k}    9

*** Keywords ***
Application config is served
    ${out} =    Run on node    curl -fsSk -H 'Host: openwebui.ci.test' https://127.0.0.1/api/config
    Should Contain    ${out}    CI WebUI

Config value
    [Arguments]    ${key}
    ${out} =    Run on node    runagent -m ${module_id} podman exec openwebui python3 -c "import json, sqlite3; v = sqlite3.connect('/app/backend/data/webui.db').execute('SELECT value FROM config WHERE key = ?', ('${key}',)).fetchone()[0]; print(json.loads(v) if isinstance(v, str) else v)"
    RETURN    ${out.strip()}
