# ns8-openwebui

A [NethServer 8](https://github.com/NethServer/ns8-core) module that runs
[Open WebUI](https://github.com/open-webui/open-webui) as a self-hosted AI chat
interface in front of a bundled [Ollama](https://github.com/ollama/ollama)
inference backend.

Everything runs locally on your node: Open WebUI provides the chat UI, user
management and RAG/document features, while Ollama serves the language models.
No data leaves the server and no external API key is required.

## Architecture

A single rootless pod with two containers:

| Container | Image | Port | Exposure |
| --- | --- | --- | --- |
| `openwebui-app` | `ghcr.io/open-webui/open-webui` | 8080 | published on the node loopback, fronted by Traefik (TLS/WebSocket) |
| `openwebui-ollama` | `docker.io/ollama/ollama` | 11434 | pod-internal only, reached by Open WebUI over `localhost` |

One allocated TCP port on the node loopback fronts the web interface. Ollama is
never exposed on the node. No dedicated node IP is required.

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
| Interface name | `WEBUI_NAME` | Display name shown in the UI. |
| Allow self-registration | `ENABLE_SIGNUP` | Let visitors create accounts. The **first** account always becomes admin. |
| Default role for new accounts | `DEFAULT_USER_ROLE` | `pending` (admin approval), `user`, or `admin`. |
| Enable OpenAI-compatible API | `ENABLE_OPENAI_API` | Off = self-contained local-only setup. |
| Model keep-alive | `OLLAMA_KEEP_ALIVE` | How long Ollama keeps a model in RAM, e.g. `5m`, `1h`, `-1`. |
| Timezone | `TZ` | e.g. `Europe/Berlin`. |

`WEBUI_SECRET_KEY` is generated once at install time and kept stable so login
sessions survive restarts.

## First steps

1. Open the published URL and **register the first account** — it becomes the
   administrator.
2. Go to **Admin Panel → Settings → Models** and pull a model (e.g. `llama3.2`,
   `qwen2.5`, `gemma2`). The download runs on the server and is stored in the
   Ollama volume.
3. Turn **self-registration** off (or set the default role to *pending*) once
   your users have accounts.

## Storage

Two rootless named volumes survive container recreation:

* `openwebui-data` — mounted at `/app/backend/data`: SQLite database, uploaded
  files, RAG vector store, avatars and generated config.
* `openwebui-ollama` — mounted at `/root/.ollama`: pulled models, manifests and
  blobs (this is the large one).

## Notes

* **CPU inference by default.** The rootless pod does not pass through a GPU.
  Model responses run on CPU, which is fine for small/medium models but slow for
  large ones. GPU acceleration requires host-level NVIDIA CDI configuration and
  is out of scope for the default deployment.
* The images track upstream moving tags (`open-webui:main`, `ollama:latest`).
  Pin them in `build-images.sh` for fully reproducible deployments.
* On first start Open WebUI initialises its database; Ollama starts empty until
  you pull a model.
