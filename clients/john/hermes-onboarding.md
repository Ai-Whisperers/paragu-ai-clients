# John (client) — Servarica VPS for Private Hermes

Compiled 2026-08-12 from live servarica.com pages, plus AIW infra context.

## What Servarica is

- **Canadian company**, Rica Web Services Inc., Montreal since 2010.
- Own hardware, own ASN, multi-homed network, **no overselling**.
- 100% Hydro-Québec renewable power, cooling via Montreal winters.
- Single region: **Montreal, QC** (~530 km from NYC, sub-10 ms to NYC/Boston/DC).
- Same provider as AIW's Host A (38.9.96.179, ParaguAI production) and Host B (38.9.96.180, Hermes) — so we already know the platform, panel, and support reality.
- TOS/AUP at `/terms-of-service/`, SLA at `/sla/`, comparison vs Hetzner/DO/Vultr/OVH at `/compare/`.
- Wholesale own hardware → their own marketing claim: ~10× cheaper than Hetzner/OVH/DO at equivalent spec (page dated 2026-06-23).

## In-stock VPS plans (2026-08-12)

Only **4 plans in stock** — all V2 KVM, all EPYC 7532 dedicated cores, all NVMe. Older V3 plans show "Out of stock" but pricing is still quoted. Annual billing is ~8% off monthly.

| Plan | vCPU | RAM | NVMe | Monthly | Annual | Best for |
|---|---|---|---|---|---|---|
| **V2 KVM Slim Slice 2** | 2 dedicated | 8 GB | 250 GB | $7/mo | $77/yr | Hermes gateway + dashboard. **Recommended default.** |
| **V2 KVM FAT Slice 2** | 2 dedicated | 8 GB | 500 GB | $9/mo | $99/yr | Same RAM, 2× disk (logs/backups more room) |
| **V2 KVM Slim Slice 4** | 4 dedicated | 16 GB | 500 GB | $12/mo | $132/yr | Headroom for scrapers / heavier skills |
| **V2 KVM FAT Slice 4** | 4 dedicated | 16 GB | 1 TB | $16/mo | $176/yr | If he wants local LLM + skills |

**Recommendation for John:** V2 KVM Slim Slice 4 ($12/mo). Matches Host B's proven 4 vCPU/8 GB baseline with 2× RAM headroom. Going FAT adds disk only — Hermes state.db is ~50 MB and growing slowly, 500 GB is overkill either way; pick Slim for the RAM.

If he wants to start cheaper and bump later: V2 KVM Slim Slice 2 ($7/mo) works fine for the gateway+dashboard. Sizing is the same shape as Host B today.

Bandwidth: every plan ships with one of two options — "unlimited 250 Mbps→1 Gbps" burst or 10 Gbps capped at a TB transfer quota (6 TB on Slice 2, 12 TB on Slice 4). Plenty for an LLM-router workload; outbound to Anthropic/OpenAI/etc. is the main traffic.

## TOS / AUP relevant to Hermes

- ✅ **Legal in Canada, including AI inference.** No explicit prohibition on AI workloads.
- ✅ Personal VPN/proxy allowed (Tailscale, WireGuard — fine).
- ✅ TOR relay nodes allowed, exit nodes not (irrelevant here).
- ❌ Public proxy servers, IRC servers, adult content, gambling — all banned. Hermes isn't any of these.
- ⚠️ **No spam / UCE.** Hermes gateway handles Telegram + Mensaje inbound/outbound — your outbound is John-initiated, not bulk. Safe.
- ⚠️ AUP "may be changed from time to time at the discretion of the Company." Not grounds for early termination. Standard.

## SLA

- **99.99% network uptime** measured at DC edge. Cash refund, not service credit, automatic.
- Refund schedule (FAQ restates):
  - 99.0–99.9% = 15% refund
  - 97.0–99.0% = 30% refund
  - 95.0–97.0% = 50% refund
  - <95% = 100% refund
- Max credit per incident = 100% of monthly fee for the affected service.
- Excludes: scheduled maintenance (≥48h notice), customer-caused issues (DDoS from your box counts), force majeure, individual hardware failures (covered separately).
- Real-world: AIW's two Servarica hosts have been stable since migration; no SLA claims needed.

## Billing & payment

- Monthly billing, anniversary date. **Suspends at 3 days past due** — important: if your Servarica payment fails, the box goes dark. Cron morning-brief already flags Servarica invoice status on the 1st of each month.
- Payment methods: PayPal, Alipay, all major cards, **crypto (BTC, ETH)** accepted. No ACH/wire for <$200.
- 7-day money-back guarantee on first VPS order (once per client, excludes processor fees, crypto refunds only as account credit).
- Refunds: generally non-refundable after day 7. Crypto refunds never return to wallet.
- Setup fee (one-time) non-refundable.

## Provisioning & lifecycle

- VPS provision: ~10 minutes after order. Some orders go through fraud review (several hours).
- Panel: WHMCS at clients.servarica.com. Same panel AIW uses.
- OS: pick Ubuntu 24.04 LTS at order time.
- IPv4 included, IPv6 included.
- Test IP / Looking Glass: ping.servarica.com, speedtest.servarica.net — pre-buy latency check is encouraged.
- Cancellation: must go through the client area (no email-cancel).

## What to put on John's box

Same as Host B, scoped to one client:

