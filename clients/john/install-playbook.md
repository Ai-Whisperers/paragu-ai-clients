# Hermes VPS Install Playbook

Verified install path for a single-client Hermes VPS on Servarica (or any
Ubuntu 24.04+/26.04 LTS KVM host). Mirrors the Host B production pattern
(`paragu-ai` → `38.9.96.180`).

Tested 2026-08-12 on Servarica V2 KVM Slim Slice 2 (Ubuntu 26.04,
kernel 7.0.0-14-generic, 2 vCPU / 8 GB / 250 GB NVMe).

## 0. Pre-flight on the operator laptop

```bash
mkdir -p ~/.ssh/john-servarica
ssh-keygen -t ed25519 -f ~/.ssh/john-servarica/id_ed25519 -N "" \
  -C "ivan@ai-whisperers.local // Servarica VPS for <client>"
```

Add the SSH config block (one per VPS):

```
Host <client>-hermes
    HostName <NEW_IP_AFTER_PROVISION>
    User hermes
    Port 22
    IdentityFile ~/.ssh/<client>-servarica/id_ed25519
    IdentitiesOnly yes
    ServerAliveInterval 30
    ServerAliveCountMax 4
    RequestTTY no
    LocalForward 9119 127.0.0.1:9119
```

## 1. Order the box

- Servarica → VPS → V2 KVM Slim Slice 2 (or 4 for more RAM)
- VM Template: **Ubuntu 24.04 LTS** if available (Ubuntu 26.04 also works)
- Bandwidth: leave on "10 Gbps for first 8 TB/month"
- SSH Public Key: paste the public half of the new ed25519 key

## 2. Wait for provisioning (~10 min)

The portal will show "Page Not Available — process of creating a VM is in progress". Poll SSH until it accepts:

```bash
ssh -F /dev/null -i ~/.ssh/<client>-servarica/id_ed25519 \
  -o ConnectTimeout=8 -o BatchMode=yes root@<NEW_IP> 'echo up'
```

## 3. Bootstrap (root, one shot)

```bash
ssh root@<NEW_IP>  # with the new key
```

Once in, run (as root):

```bash
export DEBIAN_FRONTEND=noninteractive
systemctl stop unattended-upgrades.service
systemctl disable unattended-upgrades.service

# Drop cloud-init SSH override (would re-enable password auth)
rm -f /etc/ssh/sshd_config.d/50-cloud-init.conf

# SSH hardening drop-in
cat > /etc/ssh/sshd_config.d/99-aiw-hardening.conf <<'EOF'
PasswordAuthentication no
PermitRootLogin prohibit-password
PubkeyAuthentication yes
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
AllowAgentForwarding yes
AllowTcpForwarding yes
EOF

apt-get update -qq
apt-get install -y -qq sudo curl git ca-certificates gnupg jq rsync fail2ban ufw acl

# Non-root user
useradd -m -s /bin/bash -G sudo hermes
echo "hermes ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/hermes
chmod 440 /etc/sudoers.d/hermes

# Authorise key for hermes
mkdir -p /home/hermes/.ssh
cp /root/.ssh/authorized_keys /home/hermes/.ssh/authorized_keys
chown -R hermes:hermes /home/hermes/.ssh
chmod 700 /home/hermes/.ssh
chmod 600 /home/hermes/.ssh/authorized_keys

sshd -t && systemctl reload sshd
```

Verify password auth really off:
```bash
ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no \
  root@<NEW_IP>  # should fail with "Permission denied (publickey)"
```

## 4. nftables + docker-restart drop-in (as root)

