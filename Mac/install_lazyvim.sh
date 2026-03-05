#!/usr/bin/env bash
set -euo pipefail

# Install LazyVim + Neovim on macOS (Apple Silicon or Intel)
#
# Optional env vars:
#   NVIM_NERD_FONT  - Nerd Font to install (default: FiraCode). Examples: JetBrainsMono, Hack.
#   NVIM_CATPPUCCIN_FLAVOUR - Catppuccin flavour (default: macchiato). Options: latte, frappe, macchiato, mocha.
# See: https://github.com/ryanoasis/nerd-fonts/releases and https://github.com/catppuccin/nvim

# Resolve target user/home
if [[ "${SUDO_USER:-}" != "" && "${SUDO_USER}" != "root" ]]; then
  TARGET_USER="$SUDO_USER"
  TARGET_HOME="$(eval echo "~$SUDO_USER")"
else
  TARGET_USER="$(id -un)"
  TARGET_HOME="${HOME:-$(eval echo "~$TARGET_USER")}"
fi

CONFIG_DIR="$TARGET_HOME/.config/nvim"
DATA_DIR="$TARGET_HOME/.local/share/nvim"
STATE_DIR="$TARGET_HOME/.local/state/nvim"
CACHE_DIR="$TARGET_HOME/.cache/nvim"
LOCAL_BIN="$TARGET_HOME/.local/bin"
NVIM_INSTALL_DIR="$TARGET_HOME/.local/nvim"

# Nerd Font: name of the zip on GitHub (e.g. FiraCode, JetBrainsMono). Default: FiraCode.
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
    local target_group
    target_group="$(id -gn "$TARGET_USER" 2>/dev/null || echo staff)"
    chown -R "$TARGET_USER:$target_group" "$TARGET_HOME/.config" "$TARGET_HOME/.local" "$TARGET_HOME/Library/Fonts" 2>/dev/null || true
  fi
}

echo "Installing for user: $TARGET_USER"
echo "Target home: $TARGET_HOME"

# --- Homebrew (required for deps and optional Neovim) ---
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Add brew to PATH for this session (typical paths post-install)
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

# Ensure brew is in PATH for rest of script
if command -v brew &>/dev/null; then
  : # already available
elif [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
else
  echo "Homebrew not found. Install from https://brew.sh and re-run." >&2
  exit 1
fi

# Dependencies (ripgrep for telescope, etc.; xclip not needed on macOS – pbcopy used)
brew install git ripgrep curl unzip

# --- Neovim: latest stable from official release ---
ARCH="$(uname -m)"
case "$ARCH" in
  arm64)
    NVIM_ARCH="macos-arm64"
    ;;
  x86_64)
    NVIM_ARCH="macos-x86_64"
    ;;
  *)
    echo "Unsupported architecture: $ARCH" >&2
    exit 1
    ;;
esac

cd /tmp
NVIM_TAR="nvim-${NVIM_ARCH}.tar.gz"
NVIM_EXTRACTED="nvim-${NVIM_ARCH}"
NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/${NVIM_TAR}"
rm -f "$NVIM_TAR"
curl -sL -o "$NVIM_TAR" "$NVIM_URL"
# Avoid "unknown developer" quarantine warning
xattr -c "$NVIM_TAR" 2>/dev/null || true
rm -rf "$NVIM_EXTRACTED"
tar -xzf "$NVIM_TAR"

mkdir -p "$(dirname "$NVIM_INSTALL_DIR")"
rm -rf "$NVIM_INSTALL_DIR"
mv "$NVIM_EXTRACTED" "$NVIM_INSTALL_DIR"
mkdir -p "$LOCAL_BIN"
ln -sf "$NVIM_INSTALL_DIR/bin/nvim" "$LOCAL_BIN/nvim"

