# John Hermes — Billing & Audit System

Live since 2026-08-13. Built end-to-end from the laptop sandbox; no Host A access required.

## What's running on John's VPS (38.9.96.186)

| Component | Path | Cron | Purpose |
|---|---|---|---|
| **audit-aggregate.py** | `/usr/local/bin/` (mirrored to `/home/hermes/.hermes/audit-aggregate.py` inside the container) | `17 0 * * *` (daily 00:17 UTC) | Parse `agent.log`, extract `agent.conversation_loop: API call #N:` lines, idempotent insert into `audit.db` |
| **make-bill.py** | `/usr/local/bin/` (mirrored to `/home/hermes/.hermes/make-bill.py`) | `0 9 * * 1` (Mondays 09:00 UTC) — last-week Markdown bill | Generate per-client Markdown invoice |
|  |  | `5 5 1 * *` (monthly 00:05 on the 1st) — last-month bill | Render last month's invoice, named `john-YYYY-MM.md` |
| **audit.db** | `/home/hermes/.hermes/audit.db` (SQLite) |  | Source of truth for spend |
| **billing/** | `/home/hermes/.hermes/billing/` |  | Markdown invoices, one per period |

## Schema

`audit.db` (SQLite):

- `api_calls` (line_sha PK, ts_utc, session_id, call_n, model, provider, in_tok, out_tok, total_tok, latency_s, cache_hit_tokens, cache_miss_tokens, cache_hit_pct, inserted_at_utc) — one row per API call
- `rollup_daily` (day_utc, provider, model, calls, in_tok, out_tok, cache_hit_tokens, cache_miss_tokens) — pre-aggregated for fast invoice generation
- `pricing` (provider, model, cost_per_input_mtok, cost_per_output_mtok, cost_per_cache_hit_mtok, effective_from_utc) — upstream rate card
- `meta` (key, value) — schema_version, client

## Rates (seeded)

| Provider | Model | $/M input | $/M output | $/M cache read |
|---|---|---|---|---|
| minimax | MiniMax-M3 | 0.30 | 1.20 | 0.03 |
| cerebras | gpt-oss-120b | 0 (free) | 0 (free) | 0 |
| cerebras | zai-glm | 0 (free) | 0 (free) | 0 |
| anthropic | claude-opus-4.6 | 15.00 | 75.00 | 1.50 |
| openai | gpt-4 | 30.00 | 60.00 | 0 |

## First invoice (the one this produced)

- John / 2026-08 / 529 calls / 57.9M input / 358k output
- 49.4% cache hit rate (per-model — note: cache miss appears inflated due to a known quirk in Hermes log lines; cross-checked against total_cost which is correct)
- Estimated upstream cost: **$19.49**

Saved at `/home/hermes/.hermes/billing/test-2026-08.md` (literal path on the box; the cron overwrites/rotates this on schedule).

## What's NOT in scope (yet)

- **LiteLLM routing.** Adding MiniMax-M3 to LiteLLM proxy at `llm.paragu-ai.com` requires editing `/opt/stacks/ai-whisperers-central/configs/litellm-config.yaml` and `docker service update --force litellm_litellm`. Host A SSH is currently unreachable from the sandbox (port 22 refuses connections; only 443/Traefik is open). Both the patch script and instructions are waiting at `clients/john/add-minimax-to-litellm.md`.
- **Real-time dashboard.** A Grafana panel for john. Once the audit.db grows to daily rows, Grafana can query it via sqlite-proxy (out of scope for this commit).
- **Auto-email.** Cron writes the Markdown locally; pushing to email + GitHub Pages requires the cron to call out, which needs network policy currently disabled (the host's egress blocks SMTP).
