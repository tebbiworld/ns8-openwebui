# Changelog

## 1.4.0 — 2026-11-13

### Added

- **Knowledge-base (RAG) base values on the settings page.** Optional fields for
  the embedding engine and model, Top K and chunk size/overlap. They are written
  to the environment as a *seed* only: Open WebUI stores them in its database on
  first start and the database wins from then on, and these keys are deliberately
  not reset on every start. So a value configures a fresh instance and never
  silently changes an instance that already holds documents — which would make
  the indexed knowledge bases unsearchable after an embedding change. The
  settings page carries a warning to that effect; a later change is made in the
  admin panel together with a re-index. This replaces hand-editing
  `state/openwebui.env`, whose lines were lost on the next page save.

### Changed

- **Personal API keys are enabled by default** (`ENABLE_API_KEYS`, off upstream)
  so programmatic clients — such as an automated document upload into the
  knowledge base — can authenticate. Seed-once, so an instance that already has
  the setting keeps its own value; an administrator can turn it off in the panel.

### Documentation

- A "Knowledge base in a regulated (GMP) context" section: AI answers are not a
  GMP record, keep an ingestion log of which document version entered which
  collection when, and treat the *GMP Wissen* / *Arzneimittelwerbung* collections
  as controlled (no embedding change without a re-index).
- How to run an automated upload (e.g. Huginn) with a dedicated non-admin
  account and a scoped API key.
- Context compaction (off by default) and why its token threshold has to be set
  well below a small `num_ctx` window if it is enabled.
- The security defaults are spelled out: sign-up off, API keys on, LDAP
  certificate validation on for an `ldaps://` server of its own.

## 1.3.1 — 2026-11-11

### Fixed

- **Consistent database backup.** The backup used to copy the live SQLite
  database (`webui.db`) straight from the volume, where Open WebUI writes it in
  WAL mode, so the saved file could be torn. A new `module-dump-state` hook now
  writes a transactionally consistent snapshot (the SQLite online-backup API)
  into the backup, `module-cleanup-state` removes it afterwards, and
  `restore-module` restores that snapshot over the volume copy (dropping any
  stale WAL side files). Backups made by an older version still restore — their
  own `webui.db` from the volume is used when no snapshot is present. Uploads and
  the RAG vector store keep being backed up as volume files.

## 1.3.0 — 2026-11-11

### Added

- **Unified directory login.** The AD/LDAP settings now offer the same chooser
  as the other tebbiworld NS8 modules: a **user domain of this cluster**
  (through the node's `ldapproxy`, no credentials stored, follows a bind-password
  change or a domain-controller move automatically) **or** an **LDAP server of
  its own**. With a user domain, login can be restricted to a group picked from
  a list (nested AD groups count). The shared building blocks
  (`pypkg/ldapsettings.py`, `components/LdapLogin.vue`, the `list-ldap-groups`
  action, `bin/discover-ldap` as an `ExecStartPre`, the `user-domain-changed`
  event, the `cluster:accountconsumer` label) are taken 1:1 from those modules;
  `pypkg/owldap.py` translates the chosen settings into Open WebUI's native LDAP
  support.

### Security

- Self-registration (`ENABLE_SIGNUP`) now defaults to **off**: a new instance no
  longer lets anonymous visitors create accounts unless the administrator turns
  it on.
- A custom LDAP server with **StartTLS** is refused: Open WebUI binds with
  `use_ssl` only, so StartTLS would have silently connected in clear text. Use an
  `ldaps://` URL instead.
- A configured login **group** that cannot be resolved now fails closed (every
  login refused) instead of allowing all directory users.

### Update notes

- Existing instances are carried over as a **custom LDAP server** with their
  previous behaviour (TLS verification kept as it was, the former free-text
  search filter preserved), so the login is not lost. Switch to a cluster user
  domain on the settings page when you want that.

## 1.2.1 — 2026-09-30

### Changed

- Open WebUI v0.11.3 → v0.11.4.
- The update test expects a line appended to `openwebui.env` by hand to take effect only when updating from 1.1.x; from 1.2.0 the settings live in the database (see the update notes of 1.2.0).

