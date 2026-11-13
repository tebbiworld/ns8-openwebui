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
| Embedding engine | `RAG_EMBEDDING_ENGINE` | Knowledge-base base value. Empty = built-in model; `ollama` / `openai`. **Seed only — see below.** |
| Embedding model | `RAG_EMBEDDING_MODEL` | e.g. `bge-m3:latest` for the Ollama engine. **Seed only — see below.** |
| Top K | `RAG_TOP_K` | Passages retrieved per query (default 3). Seed only. |
| Chunk size | `CHUNK_SIZE` | Indexing chunk size (default 1000). Seed only. |
| Chunk overlap | `CHUNK_OVERLAP` | Overlap between chunks (default 100). Seed only. |

`WEBUI_SECRET_KEY` is generated once at install time and kept stable so login
sessions survive restarts.

Security defaults worth knowing:

* **Self-registration is off** (`ENABLE_SIGNUP=false`) unless you turn it on —
  Open WebUI itself defaults it *on*, so the module overrides that and resets it
  to the value on this page at every start. Leave it off when users log in via
  AD/LDAP.
* **Personal API keys are on** (`ENABLE_API_KEYS=true`, off by default upstream)
  so programmatic clients can authenticate. This is a cluster-wide switch: it
  lets **every** account mint API keys, not only an automation account. The keys
  are credentials; once the automation's key is issued, turn the feature off
  again in the admin panel if no interactive user needs it.
* **LDAP certificate validation is on** for an `ldaps://` server of its own
  (`LDAP_VALIDATE_CERT` follows the *Verify the server certificate* toggle,
  default on; the CA chain is checked, the host name is not pinned so an internal
  CA still works). It does not apply to a user domain reached through the node's
  `ldapproxy` on the loopback, or to a plain `ldap://` connection.

### Active Directory / LDAP

Enable the directory login and choose the source:

