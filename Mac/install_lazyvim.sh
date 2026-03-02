#!/usr/bin/env bash
set -euo pipefail

# Install LazyVim + Neovim on macOS (Apple Silicon or Intel)

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

backup_if_exists() {
  local path="$1"
  if [[ -e "$path" ]]; then
    local backup="${path}.bak.$(date +%Y%m%d-%H%M%S)"
    echo "Backing up $path -> $backup"
    mv "$path" "$backup"
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

# --- Nerd Font (Fira Code): install and configure ---
rm -f /tmp/FiraCode.zip
curl -sL -o /tmp/FiraCode.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/FiraCode.zip
FONT_DIR="$TARGET_HOME/Library/Fonts"
mkdir -p "$FONT_DIR"
FONT_TMP="/tmp/firacode_fonts"
rm -rf "$FONT_TMP"
unzip -o -q /tmp/FiraCode.zip -d "$FONT_TMP"
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

# Configure Neovim to use the installed Nerd Font (GUI clients: Neovide, etc.)
OPTIONS_LUA="$CONFIG_DIR/lua/config/options.lua"
if [[ -f "$OPTIONS_LUA" ]]; then
  if ! grep -q "guifont" "$OPTIONS_LUA" 2>/dev/null; then
    {
      echo ""
      echo "-- Fira Code Nerd Font (installed by this script)"
      echo "vim.opt.guifont = \"FiraCode Nerd Font:h14\""
    } >> "$OPTIONS_LUA"
    echo "Configured guifont in $OPTIONS_LUA"
  fi
fi

echo
echo "Installed Neovim:"
"$LOCAL_BIN/nvim" --version | head -n 1
echo
echo "LazyVim config: $CONFIG_DIR"
echo "Font: Fira Code Nerd Font installed in $FONT_DIR and set in Neovim (guifont)."
echo "      For terminal Neovim, set your terminal font to 'FiraCode Nerd Font'."
echo "Run: nvim   (ensure \$HOME/.local/bin is in your PATH)"
