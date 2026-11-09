#!/usr/bin/env bash
# Smoke-tests the running gateway. LLM calls are skipped when the matching key is not set.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

BASE="http://localhost:8080"
EDITION="$(running_edition)"
if [[ -z "$EDITION" ]]; then
  c_red "KrakenD is not running. Start it with: bash scripts/start.sh"
  exit 1
fi

PASS=0; FAIL=0; SKIP=0

run() { # name, expected-status, curl args...
  local name="$1" expect="$2"; shift 2
  local out code body
  out="$(curl -sS -w '\n%{http_code}' "$@" 2>&1)"
  code="${out##*$'\n'}"; body="${out%$'\n'*}"
  if [[ "$code" == "$expect" ]]; then
    c_green "PASS  $name ($code)"; PASS=$((PASS+1))
  else
    c_red "FAIL  $name (got $code, want $expect)"; FAIL=$((FAIL+1))
  fi
  echo "      ${body:0:300}" | tr '\n' ' '; echo
}

skip() { c_yellow "SKIP  $1"; SKIP=$((SKIP+1)); }

c_bold "Testing KrakenD ${EDITION^^} at $BASE"
echo

run "health"               200 "$BASE/__health"
run "demo (no key needed)" 200 "$BASE/demo/todos/1"

if [[ -n "${OPENAI_API_KEY:-}" ]]; then
  run "CE proxy: OpenAI models" 200 "$BASE/llm/openai/v1/models"
  run "CE proxy: OpenAI chat"   200 -X POST "$BASE/llm/openai/v1/chat/completions" \
      -H 'Content-Type: application/json' \
      -d "{\"model\":\"${OPENAI_MODEL:-gpt-5-nano}\",\"messages\":[{\"role\":\"user\",\"content\":\"Say hello in 5 words\"}]}"
else
  skip "OpenAI proxy tests (OPENAI_API_KEY not set)"
fi

if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
  run "CE proxy: Anthropic messages" 200 -X POST "$BASE/llm/anthropic/v1/messages" \
      -H 'Content-Type: application/json' \
      -d "{\"model\":\"${ANTHROPIC_MODEL:-claude-haiku-4-5}\",\"max_tokens\":64,\"messages\":[{\"role\":\"user\",\"content\":\"Say hello in 5 words\"}]}"
else
  skip "Anthropic proxy tests (ANTHROPIC_API_KEY not set)"
fi

if [[ "$EDITION" == "ee" ]]; then
  PROMPT='{"instructions":"You are terse.","contents":"Say hello in 5 words"}'
  if [[ -n "${OPENAI_API_KEY:-}" ]]; then
    run "AI Gateway: /ai/openai"           200 -X POST "$BASE/ai/openai" -H 'Content-Type: application/json' -d "$PROMPT"
    run "AI Gateway: /ai/multi (openai)"   200 -X POST "$BASE/ai/multi"  -H 'Content-Type: application/json' -H 'X-LLM: openai' -d "$PROMPT"
  else
    skip "EE OpenAI tests (OPENAI_API_KEY not set)"
  fi
  if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    run "AI Gateway: /ai/anthropic"          200 -X POST "$BASE/ai/anthropic" -H 'Content-Type: application/json' -d "$PROMPT"
    run "AI Gateway: /ai/multi (fallback)"   200 -X POST "$BASE/ai/multi"     -H 'Content-Type: application/json' -d "$PROMPT"
  else
    skip "EE Anthropic tests (ANTHROPIC_API_KEY not set)"
  fi
else
  skip "EE AI Gateway endpoints (running CE - add a LICENSE to enable)"
fi

echo
c_bold "Result: $PASS passed, $FAIL failed, $SKIP skipped"
[[ $FAIL -eq 0 ]]
