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
    curl -sSL https://get.chezmoi.io | sh -s -- -b /usr/local/bin
    info "Chezmoi installed."
else
    info "Chezmoi already installed."
fi

# 2. Check for existing dotfiles repo
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -d "$REPO_DIR/.git" ]; then
    warn "Not a git repository. Initialize with: git init && git remote add origin <your-repo-url>"
fi

# 3. Initialize and apply
info "Initializing chezmoi from $REPO_DIR..."
chezmoi init --source "$REPO_DIR" --force

# 4. Apply dotfiles
info "Applying dotfiles..."
chezmoi apply --source "$REPO_DIR" --force --dry-run=false

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
info "To update dotfiles later:"
echo "  chezmoi update --source=$REPO_DIR"
echo "  chezmoi apply --source=$REPO_DIR"
echo ""
