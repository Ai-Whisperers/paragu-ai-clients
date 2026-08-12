# John's Laptop Setup — Connect to Your Private Hermes VPS

**Server:** `38.9.96.186` (Servarica, Montreal)
**User:** `hermes`
**Dashboard token:** `7xmKDbzTeiDzkOqlPklzQxgvDqibfPAagt93C3ymkkT`

This takes about 10 minutes. Run every step on **your laptop** (not the server).

---

## 1. Install the SSH key

The operator sent you a file called something like `john-servarica-id_ed25519` (the
**private** key). Save it to `~/.ssh/john-servarica/id_ed25519` on your laptop:

```bash
mkdir -p ~/.ssh/john-servarica
# Move the file the operator sent you into that folder, then:
chmod 700 ~/.ssh/john-servarica
chmod 600 ~/.ssh/john-servarica/id_ed25519
```

Verify the key is loaded (you should see `id_ed25519` listed, no errors):

```bash
ssh-keygen -y -f ~/.ssh/john-servarica/id_ed25519
```

That should print a line starting with `ssh-ed25519 AAAA...`. If it asks for a
passphrase, the operator may have set one — enter it.

---

## 2. Add the SSH config block

Open (or create) `~/.ssh/config` on your laptop and add this block at the end:

```
# John Hermes VPS — Servarica Montreal
Host john-hermes
    HostName 38.9.96.186
    User hermes
    Port 22
    IdentityFile ~/.ssh/john-servarica/id_ed25519
    IdentitiesOnly yes
    ServerAliveInterval 30
    ServerAliveCountMax 4
    LocalForward 9119 127.0.0.1:9119
```

Make sure the file's permissions are right:

```bash
chmod 600 ~/.ssh/config
```

Test it:

```bash
ssh john-hermes
```

If you get a shell prompt ending in `hermes@WPG` (or similar) — you're in.
Type `exit` to come back out.

---

## 3. Auto-tunnel the dashboard (so you don't have to remember)

This makes your laptop always forward port 9119 → the VPS, even after you close
the lid or reboot. One-time setup:

Create the file `~/.config/systemd/user/hermes-tunnel.service`:

```bash
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/hermes-tunnel.service <<'EOF'
[Unit]
Description=SSH tunnel to Hermes VPS
After=network.target

[Service]
ExecStart=/usr/bin/ssh -N -L 9119:127.0.0.1:9119 john-hermes
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF
```

Then enable it:

```bash
# Linux only — make user services survive logout
loginctl enable-linger $USER

systemctl --user daemon-reload
systemctl --user enable --now hermes-tunnel.service
systemctl --user status hermes-tunnel.service
```

You should see `active (running)`. Now `http://127.0.0.1:9119` on your laptop
is the same as the dashboard on the VPS — and it auto-reconnects.

> **macOS note:** `systemd --user` doesn't exist by default. Use
> `launchctl` instead, or just keep a Terminal open with
> `ssh -N -L 9119:127.0.0.1:9119 john-hermes`. Ask the operator for the
> macOS launchd plist if you want it auto-started.

---

## 4. Install Hermes Desktop

Download the installer for your OS from the official site:

- **macOS:** [Hermes Desktop download](https://hermes-agent.nousresearch.com/docs/)
- **Linux:** AppImage from the same page
- **Windows:** MSI from the same page

Install it like any other app.

---

## 5. Connect Hermes Desktop to your VPS gateway

Open Hermes Desktop. On first launch it'll ask how to connect:

1. Pick **"Connect to remote gateway"** (not "local").
2. **URL:** `http://127.0.0.1:9119`
3. **Session token:** paste the dashboard token from the top of this doc:
   ```
   7xmKDbzTeiDzkOqlPklzQxgvDqibfPAagt93C3ymkkT
   ```
4. Save.

You should see the Hermes dashboard with the green "Gateway running" indicator.

If you see "401 Unauthorized" — your token in `desktop.json` doesn't match the
server. Re-check step 5.3.

If you see "Connection refused" — the tunnel isn't up. Run
`systemctl --user status hermes-tunnel.service` and check.

---

## 6. First-time Hermes setup (one-time, on the VPS)

Now you need to give Hermes your model API keys and pick a default model.
The easiest way is to SSH in and run the wizard:

```bash
ssh john-hermes
hermes setup
```

The wizard walks you through:

- Default model (pick the cheapest one that handles your workload —
  Aliyun DashScope `qwen-turbo` or `glm-4.6` is a good default)
- API keys for each provider you want (paste them when prompted; they're
  stored in `~/.hermes/.env`, never logged)
- Display preferences

After `hermes setup` finishes, **restart the gateway** so it picks up the new keys:

```bash
ssh john-hermes 'cd ~/hermes-agent && docker compose restart'
```

Wait ~30 seconds, then refresh Hermes Desktop. The "Gateway running" indicator
should stay green and `active_sessions` should be > 0.

---

## 7. Wire Cursor (if you want)

The whole point of routing through Hermes is so Cursor's traffic goes to cheap
models by default. In Cursor:

1. **Settings → Models → OpenAI API Key**
2. Change the base URL to: `http://127.0.0.1:9119/v1`
3. Paste any non-empty string as the API key (Hermes ignores it; it
   authenticates by the `Authorization: Bearer` header being present).
4. Save.

Now Cursor's chat will route through Hermes → your cheap-model default, with
auto-escalation to frontier models on demand.

---

## Daily use

- Make sure the tunnel is running: `systemctl --user status hermes-tunnel`
- Open Hermes Desktop — it connects automatically
- Use Hermes as normal

If the dashboard says "Gateway stopped", restart on the server:

```bash
ssh john-hermes 'cd ~/hermes-agent && docker compose restart'
```

---

## Need help?

Ping the operator with:

- The output of `ssh john-hermes 'docker compose -f ~/hermes-agent/docker-compose.yml ps'`
- The output of `ssh john-hermes 'docker logs --tail 50 hermes'`

That tells them 90% of what's wrong without further questions.