1. Ubuntu 24.04, non-root sudo user, SSH keys only, password auth off.
2. Docker engine + compose plugin.
3. Hermes compose stack (`hermes` gateway on `--network host`, `hermes-dashboard` on 127.0.0.1:9119, share PID namespace via `pid: service:gateway`).
4. `~/.hermes` bind-mounted to `/opt/data` inside the container, **ownership pinned to 10000:10000**. All `docker exec hermes hermes …` as `-u hermes`, never root.
5. nftables: default-drop input, allow 22/80/443. SMTP+IRC egress blocked. Systemd drop-in to `systemctl restart docker` after any nftables reload.
6. Provider keys in `~/.hermes/.env`: MiniMax, ZAI, Moonshot/Kimi — whatever John has. Anthropic/OpenAI/Gemini as escalation tier. No keys logged, no keys visible in the dashboard.
7. Model routing default: cheap tier first, escalate on demand. If John's primary driver is "I burned through Cursor's quota, route my Cursor through Hermes to cheap models," `hermes proxy` (OpenAI-compatible) at the dashboard URL is what Cursor's "OpenAI Base URL" field points at.
8. Backup script: nightly rsync/borg of `~/.hermes/` to AIW's S3-compatible bucket. 30-day retention. Encrypted at rest. Off-host.

## John's laptop setup (he does, one-time)

1. SSH key in his `~/.ssh/`, public half added during provisioning.
2. Drop in `~/.config/systemd/user/hermes-tunnel.service`:
   ```
   [Unit]
   Description=SSH tunnel to Hermes VPS
   After=network.target
   [Service]
   ExecStart=/usr/bin/ssh -N -L 9119:127.0.0.1:9119 hermes@<server>
   Restart=always
   RestartSec=5
   [Install]
   WantedBy=default.target
   ```
3. `loginctl enable-linger $USER` then `systemctl --user enable --now hermes-tunnel`.
4. Hermes desktop → connect to remote gateway at `http://127.0.0.1:9119`. Token pinned via `HERMES_DASHBOARD_SESSION_TOKEN` on the server, same value in his `desktop.json`.

## Quote to send John

| Item | One-time | Monthly |
|---|---|---|
| V2 KVM Slim Slice 4 (4 vCPU / 16 GB / 500 GB NVMe) | — | $12 |
| Setup: provision + harden + install + wire keys + walkthrough | TBD | — |
| Retainer: updates, monitoring, key rotation, restore drill (quarterly) | — | TBD |
| AI usage: pass-through, itemised on invoice | — | actual cost |
| Backups to AIW S3 bucket, 30-day retention | included | included |

**Decide for the quote:** setup fee and retainer numbers. Match your existing client-tier pattern (Ometz A/B/C or similar). Server + AI usage pass through with no markup; your time is the markup.

## Risks / things to flag to John before sign-off

1. **Stock is volatile.** V2 plans are in stock today (2026-08-12); V3 plans all show "Out of stock." The plan list rotates. If a plan goes OOS mid-cycle, you can't resize to it — you'd have to migrate to a new server and 7-day MBG only covers the new order.
2. **3-day suspension if payment fails.** Worth wiring his card with auto-pay or having him pre-pay a few months.
3. **Montreal-only.** No multi-region option. Sub-10 ms to NYC, but ~120–180 ms to Europe. For John's "Cursor over Hermes" use case (sitting wherever he is, hitting your LiteLLM which is Miami), the extra leg adds ~80–150 ms per call vs. a Miami-based box. Cheap models with high tokens/sec absorb this. Not a blocker.
4. **Provider-side backups not included.** AIW's S3 backup is the only copy. Servarica snapshots exist but are not a substitute.
5. **Data sovereignty bonus.** If John cares about Canadian/PIPEDA + Quebec Law 25 over US Patriot Act — Montreal is genuinely a sellable advantage. AIW's choice of Servarica for the same reason.
6. **Cancellation is one-way from John's side.** He cancels through the client area; if his card fails and the 3-day timer runs out, the box is gone and so is anything not backed up. Belt-and-braces: pre-pay a quarter.

## Decision matrix if John pushes back on Servarica

| If he wants | Alternative | Trade-off |
|---|---|---|
| Closer to Miami (your LiteLLM) | Hetzner Ashburn, DO NYC, Vultr Miami | 2–5× the price, similar reliability, no AIW precedent on that provider |
| Closer to John himself | Hetzner EU (FSN1/NBG), OVH EU | AIW has no operational history with either; +24–48 h on first incident |
| Multi-region failover | Servarica is wrong fit — go Hetzner + DO | more $, more ops surface |
| GPU for local LLM | Servarica has Bee dedicated GPU VPS ($79/mo, in-stock status unknown) or Hetzner GPU | Adds $40–60+/mo; only justified if he wants to run a local 7B+ model |

For "Cursor on laptop, Hermes on cheap models, fallbacks to frontier" — **Servarica Montreal is a good fit**, primarily because (a) you already operate two there and know the failure modes, (b) price is ~10× under the equivalent Hetzner/OVH/DO box for the same specs, (c) Montreal's PIPEDA + Quebec Law 25 is a privacy story John can sell himself if he cares.

---

## What to do next, in order

1. **Confirm John's budget ceiling for monthly retainer + setup.** Without that, you can't quote.
2. **Test latency from John's location to Montreal** (`ping.servarica.com`) — a 200 ms pinger kills the cheap-model-routing value prop.
3. **Order the box** on your Servarica account, Ubuntu 24.04, V2 KVM Slim Slice 4 monthly. Capture the IP and root password.
4. **Harden & install** (nftables, docker, Hermes, backup). ~1 hour.
5. **Wire keys** when John sends MiniMax/ZAI/Kimi/etc.
6. **Send John the laptop setup doc** (3 steps + the systemd unit).
7. **First check-in at end of month 1:** confirm cheap-tier is actually serving his Cursor traffic, itemise AI usage, send the first invoice.