```bash
which ufw && ufw disable || true

cat > /etc/nftables.conf <<'EOF'
flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        ct state established,related accept
        ct state invalid drop
        iif lo accept
        ip protocol icmp limit rate 4/second accept
        ip6 nexthdr icmpv6 limit rate 4/second accept
        tcp dport 22 accept
        tcp dport { 80, 443 } accept
    }
    chain forward {
        type filter hook forward priority 0; policy drop;
        ct state established,related accept
    }
    chain output {
        type filter hook output priority 0; policy accept;
        tcp dport { 25, 465, 587, 2525 } reject with tcp reset
        tcp dport { 6660-6669, 6697 } reject with tcp reset
    }
}
EOF
nft -c -f /etc/nftables.conf
systemctl enable nftables.service
systemctl restart nftables.service

mkdir -p /etc/systemd/system/nftables.service.d
cat > /etc/systemd/system/nftables.service.d/90-restart-docker.conf <<'EOF'
[Service]
ExecStartPost=/bin/systemctl restart docker.service
EOF
systemctl daemon-reload
```

## 5. Docker (with buildx host-network — critical!)

```bash
apt-get install -y -qq ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $CODENAME stable" > /etc/apt/sources.list.d/docker.list
apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
usermod -aG docker hermes
systemctl enable docker.service
systemctl restart docker.service
```

**Why the buildx setup matters:** the bundled Dockerfile builds SQLite from
source and pulls Node 26 from a multi-stage build. Default buildx networking
gets stuck on `apt-get update` inside the buildkit namespace (8+ min hangs).
Fix once per box:

```bash
docker buildx rm hermes-builder 2>/dev/null || true
docker buildx create --name hermes-builder --driver docker-container \
  --driver-opt network=host --use
docker buildx inspect --bootstrap

# Also pin daemon DNS so apt mirrors resolve predictably
cat > /etc/docker/daemon.json <<'EOF'
{
  "dns": ["1.1.1.1", "8.8.8.8"]
}
EOF
systemctl restart docker
```

## 6. Hermes stack

```bash
# Clone (operator does as hermes, not root)
sudo -u hermes bash <<'EOF'
cd ~
git clone https://github.com/NousResearch/hermes-agent.git hermes-agent
EOF

# Pre-create the state dir + remap user
groupadd -g 10000 hermes-runtime
useradd -u 10000 -g 10000 -M -s /usr/sbin/nologin hermes-runtime
mkdir -p /home/hermes/.hermes
chown -R 10000:10000 /home/hermes/.hermes
chown -R hermes:hermes /home/hermes/hermes-agent

# Generate dashboard token
DASHBOARD_TOKEN=$(openssl rand -base64 33 | tr -d '/+=' | cut -c1-43)
echo "DASHBOARD TOKEN: $DASHBOARD_TOKEN"   # SAVE THIS — give to client
```

Edit `/home/hermes/hermes-agent/docker-compose.yml`:
- Drop the `mem0` service block (not part of baseline)
- Confirm `HERMES_DASHBOARD_SESSION_TOKEN` env value matches the token

Create `/home/hermes/hermes-agent/.env`:
```
HERMES_UID=10000
HERMES_GID=10000
HERMES_DASHBOARD_SESSION_TOKEN=<the token above>
```

Build:
```bash
sudo -u hermes docker buildx use hermes-builder
sudo -u hermes DOCKER_BUILDKIT=1 docker build --network=host \
  -t hermes-agent:latest -f Dockerfile .   # ~5 minutes
```

Start:
```bash
cd /home/hermes/hermes-agent
sudo -u hermes docker compose up -d
sudo -u hermes docker compose ps   # both should be Up
```

Verify:
```bash
sudo -u hermes curl -s http://127.0.0.1:9119/api/status | jq '{version, gateway_running, gateway_state}'
```

Expected: `"gateway_running": true, "gateway_state": "running"` after ~60s.

## 7. Backup script

