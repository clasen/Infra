#!/usr/bin/env bash
set -euo pipefail

# Canonical systemd unit for Ubuntu/Debian.
SERVICE_NAME="redis-server"
CONFIG_FILE="/etc/redis/redis.conf"
BACKUP_SUFFIX="$(date +%F-%H%M%S)"

echo "[1/9] Checking root privileges..."
if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo bash $0"
  exit 1
fi

echo "[2/9] Refreshing APT package index..."
apt-get update

echo "[3/9] Installing stable Redis packages from Ubuntu repositories..."
if ! apt-cache show redis-server &>/dev/null; then
  echo "ERROR: Package 'redis-server' was not found in current APT sources."
  echo "Verify your Ubuntu repositories are enabled and run apt-get update."
  exit 1
fi
apt-get install -y redis-server redis-tools

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Config file not found at $CONFIG_FILE"
  exit 1
fi

echo "[4/9] Backing up existing config..."
cp "$CONFIG_FILE" "${CONFIG_FILE}.bak.${BACKUP_SUFFIX}"

echo "[5/9] Writing secure local-only in-memory config..."
cat > "$CONFIG_FILE" <<'EOF'
##################################
# Minimal Redis config for local-only ephemeral use
##################################

bind 127.0.0.1 ::1
protected-mode yes
port 6379

# systemd integration
supervised systemd
daemonize no

# Logging
loglevel notice
logfile ""

# Obfuscate dangerous commands (call via N* names instead)
rename-command FLUSHALL NFLUSHALL
rename-command FLUSHDB NFLUSHDB

# No persistence
save ""
appendonly no

# Keep defaults simple
databases 16
timeout 0
tcp-keepalive 300

# Working directory
dir /var/lib/redis
EOF

echo "[6/9] Ensuring data dir ownership..."
mkdir -p /var/lib/redis
chown -R redis:redis /var/lib/redis

echo "[7/9] Enabling and restarting service..."
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

echo "[8/9] Verifying service..."
systemctl --no-pager --full status "$SERVICE_NAME" || true
sleep 1
redis-cli ping

echo "[9/9] Showing installed Redis version..."
redis-server --version

echo
echo "Done."
echo "Redis is installed, starts on boot, listens only on localhost, and has no disk persistence."