* **User domain of this cluster (recommended)** — pick a user domain that NS8
  already manages. No credentials are stored in the module: the connection
  (the node's `ldapproxy` on the loopback, the bind account) is read every time
  the service starts, so a rotated bind password or a moved domain controller is
  followed automatically. Optionally restrict login to the members of a group,
  chosen from a list (nested groups count). NS8 can also add an external AD/LDAP
  as a user domain, which then appears here too.
* **LDAP server of its own (advanced)** — enter the server URL, base DN, bind
  account and login attribute yourself. Use this only for a directory that is
  not a user domain of the cluster. The bind password is stored in
  `state/passwords.env` (mode 0600), never in the module environment.

This chooser is the same shared building block used by the other tebbiworld NS8
modules (ns8-clamav, ns8-idevice-backup). The module translates the chosen
settings into Open WebUI's native LDAP support; `bin/discover-ldap` writes them
to `state/ldap.env` before every start.

Two settings are specific to Open WebUI:

| Setting | Env var | Notes |
| --- | --- | --- |
| Login button label | `LDAP_SERVER_LABEL` | Text on the LDAP login option. |
| Mail attribute | `LDAP_ATTRIBUTE_FOR_MAIL` | Open WebUI requires every user to have an e-mail. Defaults to `mail`; on Active Directory where `mail` is empty, use `userPrincipalName`. |

Caveats of Open WebUI's native LDAP:

* **No StartTLS.** Open WebUI binds with `use_ssl` only, so a custom server must
  use an `ldaps://` URL; a `ldap://` + StartTLS combination is refused.
* **Group restriction** becomes a single `LDAP_SEARCH_FILTER`: the module
  resolves the group to its DN and builds a `memberOf` filter (nested on AD). If
  the group cannot be resolved, every login is refused (fail closed) rather than
  allowing everyone. For `rfc2307` the server needs the `memberof` overlay.

### Settings made in the Open WebUI admin panel

Since 1.2.0 everything changed in the Open WebUI **admin panel** is kept across
restarts, updates and backups (the embedding model under *Documents*, chunk
size, *Top K*, API keys, default model parameters, ...). Two groups of settings
behave differently:

* The **module-owned** settings (host, Ollama URL, sign-up, default role, LDAP,
  interface name) are reset to the values on the settings page before every
  start, so change them there, not in the admin panel (additional Ollama
  connections go into the Ollama base URL field, separated by `;`). The Ollama
  URL used for embeddings follows the Ollama base URL as well.
* The **knowledge-base base values** (embedding engine/model, Top K, chunk
  size/overlap) are *seed only*: the value on the settings page is applied when
  the instance is **first set up** and is then owned by the database/admin
  panel. Setting or changing one of these fields does **not** change an instance
  that already holds documents — that is deliberate, see the warning below.

> **Changing the embedding engine or model after documents are indexed makes the
> existing knowledge bases unsearchable** (a different vector dimension). Do it
> in the admin panel (*Settings → Documents*) and then re-index the knowledge
> bases with the button on the same page. Never delete or reorder existing
> collections; their contents and order are what the chat retrieves against.

Recommendations for a local Ollama:

* **Embedding model**: the built-in `all-MiniLM-L6-v2` only understands English.
  For German or mixed documents pull a multilingual model on the Ollama host
  (`ollama pull bge-m3`) and, for a *new* instance, set engine *Ollama* and model
  `bge-m3:latest` on the settings page; on an instance that already has knowledge
  bases do it in the admin panel and re-index.
* **Tool calling**: new instances start with the default model parameter
  `function_calling: legacy`. Open WebUI 0.11 otherwise lets the model call its
  built-in tools itself (knowledge search, questions to the user, ...), which
  local models of 14B parameters and below do not handle reliably: invented
  tool calls, garbage tokens, no answer. In legacy mode the knowledge-base
  results are put into the prompt directly. It can be changed per model or
  globally in the admin panel.
* **Context compaction** is off by default (`ENABLE_CONTEXT_COMPACTION`). When a
  conversation exceeds `CONTEXT_COMPACTION_TOKEN_THRESHOLD` tokens (default
  `80000`) Open WebUI summarises the older turns. The default never triggers on
  a small context window, so if you enable compaction for a model served with
  `num_ctx` 16384, set the threshold to roughly `10000` (clearly below the
  window) or it will overflow first. Weigh it carefully for regulated use: the
  summary is lossy, so the model may answer from a compressed history rather than
  the verbatim text.

### Knowledge base in a regulated (GMP) context

The module makes Open WebUI available; it does not make it a validated system.
If you use a knowledge base such as *GMP Wissen* or *Arzneimittelwerbung* to
answer regulated questions, keep the following in mind:

* **AI answers are not a GMP record.** A chat answer is generated from an
  embedding search and a language model; it is not an attributable, reproducible
  record and must not be used as evidence of a controlled fact. Always go back to
  the authoritative, version-controlled source document.
* **Keep an ingestion log.** Open WebUI does not version the files in a knowledge
  base. Record separately — outside the chat — **which version of which document
  was added to (or removed from) which collection and when**, so you can tell
  later what the model could have retrieved at a given time.
* **Protect the collections.** Changing the embedding engine/model, or deleting
  or reordering a collection, breaks or silently changes what the chat retrieves.
  Treat the *GMP Wissen* and *Arzneimittelwerbung* collections as controlled: no
  embedding change without a re-index and a record of it.

### Automated document upload (e.g. Huginn)

If an automation such as Huginn uploads documents into a knowledge base through
the Open WebUI API, give it a **dedicated, non-admin account** with a personal
API key (API keys are enabled by default, see above). Grant it only what it
needs — write access to the target knowledge base, not administrator rights —
and treat the API key as a credential (store it in the automation's secret
store, rotate it if leaked). Review the account's rights periodically.

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
  files, RAG vector store, avatars and the admin panel settings.

## Backup and restore

The module backup contains `state/passwords.env` (the `WEBUI_SECRET_KEY` and the
LDAP bind password) and the `openwebui-data` volume (uploads, the RAG vector
store and the cache).

The database (`webui.db`) is **not** taken from the live volume, where Open
WebUI writes it in WAL mode and a plain copy could be torn. Instead
`bin/module-dump-state` writes a transactionally consistent snapshot (the SQLite
online-backup API) into the backup just before it runs, and
`bin/module-cleanup-state` removes that snapshot afterwards. On restore,
`restore-module` puts the snapshot back over the copy in the volume (and drops
any stale WAL side files). A backup made by a module version older than this one
carries no snapshot; its volume copy of `webui.db` is then used unchanged.

Cloning or moving an instance copies the volume directly (the core does this,
without the snapshot step), so for a consistent clone of a busy instance stop it
first, or take a backup and restore it into a new instance.

## Notes

* Runtime settings, including the LDAP bind password and `WEBUI_SECRET_KEY`, are
  written to `state/openwebui.env` and passed to the container with `--env-file`.
* The Open WebUI image is pinned to a fixed upstream version in
  `build-images.sh`; new versions arrive as module releases.
* The node must be able to reach the Ollama host on its API port (default
  `11434`).
* The container runs in the host network namespace and binds only
  `127.0.0.1:<allocated port>`. This is deliberate: with the rootless default
  network a container cannot reach services on its **own node's IP** (the
  address is mirrored into the container), which broke LDAP login and Ollama
  access whenever the domain controller or Ollama runs on the same node.
