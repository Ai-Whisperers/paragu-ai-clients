#!/bin/bash
set -euo pipefail

# ============================================================
# Add MiniMax-M3 to the LiteLLM proxy on Host A
# Run as root on paragu-ai (38.9.96.179)
# 2026-08-13 — built by AIW operator
# ============================================================

CONFIG=/opt/stacks/ai-whisperers-central/configs/litellm-config.yaml
ENVFILE=/opt/stacks/ai-whisperers-central/.env.litellm
SNIPPET=/tmp/MiniMax-M3.snippet
MINIMAX_KEY="<PASTE_MINIMAX_KEY_HERE>"

# 1. Backup
sudo cp -p "$CONFIG" "$CONFIG.bak-pre-minimax-2026-08-13"

# 2. Write the snippet to splice in
sudo tee "$SNIPPET" > /dev/null <<'EOF'
- model_name: MiniMax-M3
  litellm_params:
    model: anthropic/MiniMax-M3
    api_key: os.environ/MINIMAX_API_KEY
    api_base: https://api.minimax.io/anthropic
    drop_params: true
    additional_drop_params: *drop
    extra_headers:
      anthropic-version: "2023-06-01"
  model_info:
    mode: chat
    supports_tool_calling: true
    input_cost_per_token: 0.0
    output_cost_per_token: 0.0

EOF

# 3. Splice after the or-nemotron-nano block (last entry in the per-provider alias block).
sudo awk '
  /^- model_name: or-nemotron-nano$/ { inblock=1 }
  inblock && /^  model_info:/           { in_block_info=1 }
  in_block_info && /^    output_cost_per_token: 0.0$/ {
    # End of the or-nemotron-nano block — insert here
    print
    print ""
    while ((getline line < "'"$SNIPPET"'") > 0) print line
    close("'"$SNIPPET"'")
    inblock=0
    in_block_info=0
    next
  }
  { print }
' "$CONFIG" | sudo tee "$CONFIG.new" > /dev/null

sudo mv "$CONFIG.new" "$CONFIG"

# 4. Validate YAML
echo "=== validating patched config ==="
python3 -c "
import yaml, sys
with open('$CONFIG') as f:
    c = yaml.safe_load(f)
print(f'model_list has {len(c["model_list"])} entries')
matches = [m for m in c['model_list'] if m['model_name'] == 'MiniMax-M3']
if len(matches) == 1:
    p = matches[0]['litellm_params']
    print(f'MiniMax-M3 -> {p["model"]} via {p["api_base"]}')
else:
    print(f'ERROR: MiniMax-M3 found {len(matches)} times, expected 1')
    sys.exit(1)
"

# 5. Add MINIMAX_API_KEY to .env.litellm if not already there
if ! sudo grep -q '^MINIMAX_API_KEY=' "$ENVFILE" 2>/dev/null; then
  echo "MINIMAX_API_KEY=$MINIMAX_KEY" | sudo tee -a "$ENVFILE" > /dev/null
fi
sudo chmod 600 "$ENVFILE"

# 6. Redeploy the LiteLLM service to pick up new env + config (volume mount is
# read-only, but the container needs recreation for env vars; service update --force does it)
echo "=== redeploying litellm service ==="
sudo docker service update \
  --env-add "MINIMAX_API_KEY=$MINIMAX_KEY" \
  --force \
  litellm_litellm

# 7. Watch rollout
echo "=== watching rollout ==="
for i in 1 2 3 4 5 6 7 8 9 10; do
  state=$(sudo docker service ls --format '{{.Name}} {{.Replicas}}' | grep '^litellm_litellm ' || true)
  echo "$state"
  if echo "$state" | grep -q '1/1'; then
    echo "  -> rolled out"
    break
  fi
  sleep 3
done

# 8. Verify MiniMax-M3 is in /v1/models
echo "=== verify /v1/models has MiniMax-M3 ==="
curl -sS https://llm.paragu-ai.com/v1/models \
  -H "Authorization: Bearer sk-her...2026" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
names = [m['id'] for m in d['data']]
print(f'  models visible: {len(names)}')
print(f'  MiniMax-M3 present: {chr(34) + chr(77) + chr(105) + chr(110) + chr(105) + chr(77) + chr(97) + chr(120) + chr(45) + chr(77) + chr(51) + chr(34) in names}')
"

# 9. End-to-end chat test (use John's virtual key, full key in next command)
echo "=== end-to-end chat ==="
echo "  (next: tell AIW operator the proxy is up; they'll run the chat test with John's key)"

echo
echo "=== DONE ==="
echo "  - YAML patch applied, validated"
echo "  - MINIMAX_API_KEY injected into proxy env"
echo "  - LiteLLM service rolled out (config + env)"
echo "  - MiniMax-M3 visible in /v1/models"
echo
echo "Confirm to operator; they re-point John's /v1/chat/completions and verify"
echo "spend attribution. After that, run the audit-DB cron setup."
