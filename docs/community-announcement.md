<!--
First community post for the NS8 Open WebUI module, written in the style
of https://community.nethserver.org/t/ns8-forgejo-testing/28554 (first post).
Paste into a new topic on community.nethserver.org, category "App", tag "ns8".
Fill in the wiki link once the page is published.
-->

# NS8 Open WebUI (testing)

Hi all,

I've built an NS8 module for [Open WebUI](https://github.com/open-webui/open-webui) — a self-hosted AI chat interface that talks to an external Ollama server, so your users get a friendly web front end while the models run on a machine you size yourself.

It's in my community repository. To try it, add the repo once:

```
api-cli run add-repository --data '{"name":"tebbiworld","url":"https://raw.githubusercontent.com/tebbiworld/ns8-repo/main/ns8/updates/","status":true,"testing":false}'
```

then install **Open WebUI** from the Software Center. (Or straight from the image: `add-module ghcr.io/tebbiworld/openwebui:latest 1`.)

What it does:

* Runs the Open WebUI chat front end on your node, published on an FQDN through Traefik with optional Let's Encrypt and HTTP→HTTPS redirection.
* Connects to an **external** Ollama instance (for example one running on your Proxmox host with the GPU) — Ollama is deliberately not bundled, so the inference host is sized and managed separately.
* Optional Active Directory / LDAP login using Open WebUI's native support; the first account to log in becomes the administrator.
* Self-registration and the default role for new accounts are configurable, and chat history, uploads and the RAG store live in a named volume that survives container recreation.

A few things to know:

* Open WebUI is fairly hungry — reckon on roughly 6 GB RAM per instance.
* The container runs in the host network namespace and binds only `127.0.0.1:<port>`. That's deliberate: with the rootless default network a container can't reach services on its own node's IP, which otherwise broke LDAP login and Ollama access when the domain controller or Ollama runs on the same node.
* Your node needs to reach the Ollama host on its API port (default 11434); the models are pulled and run there, not on the NS8 node.

It's early days, so feedback is very welcome — if you point it at your own Ollama, I'd be glad to hear whether the connection and (especially) AD/LDAP login behave for you.

Docs: NethServer wiki (tebbiworld repository) · Source: [github.com/tebbiworld/ns8-openwebui](https://github.com/tebbiworld/ns8-openwebui)

Thanks!

*Category: App · Tags: ns8*
