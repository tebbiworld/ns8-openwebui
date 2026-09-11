#!/bin/bash

#
# Copyright (C) 2026 tebbi
# SPDX-License-Identifier: GPL-3.0-or-later
#

set -e

images=()
repobase="${REPOBASE:-ghcr.io/tebbiworld}"
reponame="openwebui"

# Runtime images pinned by the module through the org.nethserver.images label so
# the node pre-pulls them and exposes their references to the systemd units.
#
# The env var name is the image basename, uppercased, with non-alphanumeric
# characters turned into underscores, plus the _IMAGE suffix:
#   ghcr.io/open-webui/open-webui:...  -> ${OPEN_WEBUI_IMAGE}
#   docker.io/ollama/ollama:...        -> ${OLLAMA_IMAGE}
#
# These are moving upstream tags (open-webui :main, ollama :latest). Pin them to
# a digest or fixed version for reproducible deployments.
openwebui_image="ghcr.io/open-webui/open-webui:main"
ollama_image="docker.io/ollama/ollama:latest"

runtime_images=(
    "${openwebui_image}"
    "${ollama_image}"
)

container=$(buildah from scratch)

# Reuse an existing nodebuilder container to speed up UI rebuilds
if ! buildah containers --format "{{.ContainerName}}" | grep -q nodebuilder-openwebui; then
    echo "Pulling NodeJS runtime..."
    buildah from --name nodebuilder-openwebui -v "${PWD}:/usr/src:Z" docker.io/library/node:24.16.0-slim
fi

echo "Build static UI files with node..."
buildah run \
    --workingdir=/usr/src/ui \
    --env="NODE_OPTIONS=--openssl-legacy-provider" \
    nodebuilder-openwebui \
    sh -c "yarn install && yarn build"

buildah add "${container}" imageroot /imageroot
buildah add "${container}" ui/dist /ui
# Reserve one TCP port for the Open WebUI frontend (container 8080), fronted by
# Traefik. Ollama stays pod-internal, so no extra node ports are required.
buildah config --entrypoint=/ \
    --label="org.nethserver.authorizations=traefik@node:routeadm" \
    --label="org.nethserver.tcp-ports-demand=1" \
    --label="org.nethserver.rootfull=0" \
    --label="org.nethserver.images=${runtime_images[*]}" \
    "${container}"
buildah commit "${container}" "${repobase}/${reponame}"

images+=("${repobase}/${reponame}")

if [[ -n "${CI}" ]]; then
    printf "images=%s\n" "${images[*],,}" >> "${GITHUB_OUTPUT}"
else
    printf "Publish the images with:\n\n"
    for image in "${images[@],,}"; do printf "  buildah push %s docker://%s:%s\n" "${image}" "${image}" "${IMAGETAG:-latest}" ; done
    printf "\n"
fi
