#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="valkey"
CONFIG_FILE="/etc/valkey/valkey.conf"
BACKUP_SUFFIX="$(date +%F-%H%M%S)"

echo "[1/8] Checking root privileges..."
if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo bash $0"
  exit 1
fi

echo "[2/8] Installing Valkey..."
apt-get update
apt-get install -y valkey

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Config file not found at $CONFIG_FILE"
  exit 1
fi

echo "[3/8] Backing up existing config..."
cp "$CONFIG_FILE" "${CONFIG_FILE}.bak.${BACKUP_SUFFIX}"

echo "[4/8] Writing secure local-only in-memory config..."
cat > "$CONFIG_FILE" <<'EOF'
##################################
# Minimal Valkey config for local-only ephemeral use
##################################

bind 127.0.0.1
protected-mode yes
port 6379

# systemd integration
supervised systemd
daemonize no

# Logging
loglevel notice
logfile ""

# No persistence
save ""
appendonly no

# Keep defaults simple
databases 16
timeout 0
tcp-keepalive 300

# Working directory
dir /var/lib/valkey
EOF

echo "[5/8] Ensuring data dir ownership..."
mkdir -p /var/lib/valkey
chown -R valkey:valkey /var/lib/valkey

echo "[6/8] Creating redis-cli compatibility wrapper..."
cat > /usr/local/bin/redis-cli <<'EOF'
#!/usr/bin/env bash
exec /usr/bin/valkey-cli "$@"
EOF
chmod +x /usr/local/bin/redis-cli

echo "[7/8] Enabling and restarting service..."
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

echo "[8/8] Verifying service..."
systemctl --no-pager --full status "$SERVICE_NAME" || true
sleep 1
valkey-cli ping
redis-cli ping

echo
echo "Done."
echo "Valkey is installed, starts on boot, listens only on 127.0.0.1, has no disk persistence,"
echo "and redis-cli now forwards to valkey-cli."