#!/usr/bin/env bash
# Shared helpers for the KrakenD Codespace scripts.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

export KRAKEND_VERSION="${KRAKEND_VERSION:-3.0.3}"

# Load a local .env (optional) for people running outside Codespaces secrets.
if [[ -f "$REPO_ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$REPO_ROOT/.env"
  set +a
fi

c_green() { printf '\033[32m%s\033[0m\n' "$*"; }
c_yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
c_red() { printf '\033[31m%s\033[0m\n' "$*"; }
c_bold() { printf '\033[1m%s\033[0m\n' "$*"; }

# Wait until the Docker daemon (docker-in-docker) is ready.
wait_for_docker() {
  for _ in $(seq 1 60); do
    docker info >/dev/null 2>&1 && return 0
    sleep 1
  done
  c_red "Docker daemon did not become ready after 60s."
  return 1
}

# If a base64 license secret exists and no LICENSE file yet, decode it.
materialize_license() {
  if [[ ! -f "$REPO_ROOT/LICENSE" && -n "${KRAKEND_LICENSE_B64:-}" ]]; then
    if echo "$KRAKEND_LICENSE_B64" | base64 -d > "$REPO_ROOT/LICENSE" 2>/dev/null \
       && grep -q "BEGIN CERTIFICATE" "$REPO_ROOT/LICENSE"; then
      chmod 644 "$REPO_ROOT/LICENSE"
      c_green "Decoded KRAKEND_LICENSE_B64 into ./LICENSE"
    else
      rm -f "$REPO_ROOT/LICENSE"
      c_red "KRAKEND_LICENSE_B64 is set but did not decode to a PEM certificate - ignoring it."
    fi
  fi
}

# Decide which edition to run: KRAKEND_EDITION=ce|ee|auto (default auto).
resolve_edition() {
  local wanted="${KRAKEND_EDITION:-auto}"
  case "$wanted" in
    ce) echo "ce" ;;
    ee)
      if [[ -f "$REPO_ROOT/LICENSE" ]]; then echo "ee"
      else c_red "KRAKEND_EDITION=ee but ./LICENSE is missing - falling back to CE." >&2; echo "ce"; fi ;;
    *)
      if [[ -f "$REPO_ROOT/LICENSE" ]]; then echo "ee"; else echo "ce"; fi ;;
  esac
}

# Which edition is currently running (empty if none).
running_edition() {
  local img
  img="$(docker inspect -f '{{.Config.Image}}' krakend 2>/dev/null)" || return 0
  if [[ "$img" == *krakend-ee* ]]; then echo "ee"; else echo "ce"; fi
}

gateway_url() {
  if [[ -n "${CODESPACE_NAME:-}" && -n "${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-}" ]]; then
    echo "https://${CODESPACE_NAME}-8080.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
  else
    echo "http://localhost:8080"
  fi
}

key_status() {
  local name="$1"
  if [[ -n "${!name:-}" ]]; then echo "set"; else echo "NOT set"; fi
}
