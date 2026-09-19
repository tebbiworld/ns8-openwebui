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
    Run on node    api-cli run update-module --data '{"force":true,"module_url":"${IMAGE_URL}","instances":["${module_id}"]}'
    Wait Until Keyword Succeeds    90 times    10 seconds    Application config is served

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

*** Keywords ***
Application config is served
    ${out} =    Run on node    curl -fsSk -H 'Host: openwebui.ci.test' https://127.0.0.1/api/config
    Should Contain    ${out}    CI WebUI
