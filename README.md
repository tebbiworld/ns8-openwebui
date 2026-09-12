# ns8-openwebui

A [NethServer 8](https://github.com/NethServer/ns8-core) module that runs
[Open WebUI](https://github.com/open-webui/open-webui) as a self-hosted AI chat
interface. It connects to an **external** [Ollama](https://github.com/ollama/ollama)
instance (for example one running directly on your Proxmox host) and supports
**Active Directory / LDAP** login.

Ollama is **not** bundled: only the Open WebUI front end runs on the node, which
keeps the module small and lets the inference host be sized and managed
independently (GPU, RAM, model storage).

## Architecture

A single rootless container:

| Container | Image | Port | Exposure |
| --- | --- | --- | --- |
| `openwebui` | `ghcr.io/open-webui/open-webui` | 8080 | published on the node loopback, fronted by Traefik (TLS/WebSocket) |

One allocated TCP port on the node loopback fronts the web interface. No
dedicated node IP is required. Open WebUI reaches your Ollama server over the
network via the configured `OLLAMA_BASE_URL`.

## Install

```
add-module ghcr.io/tebbiworld/openwebui:latest 1
```

## Settings

| Setting | Env var | Notes |
| --- | --- | --- |
| Host name | Traefik host + `WEBUI_URL` | FQDN the chat interface is published on. |
| Let's Encrypt certificate | (Traefik) | Request a valid certificate for the host. |
| HTTP to HTTPS redirection | (Traefik) | Redirect plain HTTP to HTTPS. |
| Ollama base URL | `OLLAMA_BASE_URL` | URL of your external Ollama, e.g. `http://10.0.0.5:11434`. Separate several with `;`. |
| Enable OpenAI-compatible API | `ENABLE_OPENAI_API` | Also allow OpenAI-compatible endpoints. |
| Interface name | `WEBUI_NAME` | Display name shown in the UI. |
| Allow self-registration | `ENABLE_SIGNUP` | Local account signup. The **first** account becomes admin. |
| Default role for new accounts | `DEFAULT_USER_ROLE` | `pending` (admin approval), `user`, or `admin`. Applies to first-login LDAP users too. |
| Timezone | `TZ` | e.g. `Europe/Berlin`. |

`WEBUI_SECRET_KEY` is generated once at install time and kept stable so login
sessions survive restarts.

### Active Directory / LDAP

Maps onto Open WebUI's native LDAP support. Enable it and provide your directory
details; users then log in with their AD/LDAP accounts.

| Setting | Env var | Notes |
| --- | --- | --- |
| LDAP URL | `LDAP_SERVER_HOST` / `LDAP_SERVER_PORT` / `LDAP_USE_TLS` | e.g. `ldaps://ad.example.org:636`; parsed into host, port and TLS flag. |
| Login button label | `LDAP_SERVER_LABEL` | Text on the LDAP login option. |
| Search base DN | `LDAP_SEARCH_BASE` | e.g. `DC=ad,DC=example,DC=org`. |
| Bind DN | `LDAP_APP_DN` | Service account used to search the directory. |
| Bind password | `LDAP_APP_PASSWORD` | Password of the service account (blank on save keeps the stored one). |
| Username attribute | `LDAP_ATTRIBUTE_FOR_USERNAME` | `sAMAccountName` (AD) or `uid` (OpenLDAP). |
| Mail attribute | `LDAP_ATTRIBUTE_FOR_MAIL` | Open WebUI requires every user to have an e-mail. Defaults to `mail`; on Active Directory where `mail` is empty, use `userPrincipalName`. |
| Search filter | `LDAP_SEARCH_FILTER` | Optional; restrict login, e.g. `(memberOf=CN=ai-users,...)`. |
| Validate LDAPS certificate | `LDAP_VALIDATE_CERT` | Off by default for internal CAs / self-signed certs. |

## First steps

1. Set the **Ollama base URL** to your external instance and save.
2. Open the published URL. The first account that logs in (local signup or the
   first AD/LDAP user) becomes the **administrator**.
3. Pick a model in the chat interface — models are pulled and run on your
   external Ollama host, not on this server.
4. Turn **self-registration** off once your users exist (not needed with LDAP).

## Storage

One rootless named volume survives container recreation:

* `openwebui-data` — mounted at `/app/backend/data`: SQLite database, uploaded
  files, RAG vector store, avatars and generated config.

## Notes

* Runtime settings, including the LDAP bind password and `WEBUI_SECRET_KEY`, are
  written to `state/openwebui.env` and passed to the container with `--env-file`.
* The image tracks the upstream moving tag `open-webui:main`. Pin it in
  `build-images.sh` for fully reproducible deployments.
* The node must be able to reach the Ollama host on its API port (default
  `11434`).
* The container runs in the host network namespace and binds only
  `127.0.0.1:<allocated port>`. This is deliberate: with the rootless default
  network a container cannot reach services on its **own node's IP** (the
  address is mirrored into the container), which broke LDAP login and Ollama
  access whenever the domain controller or Ollama runs on the same node.
