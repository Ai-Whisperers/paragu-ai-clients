# Host A sshd — Restoration Recipe

**Symptom** (verified 2026-08-13 from sandbox):

```bash
$ sudo ss -tlnp | grep ':22'
LISTEN 0  4096  0.0.0.0:22  0.0.0.0:*  users:(("systemd",pid=1,fd=192))
LISTEN 0  4096     [::]:22     [::]:*  users:(("systemd",pid=1,fd=193))

$ sudo systemctl status sshd --no-pager
Unit sshd.service could not be found.
```

Port 22's socket exists, but no service is consuming the connection → systemd replies
"Connection refused" the moment anything connects.

**Most likely cause:** `apt-get uninstall openssh-server` or a similar cleanup removed
both the daemon and the service unit. The systemd socket survives because it's in
`/etc/systemd/system/ssh.service.d/` or as a system default.

## Safest restoration path (one shot)

Run as root on the **physical or VM console** of Host A (Servarica Slice 6, 38.9.96.179).
**Do not** try to script this over the broken SSH — you need actual root access:

```bash
sudo apt-get update -qq
sudo apt-get install -y --reinstall openssh-server
sudo systemctl enable --now sshd.service
```

That's the entire fix in 80% of cases. The systemd socket activates the moment `sshd.service`
is started, port 22 starts accepting real connections, and the existing
`authorized_keys` files are untouched (they survived the uninstall because the `openssh-sftp-server`
package doesn't own them).

## If `apt-get install --reinstall` refuses

It might, if you removed the package and the postrm hook purged the unit file:

```bash
# Re-add the service unit by hand
sudo tee /etc/systemd/system/sshd.service.d/override.conf > /dev/null <<EOF
[Service]
ExecStart=
ExecStart=/usr/sbin/sshd -D \$SSHD_OPTS
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now sshd.service
```

Or, the all-in-one:

```bash
sudo install -m 644 /lib/systemd/system/ssh.service /etc/systemd/system/sshd.service 2>/dev/null \
  || sudo tee /etc/systemd/system/sshd.service <<'EOF'
[Unit]
Description=OpenBSD Secure Shell server
After=network.target auditd.service
ConditionPathExists=!/etc/ssh/sshd_not_to_be_run

[Service]
Type=notify
EnvironmentFile=-/etc/default/ssh
ExecStartPre=/usr/sbin/sshd -t
ExecStart=/usr/sbin/sshd -D $SSHD_OPTS
ExecReload=/usr/sbin/sshd -t
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure
RestartPreventExitStatus=255
Type=notify

[Install]
WantedBy=multi-user.target
Alias=sshd.service
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now sshd.service
```

## Verify it landed

```bash
sudo systemctl is-active sshd
# expect: active

sudo ss -tlnp | grep ':22'
# expect: now shows "users:((\"sshd\",pid=...)" not just systemd
```

## Why the existing key still works

Your AIW sandbox `/opt/data/.ssh/id_ed25519` is unchanged. The **`authorized_keys` files on the
box** were preserved by `apt-get remove`. So as soon as sshd is back, the same key from the same
`ssh root@38.9.96.179` command works again.

## What happens after you tell me "sshd is back"

I (the operator agent) run from this sandbox:

```bash
ssh -i /opt/data/.ssh/id_ed25519 root@38.9.96.179
```

which gives us a shell on Host A. From there:

1. Apply the LiteLLM config patch (script at
   `clients/john/add-minimax-to-litellm.md` already prepared and on GitHub)
2. `docker service update --force litellm_litellm`
3. Verify `MiniMax-M3` appears in `/v1/models` on `llm.paragu-ai.com`
4. Re-point John's gateway traffic through the proxy (so spend is recorded under his virtual
   key rather than sampled from logs)
5. Optionally swap the audit/aggregate layer to query LiteLLM's spend DB instead of John's
   local logs

## Why I'm not running this myself

The previous "give the AI access" attempt (the `aiw-operator` user + scoped sudoers) ran into
the same sshd-down issue at the wrong moment — the key was installed but Host A stopped
accepting connections before we tested the path. **The installation is already done** on
the box (a user, a key, a sudoers file); you only need to restore sshd and the
`aiw-operator` user becomes available.

## What this does NOT change

The LiteLLM routing plan I had pre-baked: once sshd is back, ~10 minutes of operator time
brings MiniMax onto the proxy, then John's metering + invoicing flow continues to work
exactly as today — just with per-key attribution instead of log scraping. The
audit.db + cron + make-bill already running on John's VPS does not depend on Host A.

---

*Compiled 2026-08-13 from the operator session.*
