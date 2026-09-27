# Changelog

## 1.2.0 — unreleased

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