# Ensure ~/.local/bin is in PATH for this session and suggest for shell profile
if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
  export PATH="$LOCAL_BIN:$PATH"
  echo
  echo "Add to your shell profile (.zshrc / .bash_profile):"
  echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
  echo
fi

# --- Nerd Font: install and configure (font name from NVIM_NERD_FONT) ---
FONT_ZIP="/tmp/${NERD_FONT_SLUG}.zip"
rm -f "$FONT_ZIP"
curl -sL -o "$FONT_ZIP" "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VERSION}/${NERD_FONT_SLUG}.zip"
FONT_DIR="$TARGET_HOME/Library/Fonts"
mkdir -p "$FONT_DIR"
FONT_TMP="/tmp/nerd_font_${NERD_FONT_SLUG}"
rm -rf "$FONT_TMP"
unzip -o -q "$FONT_ZIP" -d "$FONT_TMP"
# Move only font files (macOS unzip may not support glob in -d mode)
find "$FONT_TMP" -maxdepth 1 -type f \( -name '*.ttf' -o -name '*.otf' \) -exec mv -f {} "$FONT_DIR" \;
rm -rf "$FONT_TMP"
# Refresh font registration if fontconfig is available (e.g. via Homebrew)
if command -v fc-cache &>/dev/null; then
  fc-cache -f -v "$FONT_DIR" 2>/dev/null || true
fi

# --- Base dirs and backup ---
mkdir -p "$TARGET_HOME/.config" "$TARGET_HOME/.local/share" "$TARGET_HOME/.local/state" "$TARGET_HOME/.cache"

backup_if_exists "$CONFIG_DIR"
backup_if_exists "$DATA_DIR"
backup_if_exists "$STATE_DIR"
backup_if_exists "$CACHE_DIR"

# --- LazyVim starter ---
git clone https://github.com/LazyVim/starter "$CONFIG_DIR"
rm -rf "$CONFIG_DIR/.git"

# --- Catppuccin theme (https://github.com/catppuccin/nvim) ---
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
# Replace placeholder with actual flavour
sed -i '' "s/CATPPUCCIN_FLAVOUR_PLACEHOLDER/$CATPPUCCIN_FLAVOUR/g" "$PLUGINS_DIR/catppuccin.lua"
echo "Configured Catppuccin theme: $CATPPUCCIN_FLAVOUR"

# Configure Neovim to use the installed Nerd Font (GUI clients: Neovide, etc.)
# guifont name: most Nerd Fonts use "<Slug> Nerd Font" (e.g. "FiraCode Nerd Font")
OPTIONS_LUA="$CONFIG_DIR/lua/config/options.lua"
GUIFONT_NAME="${NERD_FONT_SLUG} Nerd Font"
if [[ -f "$OPTIONS_LUA" ]]; then
  if ! grep -q "guifont" "$OPTIONS_LUA" 2>/dev/null; then
    {
      echo ""
      echo "-- Nerd Font (installed by this script; set NVIM_NERD_FONT to change)"
      echo "vim.opt.guifont = \"${GUIFONT_NAME}:h14\""
    } >> "$OPTIONS_LUA"
    echo "Configured guifont in $OPTIONS_LUA"
  fi
fi

fix_ownership_if_needed

echo
echo "Installed Neovim:"
"$LOCAL_BIN/nvim" --version | head -n 1
echo
echo "LazyVim config: $CONFIG_DIR"
echo "Theme: Catppuccin ($CATPPUCCIN_FLAVOUR). Set NVIM_CATPPUCCIN_FLAVOUR to change (latte, frappe, macchiato, mocha)."
echo "Font: ${GUIFONT_NAME} installed in $FONT_DIR and set in Neovim (guifont)."
echo "      To use another font, set NVIM_NERD_FONT (e.g. JetBrainsMono) and re-run."
echo "      For terminal Neovim, set your terminal font to '${GUIFONT_NAME}'."
echo "Run: nvim   (ensure \$HOME/.local/bin is in your PATH)"
