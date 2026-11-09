#!/usr/bin/env bash
# Runs once when the Codespace is created: pre-pulls the KrakenD images.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

chmod +x scripts/*.sh

c_bold "Waiting for Docker..."
wait_for_docker

materialize_license

c_bold "Pulling KrakenD CE ${KRAKEND_VERSION}..."
docker pull "krakend:${KRAKEND_VERSION}"

if [[ -f LICENSE ]]; then
  c_bold "LICENSE found - pulling KrakenD EE ${KRAKEND_VERSION}..."
  docker pull "krakend/krakend-ee:${KRAKEND_VERSION}"
fi

c_green "Setup complete."
