#!/bin/bash
# =============================================================================
# Bootstrap script - Initialize dotfiles with chezmoi
# Works on both macOS and Linux (Debian-based)
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == darwin* ]]; then
        echo "darwin"
    elif [[ -f /etc/debian_version ]]; then
        echo "linux-debian"
    elif [[ -f /etc/redhat-release ]]; then
        echo "linux-fedora"
    elif [[ -f /etc/arch-release ]]; then
        echo "linux-arch"
    else
        echo "linux"
    fi
}

OS="$(detect_os)"

echo ""
echo "============================================"
echo "  Dotfiles Bootstrap"
echo "  OS: $OS"
echo "============================================"
echo ""

# 1. Install chezmoi
info "Installing chezmoi..."
if ! command -v chezmoi >/dev/null 2>&1; then
    if [ -w /usr/local/bin ]; then
        curl -sSL https://get.chezmoi.io | sh -s -- -b /usr/local/bin
    else
        mkdir -p "$HOME/.local/bin"
        curl -sSL https://get.chezmoi.io | sh -s -- -b "$HOME/.local/bin"
        export PATH="$HOME/.local/bin:$PATH"
        warn "Chezmoi installed to ~/.local/bin. Added to PATH for this session."
    fi
    info "Chezmoi installed."
else
    info "Chezmoi already installed."
fi

# ── Age encryption key ─────────────────────────────────────────────────────
# Generate before chezmoi runs so the recipient is valid from the start.
KEY_FILE="$HOME/.config/chezmoi/key.txt"
if [ ! -f "$KEY_FILE" ]; then
    info "Generating age encryption key..."
    mkdir -p "$(dirname "$KEY_FILE")"
    chezmoi age-keygen --output "$KEY_FILE"
    info "Age key generated: $KEY_FILE"
fi
PUBKEY=$(chezmoi age-keygen -y "$KEY_FILE" 2>/dev/null)

# 2. Check for existing dotfiles repo
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -d "$REPO_DIR/.git" ]; then
    warn "Not a git repository. Initialize with: git init && git remote add origin <your-repo-url>"
fi

info "Dotfiles repo at: $REPO_DIR"

# 3. Initialize chezmoi (generates config with placeholder recipient)
info "Initializing chezmoi..."
chezmoi init --source "$REPO_DIR" --force

# Replace placeholder with the real age public key
# Done outside of chezmoi scripts to avoid config mutation during apply.
CHEZMOI_TOML="$HOME/.config/chezmoi/chezmoi.toml"
if [ -f "$CHEZMOI_TOML" ] && grep -q 'REPLACE_WITH_YOUR_AGE_PUBLIC_KEY' "$CHEZMOI_TOML" 2>/dev/null; then
    if [ "$(uname -s)" = "Darwin" ]; then
        sed -i "" "s/REPLACE_WITH_YOUR_AGE_PUBLIC_KEY/$PUBKEY/" "$CHEZMOI_TOML"
    else
        sed -i "s/REPLACE_WITH_YOUR_AGE_PUBLIC_KEY/$PUBKEY/" "$CHEZMOI_TOML"
    fi
    info "Age recipient configured in chezmoi.toml"
fi

# 4. Apply dotfiles
info "Applying dotfiles..."
chezmoi apply --force

if [ "$OS" != "darwin" ]; then
  if [ -x /usr/bin/zsh ] && [ "$SHELL" != "/usr/bin/zsh" ]; then
    info "Setting zsh as default shell..."
    chsh -s /usr/bin/zsh 2>/dev/null || warn "Could not change default shell. Run manually: chsh -s /usr/bin/zsh"
  fi
fi

echo ""
echo "============================================"
echo "  Bootstrap Complete!"
echo "============================================"
echo ""
info "Next steps:"
echo "  1. Restart your shell: exec zsh"
echo "  2. Or source: source ~/.zshrc"
echo "  3. For tmux: prefix + I to install plugins"
echo ""
echo -e "${YELLOW}[IMPORTANT]${NC} Back up your age key for other machines:"
echo "  cp $KEY_FILE /secure/location/dotfiles-age-key.txt"
echo "  # Or store in password manager:"
echo "  # pass insert chezmoi/age-key < $KEY_FILE"
echo "  # On other machines, place it at ~/.config/chezmoi/key.txt.backup"
echo "  # Then run: dotfiles-unlock"
echo ""
info "To update dotfiles later:"
echo "  export DOTFILES_REPO=$REPO_DIR"
echo "  chezmoi update --source=\$DOTFILES_REPO && chezmoi apply --source=\$DOTFILES_REPO"
echo ""
