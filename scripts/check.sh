#!/usr/bin/env bash
# Validates the config for an edition with `krakend check` (does not start the gateway).
#   bash scripts/check.sh        -> edition auto-detected (EE if ./LICENSE exists)
#   bash scripts/check.sh ce     -> force CE
#   bash scripts/check.sh ee     -> force EE (needs ./LICENSE)
set -euo pipefail
source "$(dirname "$0")/lib.sh"

wait_for_docker
materialize_license

EDITION="${1:-$(resolve_edition)}"
args=(--rm
  -e FC_ENABLE=1
  -e FC_OUT=/tmp/krakend-rendered.json
  -e OPENAI_API_KEY="${OPENAI_API_KEY:-}"
  -e ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"
  -v "$REPO_ROOT/config/$EDITION:/etc/krakend/config:ro")

if [[ "$EDITION" == "ee" ]]; then
  [[ -f LICENSE ]] || { c_red "EE check needs ./LICENSE"; exit 1; }
  args+=(-v "$REPO_ROOT/LICENSE:/etc/krakend/LICENSE:ro")
  IMAGE="krakend/krakend-ee:${KRAKEND_VERSION}"
else
  IMAGE="krakend:${KRAKEND_VERSION}"
fi

c_bold "Checking config/$EDITION/krakend.json with $IMAGE"
docker run "${args[@]}" "$IMAGE" check -t -d -c /etc/krakend/config/krakend.json