```bash
apt-get install -y -qq rclone

mkdir -p /home/hermes/.hermes-backup /home/hermes/.local/bin /home/hermes/.config/rclone

cat > /home/hermes/.local/bin/hermes-backup.sh <<'BACKUP_EOF'
#!/bin/bash
set -euo pipefail
LOG="/home/hermes/.hermes-backup/backup.log"
TS=$(date -u +%Y-%m-%dT%H:%MZ)
REMOTE="aiw-hermes-backups:<client>-hermes"
LOCAL="/home/hermes/.hermes"
RETENTION_DAYS=30
echo "[$TS] backup starting" >> "$LOG"
rclone sync "$LOCAL" "$REMOTE/$(date -u +%Y/%m/%d)" \
    --exclude ".playwright/**" --exclude ".cache/**" --exclude "logs/**" \
    --transfers 4 --checkers 8 --log-file "$LOG" --log-level INFO
echo "[$TS] trimming backups older than $RETENTION_DAYS days" >> "$LOG"
rclone delete "$REMOTE" --min-age "${RETENTION_DAYS}d" --log-file "$LOG" --log-level INFO
rclone rmdirs "$REMOTE" --leave-root --log-file "$LOG" --log-level INFO 2>/dev/null || true
echo "[$TS] backup complete" >> "$LOG"
BACKUP_EOF
chmod +x /home/hermes/.local/bin/hermes-backup.sh

cat > /home/hermes/.config/rclone/rclone.conf <<'RCLONE_EOF'
[aiw-hermes-backups]
type = s3
provider = Other
access_key_id = REPLACE_ME
secret_access_key = REPLACE_ME
endpoint = https://REPLACE_ME.example.com
no_check_bucket = true
RCLONE_EOF
chmod 600 /home/hermes/.config/rclone/rclone.conf

echo "17 3 * * * hermes /home/hermes/.local/bin/hermes-backup.sh" | \
  sudo tee /etc/cron.d/hermes-backup > /dev/null
chmod 644 /etc/cron.d/hermes-backup
chown -R hermes:hermes /home/hermes/.local /home/hermes/.hermes-backup /home/hermes/.config/rclone
```

## 8. Handoff to client

1. Send the client:
   - IP address
   - Dashboard session token (from `/home/hermes/hermes-agent/.env`)
   - Three-step laptop setup: SSH key → SSH config → systemd tunnel → Hermes desktop
2. Client runs `hermes setup` on first connect (provider keys, model defaults)
3. Client supplies:
   - Provider API keys (MiniMax, ZAI, Kimi, Anthropic, OpenAI, Gemini)
   - rclone S3 bucket creds (or operator fills in the template)
   - Any messaging-platform tokens (Telegram bot, etc.)

## 9. Operator recurring

```bash
# Monthly health check
ssh hermes@<IP> 'cd /home/hermes/hermes-agent && docker compose ps'
ssh hermes@<IP> 'sudo tail -5 /home/hermes/.hermes-backup/backup.log'
ssh hermes@<IP> 'df -h /'

# Quarterly restore drill
# - rclone copy latest snapshot to /tmp/restore
# - diff against live state
# - delete restore dir

# Updates (Hermes ships often)
ssh hermes@<IP> 'cd /home/hermes/hermes-agent && git pull && \
  docker compose build gateway && docker compose up -d'
```

## Common failures (and fixes)

| Symptom | Cause | Fix |
|---|---|---|
| `apt-get update` hangs for 8+ min in Dockerfile | buildkit worker network namespace can't resolve Debian mirrors | `docker buildx create --driver-opt network=host` |
| Dashboard `/api/status` returns 405 on HEAD | uvicorn rejects HEAD on this path; use GET | `curl -s .../api/status` |
| `gateway_running: false` immediately after up | Sidecar IPC hasn't populated yet; gateway process IS running | Wait 30-60s, re-poll |
| `Permission denied` on /home/hermes/.hermes from hermes user | Container created files as UID 10000 but host user `hermes` is UID 1000 | Always `docker exec -u hermes`; never root |
| Cloud-init resets sshd to allow passwords on reboot | `50-cloud-init.conf` re-enables `PasswordAuthentication yes` | `rm /etc/ssh/sshd_config.d/50-cloud-init.conf` |
| Two `docker compose build` processes running | Earlier `nohup` build survived a Ctrl-C | `pkill -f "docker compose build"` first |
