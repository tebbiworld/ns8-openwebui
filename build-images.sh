#!/bin/bash

#
# Copyright (C) 2026 tebbi
# SPDX-License-Identifier: GPL-3.0-or-later
#

set -e

images=()
repobase="${REPOBASE:-ghcr.io/tebbiworld}"
reponame="openwebui"

# Runtime image pinned by the module through the org.nethserver.images label so
# the node pre-pulls it and exposes its reference to the systemd unit.
#
# The env var name is the image basename, uppercased, with non-alphanumeric
# characters turned into underscores, plus the _IMAGE suffix:
#   ghcr.io/open-webui/open-webui:...  -> ${OPEN_WEBUI_IMAGE}
#
# This is a moving upstream tag (open-webui :main). Pin it to a digest or fixed
# version for fully reproducible deployments. Ollama is NOT bundled: Open WebUI
# connects to an external Ollama instance configured on the settings page.
openwebui_image="ghcr.io/open-webui/open-webui:main"

runtime_images=(
    "${openwebui_image}"
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
# Traefik. No extra node ports are required.
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