## 1.2.0 — 2026-09-27

### Fixed

- **Settings made in the Open WebUI admin panel are no longer lost on restart.** Up to 1.1.x the module ran Open WebUI with `ENABLE_PERSISTENT_CONFIG=false`, so every change in the admin panel only lasted until the next restart, update or node reboot. A switched embedding model (e.g. `bge-m3` via Ollama) silently fell back to the built-in `all-MiniLM-L6-v2`: knowledge bases indexed with the other model no longer matched (1024 vs 384 dimensions) and every search answered "no sources found".
  Open WebUI now keeps its settings in its database. The settings owned by this module (Ollama URL, self-registration, default role, OpenAI switch, all LDAP settings) are reset to the values from the NS8 settings page before every start, so that page stays authoritative for them.

### Changed

- New instances start with the default model parameter `function_calling: legacy`. Open WebUI 0.11 defaults to native tool calling, which local models of 14B parameters and below do not handle reliably (invented tool calls, garbage tokens, no answer); in legacy mode the knowledge-base results are placed into the prompt. It is only a default and can be changed in the admin panel.

### Update notes

- The update switches the existing `openwebui.env` in place instead of rewriting it: lines appended to it by hand (for example `RAG_EMBEDDING_MODEL=`, `CHUNK_SIZE=`, `ENABLE_API_KEYS=`) are taken over into the Open WebUI database at the first start and are kept from then on, even after the next save of the NS8 settings page.
- Anything that was only set in the admin panel before the update was already lost at the last restart and has to be set once more; from now on it stays.
- API keys (*Admin panel → Settings → General*) are now kept as well; the module does not manage them.

## 1.1.0 — 2026-09-19

Alignment with the NethServer module conventions (NethServer/agents skills).

### Changed

- **Secrets moved out of the module environment.** `WEBUI_SECRET_KEY` and the LDAP bind password are now kept in `state/passwords.env` (mode 0600) instead of `state/environment`, which NS8 mirrors to Redis in plain text. Existing installations are migrated on update; the values do not change. The generated `openwebui.env` is private (0600).
- **Module backup now contains the data.** New `etc/state-include.conf`: the backup holds the `openwebui-data` volume (database, uploads, vector store) and the secrets file. Before, only the module environment was saved.
- **Working restore.** New `restore-module` steps re-apply every setting, including the directory login, and keep the original `WEBUI_SECRET_KEY`.

### Added

- Robot Framework tests (install, update from the previous release, backup and restore) run on real NS8 nodes through `stephdl/ns8-ci-actions`.

### Platform integration

- **Clone and move.** New `clone-module` step (a link to the restore step): a cloned or moved instance gets its route and settings back instead of coming up unconfigured. The settings are read from the source instance, including those a new instance starts with a default for.
- `org.nethserver.volumes`: the bulk-data volume(s) `openwebui-data` can be placed on an additional disk when the module is installed.
- Release notes are linked from the software centre (`relnotes_url`).

## 1.0.2 — 2026-09-14

### Changed

- Runtime image pinned to `open-webui:v0.11.3` instead of the moving `main` tag: every installation now runs the same, tested Open WebUI version; new upstream versions arrive as module releases (automatic every ~6 weeks). Existing instances on a different `main` build are moved to 0.11.3 by this update.

## 1.0.1 — 2026-09-12

### Fixed

- **LDAP/AD login and Ollama access failed when the target runs on the same
  node.** The container used the rootless default network (pasta), in which the
  node's own IP address is mirrored into the container: a connection to that
  address is refused inside the container instead of reaching the host. On a
  node that also hosts the NS8 Samba account provider (the AD domain controller)
  every LDAP login ended in `LDAP authentication failed.` (`[Errno 111]
  Connection refused` in the log). The container now runs with
  `--network=host` and Open WebUI binds `127.0.0.1:<allocated port>` itself
  (`HOST`/`PORT` in `openwebui.env`); nothing else is exposed.
- `update-module` now restarts the service and injects `HOST`/`PORT` into an
  existing `openwebui.env`, so the fix takes effect right after the update
  without a reboot or a re-save of the settings.
