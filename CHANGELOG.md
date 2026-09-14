# Changelog

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
