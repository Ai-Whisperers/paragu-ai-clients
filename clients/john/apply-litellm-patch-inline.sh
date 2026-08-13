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

# 3. Splice after the or-nemotron-nano block
sudo awk '
  /^- model_name: or-nemotron-nano$/ { inblock=1 }
  inblock && /^  model_info:/           { in_block_info=1 }
  in_block_info && /^    output_cost_per_token: 0.0$/ {
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
/usr/bin/python3 -c "
import yaml, sys
with open('$CONFIG') as f:
    c = yaml.safe_load(f)
print('model_list entries: ' + str(len(c['model_list'])))
matches = [m for m in c['model_list'] if m['model_name'] == 'MiniMax-M3']
if len(matches) == 1:
    p = matches[0]['litellm_params']
    print('MiniMax-M3 -> ' + p['model'] + ' via ' + p['api_base'])
else:
    print('ERROR: MiniMax-M3 found ' + str(len(matches)) + ' times, expected 1')
    sys.exit(1)
"

# 5. Add MINIMAX_API_KEY to .env.litellm
if ! sudo grep -q '^MINIMAX_API_KEY=' "$ENVFILE" 2>/dev/null; then
  echo "MINIMAX_API_KEY=$MINIMAX_KEY" | sudo tee -a "$ENVFILE" > /dev/null
fi
sudo chmod 600 "$ENVFILE"

# 6. Force-redeploy LiteLLM service to pick up new env + config
echo "=== redeploying litellm service ==="
sudo docker service update \
  --env-add "MINIMAX_API_KEY=$MINIMAX_KEY" \
  --force \
  litellm_litellm

# 7. Watch rollout
echo "=== watching rollout ==="
for i in 1 2 3 4 5 6 7 8 9 10; do
  state=$(sudo docker service ls --format '{{.Name}} {{.Replicas}}' | grep '^litellm_litellm ' || true)
  echo "  $state"
  if echo "$state" | grep -q '1/1'; then
    echo "  -> rolled out"
    break
  fi
  sleep 3
done

# 8. Verify MiniMax-M3 in /v1/models
echo "=== verify /v1/models ==="
curl -sS https://llm.paragu-ai.com/v1/models \
  -H "Authorization: Bearer sk-hermes-litellm-sunstein-2026" \
  | /usr/bin/python3 -c "
import sys, json
d = json.load(sys.stdin)
names = [m['id'] for m in d['data']]
print('  total models: ' + str(len(names)))
print(\"  'MiniMax-M3' present: \" + str('MiniMax-M3' in names))
"

echo
echo "=== DONE ==="
echo "Tell the AIW operator 'proxy is up'; they will:"
echo "  - run a chat test through the proxy with John's key"
echo "  - re-point John's gateway at the proxy"
echo "  - set up spend attribution"
