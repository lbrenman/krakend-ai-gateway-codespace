#!/usr/bin/env bash
# Starts KrakenD (EE if ./LICENSE exists, otherwise CE) and waits for /__health.
# Override with: KRAKEND_EDITION=ce bash scripts/start.sh
set -euo pipefail
source "$(dirname "$0")/lib.sh"

wait_for_docker
materialize_license

EDITION="$(resolve_edition)"

# Stop whichever edition might already be running (same container name).
docker compose --profile ce --profile ee down --remove-orphans >/dev/null 2>&1 || true

c_bold "Starting KrakenD ${EDITION^^} ${KRAKEND_VERSION}..."
docker compose --profile "$EDITION" up -d

printf 'Waiting for gateway'
for _ in $(seq 1 60); do
  if curl -fsS http://localhost:8080/__health >/dev/null 2>&1; then
    echo
    c_green "KrakenD ${EDITION^^} is up."
    echo
    echo "  Gateway URL : $(gateway_url)"
    echo "  Health      : $(gateway_url)/__health"
    echo "  OpenAI key  : $(key_status OPENAI_API_KEY)"
    echo "  Anthropic key: $(key_status ANTHROPIC_API_KEY)"
    echo
    echo "  Run 'bash scripts/test.sh' to exercise the endpoints."
    exit 0
  fi
  printf '.'
  sleep 1
done

echo
c_red "KrakenD did not become healthy in 60s. Recent logs:"
docker logs --tail 50 krakend || true
exit 1
