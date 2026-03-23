#!/usr/bin/env bash
set -euo pipefail

# Canonical systemd unit (Ubuntu/Debian: valkey.service is an alias; enable must use the real unit).
SERVICE_NAME="valkey-server"
CONFIG_FILE="/etc/valkey/valkey.conf"
BACKUP_SUFFIX="$(date +%F-%H%M%S)"

echo "[1/9] Checking root privileges..."
if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo bash $0"
  exit 1
fi

echo "[2/9] Removing redis-tools if present (avoids /usr/bin/redis-cli vs wrapper conflict)..."
if dpkg -s redis-tools &>/dev/null; then
  apt-get remove -y redis-tools
else
  echo "redis-tools not installed, skipping."
fi

echo "[3/9] Installing Valkey..."
apt-get update
apt-get install -y valkey

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Config file not found at $CONFIG_FILE"
  exit 1
fi

echo "[4/9] Backing up existing config..."
cp "$CONFIG_FILE" "${CONFIG_FILE}.bak.${BACKUP_SUFFIX}"

echo "[5/9] Writing secure local-only in-memory config..."
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

# Obfuscate dangerous commands (call via NFLUSHDB instead of FLUSHDB)
rename-command FLUSHDB NFLUSHDB

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

echo "[6/9] Ensuring data dir ownership..."
mkdir -p /var/lib/valkey
chown -R valkey:valkey /var/lib/valkey

echo "[7/9] Creating redis-cli compatibility wrapper..."
cat > /usr/local/bin/redis-cli <<'EOF'
#!/usr/bin/env bash
exec /usr/bin/valkey-cli "$@"
EOF
chmod +x /usr/local/bin/redis-cli

echo "[8/9] Enabling and restarting service..."
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

echo "[9/9] Verifying service..."
systemctl --no-pager --full status "$SERVICE_NAME" || true
sleep 1
valkey-cli ping
redis-cli ping

echo
echo "Done."
echo "Valkey is installed, starts on boot, listens only on 127.0.0.1, has no disk persistence,"
echo "and redis-cli now forwards to valkey-cli."