#!/usr/bin/env bash
# Follows the KrakenD container logs. Ctrl+C to exit.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

docker logs -f --tail 100 krakend
