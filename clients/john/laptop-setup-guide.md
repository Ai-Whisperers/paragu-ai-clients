# John Hermes Desktop — Complete Setup Guide

For John's Windows laptop. Run every step in PowerShell.

**Server:** `38.9.96.186` (Servarica, Montreal)
**User on server:** `hermes`
**Local URL on John's laptop:** `http://127.0.0.1:9119` (delivered via SSH tunnel)

---

## What you need before you start

| Item | Where it comes from |
|---|---|
| The dashboard session token | `ZR2cNQuR20lsSBTh0UnApm0UqKh2kCst8yTtISow1I3` |
| The OpenAI-compatible API key | `1ceea7453bca3dc7ff9a7029446b784f05c8760f633cb386239e8332d1380bc6` |
| The server's SSH public-key fingerprint (sanity check) | `SHA256:Wcaj1BSULA5qKJfdGOyzL/9rLif9w3R3qX8W+yDMbdQ` |

**Treat all three like passwords.** The dashboard token + API key let a
process on John's laptop drive the Hermes gateway as John. Don't paste them
in chat, screenshots, GitHub, etc. Save them in a password manager if you have one.

---

## Step 1 — Generate John's SSH key on his laptop

Open **PowerShell** (regular, no admin needed):

```powershell
ssh-keygen -t ed25519 -f "$HOME\.ssh\john-servarica\id_ed25519"
```

When prompted:
- **Passphrase:** pick something you'll remember. Required to use the key.
- Confirm: re-enter the passphrase.

The output will look like:

```
Your identification has been saved in C:\Users\John\.ssh\john-servarica\id_ed25519
Your public key has been saved in C:\Users\John\.ssh\john-servarica\id_ed25519.pub
```

**Display the public key (you'll send this to the operator):**

```powershell
Get-Content "$HOME\.ssh\john-servarica\id_ed25519.pub"
```

Copy the entire line (one line, starts with `ssh-ed25519 AAAA...`) and send
that to the operator. **Do not** send the private key (the file without `.pub`).

**Operator action:** they install the public key into the server and reply
"ssh key installed" before you continue to step 2.

---

## Step 2 — Add the SSH config block

Still in PowerShell, create or edit `~/.ssh/config`:

```powershell
# Make sure the directory exists
New-Item -ItemType Directory -Force -Path "$HOME\.ssh" | Out-Null

# Add John's host block at the end of ~/.ssh/config
@"
Host john-hermes
    HostName 38.9.96.186
    User hermes
    Port 22
    IdentityFile ~/.ssh/john-servarica/id_ed25519
    IdentitiesOnly yes
    ServerAliveInterval 30
    ServerAliveCountMax 4
    RequestTTY no
    LocalForward 9119 127.0.0.1:9119
"@ | Out-File -Append -FilePath "$HOME\.ssh\config" -Encoding ASCII

# Verify
Get-Content "$HOME\.ssh\config"
```

You should see the `john-hermes` block at the end.

**Sanity-check connection:**

```powershell
ssh john-hermes
```

If everything is right:
- First time: `Are you sure you want to continue connecting (yes/no/[fingerprint])?` — type `yes`
- Then the passphrase prompt — enter your key passphrase
- You land in a shell prompt that ends with `hermes@WPG:~ $` (or similar)
- Type `exit` to come back out

**Should it print the fingerprint and ask to verify it?**

Yes — the first time, OpenSSH prints the server's fingerprint:

```
The authenticity of host '38.9.96.186 (38.9.96.186)' can't be established.
ED25519 key fingerprint is SHA256:Wcaj1BSULA5qKJfdGOyzL/9rLif9w3R3qX8W+yDMbdQ.
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

**Compare that fingerprint** to the one in the "What you need" table above.
If they match, type `yes`. If they don't match, **stop** — something is
intercepting the connection; contact the operator.

---

## Step 3 — Auto-tunnel so the dashboard is always reachable

The tunnel forwards your laptop's `127.0.0.1:9119` to the server's
`127.0.0.1:9119`. Once it's running, your laptop's `http://127.0.0.1:9119`
is the Hermes dashboard.

### Option A — Always-on tunnel via Scheduled Task (recommended)

Run this PowerShell, **as Administrator** (right-click PowerShell → "Run as administrator"):

```powershell
# Create a Scheduled Task that runs the SSH tunnel at user logon, restarts on failure

$action = New-ScheduledTaskAction `
  -Execute "C:\Windows\System32\OpenSSH\ssh.exe" `
  -Argument "-N -L 9119:127.0.0.1:9119 john-hermes"

$trigger = New-ScheduledTaskTrigger -AtLogOn

$settings = New-ScheduledTaskSettingsSet `
  -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries `
  -RestartCount 999 `
  -RestartInterval (New-TimeSpan -Minutes 1)

Register-ScheduledTask `
  -TaskName "JohnHermesTunnel" `
  -Action $action `
  -Trigger $trigger `
  -Settings $settings `
  -RunLevel Highest `
  -Description "Persistent SSH tunnel to John's Hermes dashboard"
```

Now start it manually for the first time:

```powershell
Start-ScheduledTask -TaskName "JohnHermesTunnel"

# Wait 5 seconds, then verify the port forward is up
Test-NetConnection -ComputerName 127.0.0.1 -Port 9119
```

Expected:
- `TcpTestSucceeded : True`
- That's how you know the tunnel is live.

### Option B — Keep a terminal open with the tunnel

If you don't want a Scheduled Task:

```powershell
ssh -N -L 9119:127.0.0.1:9119 john-hermes
```

The tunnel runs as long as the terminal is open. Re-run whenever you
close/reopen PowerShell.

---

## Step 4 — Verify the dashboard is reachable through the tunnel

With the tunnel running (Option A or B), in a new PowerShell window:

```powershell
curl http://127.0.0.1:9119/api/status
```

If you see JSON like:
```json
{"version":"0.20.0","gateway_state":"running",...}
```

Then the tunnel + dashboard are working. If you see `Connection refused`,
the tunnel isn't up — go back to step 3.

---

## Step 5 — Install Hermes Desktop

Download from the official site:

- **Windows:** [Hermes Agent installers](https://hermes-agent.nousresearch.com/docs/) — pick the `.msi` or `.exe`
- **macOS / Linux:** same page, install as you would any other app

Run the installer with default options. If Windows asks
"allow this app from an unknown publisher" — Hermes is currently unsigned, so
click "More info" → "Run anyway" if you trust the source. (If you don't,
[verify the installer](https://hermes-agent.nousresearch.com/docs/) before running.)

After install, launch **Hermes Desktop**. On first run it'll show a setup wizard.

---

## Step 6 — Connect Hermes Desktop to the remote gateway

When Hermes Desktop asks "Where is your Hermes?", pick:

- **"Connect to remote gateway"** (NOT "Run a local one")

Then fill in:

| Field | Value |
|---|---|
| **Gateway URL** | `http://127.0.0.1:9119` |
| **Session token** | `ZR2cNQuR20lsSBTh0UnApm0UqKh2kCst8yTtISow1I3` |

Save. The dashboard should load with:
- Green check on "Gateway running"
- Version `0.20.0` visible somewhere

**Troubleshooting:**
- `Connection refused` → tunnel not up (Step 3)
- `401 Unauthorized` → token doesn't match; the operator can recheck what's in `/home/hermes/hermes-agent/.env`
- Slow load → first connect takes a moment to wake up the gateway; wait 10s and retry

---

## Step 7 — Configure Claude Code to use this same Hermes (optional but recommended)

Claude Code is an AI tool from Anthropic that runs in your terminal. To
make Claude Code on John's laptop talk to the same Hermes gateway (for
cheap models by default, or so John can run shell commands on the server
through Claude):

