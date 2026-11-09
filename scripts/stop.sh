#!/usr/bin/env bash
# Stops and removes the KrakenD container (either edition).
set -euo pipefail
source "$(dirname "$0")/lib.sh"

docker compose --profile ce --profile ee down --remove-orphans
c_green "KrakenD stopped."
