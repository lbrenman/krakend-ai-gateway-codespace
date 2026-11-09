# KrakenD AI Gateway — GitHub Codespace

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/lbrenman/krakend-ai-gateway-codespace?quickstart=1)

A one-click sandbox for the [KrakenD](https://www.krakend.io/) API / AI Gateway (v3.0.3). Click the button, wait about a minute, and you have a running gateway on port 8080 that:

- proxies **OpenAI** and **Anthropic** with the API keys injected by the gateway (clients never see or send a key),
- rate-limits every LLM route per client IP,
- and — when you add a KrakenD Enterprise `LICENSE` — exposes KrakenD's **AI Gateway** unified LLM interface (`ai/llm`) with header-based model routing.

No API keys are needed to see it work: a demo endpoint proxies a public test API.

---

## Contents

- [Quick start](#quick-start)
- [Community vs Enterprise](#community-vs-enterprise)
- [Adding your API keys (Codespaces secrets)](#adding-your-api-keys-codespaces-secrets)
- [Enabling the Enterprise AI Gateway](#enabling-the-enterprise-ai-gateway)
- [Endpoints](#endpoints)
- [Trying it out](#trying-it-out)
- [Calling the gateway from outside the Codespace](#calling-the-gateway-from-outside-the-codespace)
- [Scripts](#scripts)
- [Changing the configuration](#changing-the-configuration)
- [Repository layout](#repository-layout)
- [Troubleshooting](#troubleshooting)
- [References](#references)

---

## Quick start

1. Click **Open in GitHub Codespaces** above (or **Code → Codespaces → Create codespace on main**).
2. Wait for the container to build. On creation it pulls the KrakenD image; on every start it launches the gateway and waits for `/__health`.
3. In the Codespace terminal:

   ```bash
   bash scripts/test.sh
   ```

   or open `requests.http` and click **Send Request** above any block.

You should see `PASS health` and `PASS demo (no key needed)`. LLM tests are skipped until you add keys.

---

## Community vs Enterprise

KrakenD ships two editions. This repo runs whichever one you're entitled to — automatically.

| | Community (CE) — default | Enterprise (EE) — needs `LICENSE` |
|---|---|---|
| Image | `krakend:3.0.3` | `krakend/krakend-ee:3.0.3` |
| Cost | Free, Apache 2.0 | Commercial (trial available) |
| Config | `config/ce/krakend.json` | `config/ee/krakend.json` |
| Transparent LLM proxy with key injection (`/llm/...`) | ✅ | ✅ |
| Per-IP rate limiting on LLM routes | ✅ | ✅ |
| Unified LLM interface `ai/llm` (`/ai/openai`, `/ai/anthropic`) | — | ✅ |
| Header-based LLM routing (`/ai/multi`) | — | ✅ |
| AI Router, Semantic Cache, Prompt Guard, MCP server | — | ✅ (not configured here — add as needed) |

**How the edition is chosen** (`scripts/start.sh`):

- `./LICENSE` exists (or the `KRAKEND_LICENSE_B64` secret decodes to one) → **EE**
- otherwise → **CE**
- force one with `KRAKEND_EDITION=ce bash scripts/start.sh` or `KRAKEND_EDITION=ee ...`

> KrakenD 3.x requires `"version": 4` at the top of the config. Both configs here already use it.

---

## Adding your API keys (Codespaces secrets)

Keys are read from environment variables and rendered into the config at startup by KrakenD's [Flexible Configuration](https://www.krakend.io/docs/configuration/flexible-config/) (`FC_ENABLE=1`). They are never written into the repo.

1. Go to **GitHub → Settings → Codespaces → Secrets → New secret** (or the repo's **Settings → Secrets and variables → Codespaces**).
2. Add any of:

   | Secret | Purpose |
   |---|---|
   | `OPENAI_API_KEY` | Injected as `Authorization: Bearer …` on calls to `api.openai.com` |
   | `ANTHROPIC_API_KEY` | Injected as `x-api-key` (plus `anthropic-version`) on calls to `api.anthropic.com` |
   | `KRAKEND_LICENSE_B64` | Optional — enables Enterprise (see below) |

3. Grant the secret access to `lbrenman/krakend-ai-gateway-codespace`.
4. Codespaces only injects secrets at container start, so if the Codespace is already running: **Command Palette → Codespaces: Rebuild Container** (or stop/start the Codespace).

The devcontainer also declares these secrets, so the **Create codespace** page offers to fill them in.

Not using Codespaces? `cp .env.example .env`, fill it in, and the scripts load it automatically.

Optional model overrides (env or `.env`): `OPENAI_MODEL` (default `gpt-5-nano`) and `ANTHROPIC_MODEL` (default `claude-haiku-4-5`). These are used by the EE `/ai/*` endpoints and by `scripts/test.sh`. For the CE `/llm/...` routes, the client chooses the model in its request body.

---

## Enabling the Enterprise AI Gateway

1. Get a license (customers receive one by email; you can also request a trial from [KrakenD sales](https://www.krakend.io/contact-ai-gateway/)). The file is a PEM certificate named `LICENSE` (or `LICENSE_DEV`).
2. Pick one way to provide it:

   **Option A — Codespaces secret (recommended, survives rebuilds)**

   ```bash
   # on your laptop
   base64 -w0 LICENSE      # macOS: base64 -i LICENSE
   ```

   Save the output as the `KRAKEND_LICENSE_B64` Codespaces secret, then rebuild the container.

   **Option B — drag & drop**

   Drop the file into the repo root as `LICENSE` (it's git-ignored), then:

   ```bash
   bash scripts/start.sh
   ```

3. Check it:

   ```bash
   docker exec krakend krakend license      # -> OK: License is still valid
   bash scripts/test.sh                      # now runs the /ai/* tests too
   ```

> ⚠️ `.gitignore` ignores `LICENSE` so the KrakenD license can't be committed by accident. If you want an open-source license for this repo itself, name it `LICENSE.md`.

---

## Endpoints

Base URL inside the Codespace: `http://localhost:8080`

| Method | Path | Edition | What it does |
|---|---|---|---|
| GET | `/__health` | both | Built-in KrakenD health check |
| GET | `/demo/todos/{id}` | both | Proxies `jsonplaceholder.typicode.com`, returns only `id`, `title`, `completed`. No key needed. |
| GET | `/llm/openai/v1/models` | both | OpenAI model list — quickest way to verify your key |
| POST | `/llm/openai/v1/chat/completions` | both | OpenAI Chat Completions, native OpenAI request and response |
| POST | `/llm/anthropic/v1/messages` | both | Anthropic Messages, native Anthropic request and response |
| POST | `/ai/openai` | EE | Unified interface → OpenAI Responses API |
| POST | `/ai/anthropic` | EE | Unified interface → Anthropic Messages API |
| POST | `/ai/multi` | EE | Routes by `X-LLM` header: `openai` → OpenAI, anything else / missing → Anthropic |

All `/llm/*` and `/ai/*` routes are rate limited: 20 req/s overall and 5 req/s per client IP (`qos/ratelimit/router`). Exceeding it returns `503`.

### The unified interface (EE)

The `/ai/*` endpoints accept the same body no matter which vendor is behind them:

```json
{
  "instructions": "optional system prompt",
  "contents": "the user prompt"
}
```

and return the same shape:

```json
{
  "ai_gateway_response": [ { "contents": ["...model output..."] } ],
  "usage": "123"
}
```

KrakenD builds the vendor-specific payload (model, `max_tokens`, system prompt, …) from the `ai/llm` block in `config/ee/krakend.json`. That's the point: swap OpenAI for Anthropic and the client doesn't change.

---

## Trying it out

**Script:**

```bash
bash scripts/test.sh
```

**REST Client:** open `requests.http` and click **Send Request**.

**curl:**

```bash
# no key needed
curl -s localhost:8080/demo/todos/1 | jq

# OpenAI through the gateway - note: no Authorization header
curl -s localhost:8080/llm/openai/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"gpt-5-nano","messages":[{"role":"user","content":"hi"}]}' | jq

# Anthropic through the gateway - note: no x-api-key header
curl -s localhost:8080/llm/anthropic/v1/messages \
  -H 'Content-Type: application/json' \
  -d '{"model":"claude-haiku-4-5","max_tokens":128,"messages":[{"role":"user","content":"hi"}]}' | jq

# EE: unified interface + routing
curl -s localhost:8080/ai/multi -H 'Content-Type: application/json' -H 'X-LLM: openai' \
  -d '{"contents":"Which vendor are you?"}' | jq
```

**OpenAI SDK pointed at the gateway** (CE or EE):

```python
from openai import OpenAI
client = OpenAI(base_url="http://localhost:8080/llm/openai/v1", api_key="not-used")
print(client.chat.completions.create(
    model="gpt-5-nano",
    messages=[{"role": "user", "content": "hello"}],
).choices[0].message.content)
```

The SDK sends its own `Authorization` header, but the gateway only forwards `Content-Type` and sets its own key, so the dummy value is harmless.

---

## Calling the gateway from outside the Codespace

Codespaces forwards port 8080 automatically. Find the URL in the **Ports** tab, or:

```bash
echo "https://${CODESPACE_NAME}-8080.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
```

- **Private** (default): only you, signed in to GitHub in a browser, can reach it. Good for browser testing.
- **Public**: right-click the port → **Port Visibility → Public**. Anyone with the URL can call it.

> ⚠️ The gateway holds your LLM keys. If you make the port public, anyone with the URL can spend your OpenAI/Anthropic credits (within the rate limit). Keep it private unless you're demoing, and switch it back afterwards. For a public demo, add authentication first — e.g. `auth/validator` (JWT, works in CE) or `auth/api-keys` (EE).

---

## Scripts

| Command | What it does |
|---|---|
| `bash scripts/start.sh` | (Re)starts KrakenD — EE if a license is present, else CE — and waits for health. Runs automatically on every Codespace start. |
| `bash scripts/stop.sh` | Stops the gateway |
| `bash scripts/logs.sh` | Follows the gateway logs |
| `bash scripts/test.sh` | Smoke-tests every endpoint the current edition and keys allow |
| `bash scripts/check.sh [ce\|ee]` | Validates a config with `krakend check -t -d` without starting it |
| `bash scripts/setup.sh` | Pre-pulls images. Runs once at Codespace creation. |

See what KrakenD actually loaded (keys rendered in — don't share this output):

```bash
docker exec krakend cat /tmp/krakend-rendered.json
```

---

## Changing the configuration

1. Edit `config/ce/krakend.json` or `config/ee/krakend.json`. The VS Code JSON schema for KrakenD 3.0 is wired up, so you get autocomplete and validation.
2. `bash scripts/check.sh` to validate.
3. `bash scripts/start.sh` to apply. Config is rendered at startup, so a restart is required.

Things to know about these files:

- They are Flexible Configuration **templates** that also happen to be valid JSON. Values like `` {{ env `OPENAI_API_KEY` }} `` pull from the environment. Use backticks (Go raw strings) inside templates so the file stays valid JSON.
- `"@comment"` keys are ignored by KrakenD — use them for notes.
- To add another OpenAI-compatible provider (Groq, Mistral, a local Ollama via ngrok, …) to CE: copy the `/llm/openai/v1/chat/completions` block, change `host`, `url_pattern` and the injected header, add the key to `docker-compose.yml` and the devcontainer `secrets`.
- To pin a different KrakenD version, change `KRAKEND_VERSION` in `.devcontainer/devcontainer.json` (and rebuild) or export it before running the scripts.

Next ideas for EE: the [AI Router](https://www.krakend.io/docs/enterprise/ai-gateway/ai-router/) (`ai/router`, CEL gates, failover), a shared [provider inventory](https://www.krakend.io/docs/enterprise/ai-gateway/unified-llm-interface/#llm-provider-inventory) (`ai/providers`), [LLM streaming](https://www.krakend.io/docs/enterprise/ai-gateway/llm-streaming/) (`output_encoding: "streaming"`), Semantic Cache and Prompt Guard.

---

## Repository layout

```
.
├── .devcontainer/
│   └── devcontainer.json      # Ubuntu + docker-in-docker, secrets, port 8080, lifecycle hooks
├── config/
│   ├── ce/krakend.json        # Community Edition config (FC template, version 4)
│   └── ee/krakend.json        # Enterprise config: CE routes + ai/llm endpoints
├── scripts/
│   ├── lib.sh                 # shared helpers (edition detection, license decode, URLs)
│   ├── setup.sh               # postCreate: pull images
│   ├── start.sh               # postStart: launch + health wait
│   ├── stop.sh  logs.sh  check.sh  test.sh
├── docker-compose.yml         # profiles: ce | ee
├── requests.http              # REST Client samples
├── .env.example               # for non-Codespaces use
└── .gitignore                 # ignores LICENSE and .env
```

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `KrakenD did not become healthy` | `bash scripts/logs.sh`. A config error names the file and line. Run `bash scripts/check.sh`. |
| EE exits immediately | License missing, expired or mangled. `docker run --rm -v $PWD/LICENSE:/etc/krakend/LICENSE krakend/krakend-ee:3.0.3 license`. If you used the secret, make sure you encoded with `base64 -w0`. |
| `401` from `/llm/...` or `/ai/...` | The key isn't set inside the container. `echo ${OPENAI_API_KEY:+set}` in the terminal; if empty, add the secret and **rebuild** the container. |
| `503` on LLM routes | You hit the rate limit (5 req/s per IP). Raise `client_max_rate` in the config. |
| `404` on `/ai/*` | You're running CE. Add a license (see above). |
| Model not found | Pass a current model name in the request (CE) or set `OPENAI_MODEL` / `ANTHROPIC_MODEL` (EE) and restart. |
| Port 8080 already in use | `bash scripts/stop.sh` then `bash scripts/start.sh`. |
| Streaming (`"stream": true`) arrives all at once on CE | Expected with a plain `no-op` proxy in some setups. EE supports true token streaming via `output_encoding: "streaming"`. |

---

## References

- [KrakenD downloads](https://www.krakend.io/download/)
- [KrakenD documentation](https://www.krakend.io/docs/)
- [KrakenD 3.0 release announcement](https://www.krakend.io/blog/krakend-3-series/)
- [AI Gateway — OpenAI integration](https://www.krakend.io/docs/enterprise/ai-gateway/openai/)
- [AI Gateway — Anthropic integration](https://www.krakend.io/docs/enterprise/ai-gateway/anthropic/)
- [AI Gateway — LLM routing](https://www.krakend.io/docs/enterprise/ai-gateway/llm-routing/)
- [Enterprise LICENSE file](https://www.krakend.io/docs/enterprise/overview/license-file/)
- [Flexible Configuration](https://www.krakend.io/docs/configuration/flexible-config/)
- [GitHub Codespaces secrets](https://docs.github.com/en/codespaces/managing-your-codespaces/managing-your-account-specific-secrets-for-github-codespaces)
