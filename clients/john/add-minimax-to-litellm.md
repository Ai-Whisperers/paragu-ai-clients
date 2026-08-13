
# ADD MINIMAX-M3 TO LITELLM PROXY — operator steps on Host A (38.9.96.179)

## Step 1 — Get the current litellm.yml

    sudo cat /opt/stacks/ai-whisperers-central/litellm.yml | head -120

Look for the `model_list:` section. It should look roughly like:

    model_list:
      - model_name: primary
        litellm_params:
          model: cerebras/gpt-oss-120b
          ...
      - model_name: fast
        litellm_params:
          model: cerebras/zai-glm
          ...
      ...

## Step 2 — Add MiniMax-M3 model entry

Append this entry to the `model_list:` list (alongside the others):

    - model_name: MiniMax-M3
      litellm_params:
        model: anthropic/MiniMax-M3
        api_key: os.environ/MINIMAX_API_KEY
        api_base: https://api.minimax.io/anthropic
        # Anthropic-format requires this header on every request
        extra_headers:
          anthropic-version: "2023-06-01"

Notes:
- `anthropic/MiniMax-M3` tells LiteLLM to use the Anthropic SDK against MiniMax's
  anthropic-compatible endpoint. We tested this earlier — it returns proper usage data.
- `os.environ/MINIMAX_API_KEY` reads from the container env (we set it on John's
  box already; needs to be added to the LiteLLM container too — next step).
- If you'd rather use the openai-compat variant (also tested), swap to:

    - model_name: MiniMax-M3
      litellm_params:
        model: openai/MiniMax-M3
        api_key: os.environ/MINIMAX_API_KEY
        api_base: https://api.minimax.io/v1

  (Use the anthropic variant — better cost reporting.)

## Step 3 — Inject MINIMAX_API_KEY into the litellm container

The proxy container needs the key in its env. The swarm stack file is the
cleanest place. Edit `/opt/stacks/ai-whisperers-central/litellm.yml` and under
the `litellm:` service, add an `environment:` block (or extend the existing one):

    services:
      litellm:
        # ... existing config ...
        environment:
          MINIMAX_API_KEY: "<YOUR_MINIMAX_API_KEY>"

(Or, more safely, use a docker secret: see below.)

## Step 4 — Redeploy the stack

    cd /opt/stacks/ai-whisperers-central
    sudo docker stack deploy -c litellm.yml litellm

Watch the rollout:

    watch -n 2 'sudo docker service ls | grep litellm'

Wait until `REPLICAS` shows `1/1` (was 0/1 during update).

## Step 5 — Verify MiniMax is reachable through the proxy

From any box that can reach llm.paragu-ai.com (the laptop is fine):

    curl -s -X POST https://llm.paragu-ai.com/v1/chat/completions \\
      -H "Authorization: Bearer sk-her..." \\
      -H "Content-Type: application/json" \\
      -d '{"model":"MiniMax-M3","messages":[{"role":"user","content":"PONG?"}],"max_tokens":30}'

Expected: a chat.completion object with `model: "MiniMax-M3"`, content="PONG"
(or similar), and usage data.

## Step 6 — Re-generate John's key with MiniMax-M3 in the allowlist

Tell me when step 5 works, and I'll re-generate John's virtual key with:

    "models": ["all"]   # or specify ["MiniMax-M3", "primary", "fast", "zai-glm-4-flash"]

Then re-point John's `API_SERVER_KEY` setup at llm.paragu-ai.com/v1 (instead of
talking to MiniMax direct), and the spend attribution starts working.

## Optional: store MINIMAX_API_KEY as a docker secret instead of plaintext env

More secure; takes a few more commands:

    echo -n 'sk-cp-rc...K8TA' | sudo docker secret create minimax_api_key -

Then in `litellm.yml`:

    services:
      litellm:
        secrets:
          - minimax_api_key
        # reference as os.environ/MINIMAX_API_KEY from inside the container

Redeploy. The key never lives in plaintext in the stack file.

---
