#!/usr/bin/env bash
set -euo pipefail

# Install LazyVim + Neovim on Ubuntu.
# Optional env vars:
#   NVIM_NERD_FONT - Nerd Font zip to download (default: FiraCode).
#   NVIM_CATPPUCCIN_FLAVOUR - Catppuccin flavour (default: macchiato). Options: latte, frappe, macchiato, mocha.

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

# Nerd Font zip to download (e.g. FiraCode, JetBrainsMono). Default: FiraCode.
NERD_FONT_SLUG="${NVIM_NERD_FONT:-FiraCode}"
NERD_FONT_VERSION="v3.4.0"

# Catppuccin theme flavour (latte, frappe, macchiato, mocha). Default: macchiato.
CATPPUCCIN_FLAVOUR="${NVIM_CATPPUCCIN_FLAVOUR:-macchiato}"

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
apt-get install -y git ripgrep curl unzip xclip build-essential fontconfig

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

# Optional Nerd Font download (set NVIM_NERD_FONT to choose another)
rm -f "/tmp/${NERD_FONT_SLUG}.zip"
curl -sL -o "/tmp/${NERD_FONT_SLUG}.zip" "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VERSION}/${NERD_FONT_SLUG}.zip"

# Install Nerd Font for target user
FONT_ZIP="/tmp/${NERD_FONT_SLUG}.zip"
FONT_DIR="$TARGET_HOME/.local/share/fonts"
FONT_TMP="/tmp/nerd_font_${NERD_FONT_SLUG}"
mkdir -p "$FONT_DIR"
rm -rf "$FONT_TMP"
unzip -o -q "$FONT_ZIP" -d "$FONT_TMP"
find "$FONT_TMP" -maxdepth 1 -type f \( -name '*.ttf' -o -name '*.otf' \) -exec mv -f {} "$FONT_DIR" \;
rm -rf "$FONT_TMP"
if command -v fc-cache >/dev/null 2>&1; then
  fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true
fi

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

# Catppuccin theme (https://github.com/catppuccin/nvim)
PLUGINS_DIR="$CONFIG_DIR/lua/plugins"
mkdir -p "$PLUGINS_DIR"
cat > "$PLUGINS_DIR/catppuccin.lua" << 'CATPPUCCIN_LUA'
return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = "CATPPUCCIN_FLAVOUR_PLACEHOLDER",
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin-CATPPUCCIN_FLAVOUR_PLACEHOLDER",
    },
  },
}
CATPPUCCIN_LUA
sed -i "s/CATPPUCCIN_FLAVOUR_PLACEHOLDER/$CATPPUCCIN_FLAVOUR/g" "$PLUGINS_DIR/catppuccin.lua"

# Configure Neovim GUI font (used by GUIs like Neovide)
OPTIONS_LUA="$CONFIG_DIR/lua/config/options.lua"
GUIFONT_NAME="${NERD_FONT_SLUG} Nerd Font"
if [[ -f "$OPTIONS_LUA" ]]; then
  if ! grep -q "guifont" "$OPTIONS_LUA" 2>/dev/null; then
    {
      echo ""
      echo "-- Nerd Font (installed by this script; set NVIM_NERD_FONT to change)"
      echo "vim.opt.guifont = \"${GUIFONT_NAME}:h14\""
    } >> "$OPTIONS_LUA"
  fi
fi

fix_ownership_if_needed

echo
echo "Installed Neovim:"
nvim --version | head -n 1
echo
echo "LazyVim config installed at: $CONFIG_DIR"
echo "Theme: Catppuccin ($CATPPUCCIN_FLAVOUR). Set NVIM_CATPPUCCIN_FLAVOUR to change (latte, frappe, macchiato, mocha)."
echo "Font: ${GUIFONT_NAME} installed in $FONT_DIR."
echo "For terminal Neovim, set your terminal font to '${GUIFONT_NAME}'."