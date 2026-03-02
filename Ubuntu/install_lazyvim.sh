#!/usr/bin/env bash
set -euo pipefail

# Resolve target user/home
if [[ "${SUDO_USER:-}" != "" && "${SUDO_USER}" != "root" ]]; then
  TARGET_USER="$SUDO_USER"
  TARGET_HOME="$(eval echo "~$SUDO_USER")"
else
  TARGET_USER="$(id -un)"
  TARGET_HOME="$HOME"
fi

CONFIG_DIR="$TARGET_HOME/.config/nvim"
DATA_DIR="$TARGET_HOME/.local/share/nvim"
STATE_DIR="$TARGET_HOME/.local/state/nvim"
CACHE_DIR="$TARGET_HOME/.cache/nvim"

backup_if_exists() {
  local path="$1"
  if [[ -e "$path" ]]; then
    local backup="${path}.bak.$(date +%Y%m%d-%H%M%S)"
    echo "Backing up $path -> $backup"
    mv "$path" "$backup"
  fi
}

fix_ownership_if_needed() {
  if [[ "$(id -u)" -eq 0 ]]; then
    chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config" "$TARGET_HOME/.local" 2>/dev/null || true
  fi
}

echo "Installing for user: $TARGET_USER"
echo "Target home: $TARGET_HOME"

apt-get update
apt-get install -y git ripgrep curl unzip xclip

# Remove old apt neovim if present
apt-get remove -y neovim || true
apt-get autoremove -y || true

# Install latest stable Neovim official build
cd /tmp
rm -f nvim-linux-x86_64.tar.gz
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
rm -rf /opt/nvim-linux-x86_64
tar -C /opt -xzf nvim-linux-x86_64.tar.gz
ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim

# Optional Nerd Font download
rm -f /tmp/FiraCode.zip
curl -LO https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/FiraCode.zip

# Ensure base dirs exist
mkdir -p "$TARGET_HOME/.config" "$TARGET_HOME/.local/share" "$TARGET_HOME/.local/state" "$TARGET_HOME/.cache"

# Backup previous Neovim state if present
backup_if_exists "$CONFIG_DIR"
backup_if_exists "$DATA_DIR"
backup_if_exists "$STATE_DIR"
backup_if_exists "$CACHE_DIR"

# Install LazyVim starter
git clone https://github.com/LazyVim/starter "$CONFIG_DIR"
rm -rf "$CONFIG_DIR/.git"

fix_ownership_if_needed

echo
echo "Installed Neovim:"
nvim --version | head -n 1
echo
echo "LazyVim config installed at: $CONFIG_DIR"