### 7a. Install Claude Code

Per Anthropic's install instructions. You'll need an Anthropic account.

### 7b. Point Claude Code at John's Hermes gateway as an OpenAI-compatible backend

In PowerShell:

```powershell
[System.Environment]::SetEnvironmentVariable(
  "ANTHROPIC_BASE_URL",
  "http://127.0.0.1:9119/v1",
  "User"
)

[System.Environment]::SetEnvironmentVariable(
  "OPENAI_API_KEY",
  "1ceea7453bca3dc7ff9a7029446b784f05c8760f633cb386239e8332d1380bc6",
  "User"
)
```

Then **open a new terminal** (the env vars only take effect for new processes).

To verify:
```powershell
curl http://127.0.0.1:9119/v1/models `
  -Headers @{ "Authorization" = "Bearer 1ceea7453bca3dc7ff9a7029446b784f05c8760f633cb386239e8332d1380bc6" }
```

Expected: a JSON object containing `"data": [{ "id": "hermes-agent", ... }]`.

Now when Claude Code runs, it talks to John's Hermes gateway instead of
Anthropic directly. The gateway decides which model to use (cheap by default,
frontier on demand — once a working MiniMax key is in place).

---

## Step 8 — First real conversation

Open Hermes Desktop. Type into the chat:

```
Reply with exactly one word: PONG
```

If the model's working, you get "PONG" back. If you get an error like
"upstream 401" or "invalid API key", the MiniMax provider key on the server
is still being set up. Wait, or contact the operator.

If "PONG" comes back: **everything works.** You're done.

---

## Daily use

- Make sure the tunnel is running: `Test-NetConnection -ComputerName 127.0.0.1 -Port 9119` (should print `TcpTestSucceeded : True`)
- Open Hermes Desktop
- Use it like any chat tool — the difference is that your traffic goes through your own server, not directly to model providers

---

## If something breaks

| Symptom | First check | Second check |
|---|---|---|
| `ssh john-hermes` says "Permission denied" | Passphrase wrong, or operator didn't install the key yet | Re-send your `.pub` file to operator |
| `ssh john-hermes` says "Connection timed out" | Internet is down, or `38.9.96.186` is unreachable | Try a different network; if persistent, ask operator |
| Dashboard "Connection refused" | Tunnel not running | Restart the Scheduled Task: `Restart-ScheduledTask -TaskName JohnHermesTunnel` |
| Dashboard "401 Unauthorized" | Token changed on server | Get the new token from operator, re-enter in Hermes Desktop |
| "Upstream authentication failed" on a chat | The MiniMax key on the server is wrong | Wait — operator needs to fix and restart |

---

## After setup

These are nice-to-haves, not required:

- **Add the dashboard token to a password manager** so you don't lose it
- **Save the SSH key passphrase** the same way
- **Test once a month** that the tunnel is alive — `Test-NetConnection -ComputerName 127.0.0.1 -Port 9119` should always say `TcpTestSucceeded : True`

---

## Reference — what each value means

- **Dashboard session token** (`ZR2cNQuR…`) — proves to the dashboard that
  the connecting Hermes Desktop is really yours. Set once, leave alone.
- **OpenAI API key** (`1ceea745…`) — proves to the gateway's API server
  (`/v1/chat/completions`) that the request is from a known client. Used by
  Claude Code and any other OpenAI-compatible tool you point at Hermes.
- **SSH key** (`id_ed25519`) — proves to the server that you're John.
  Stays on the laptop only.
