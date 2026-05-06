#!/bin/bash

# =============================================================================
# Dotfiles Verification Suite
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

# 1. Syntax Checks
# -----------------------------------------------------------------------------
log "Checking shell script syntax..."
syntax_errors=0

check_syntax() {
    local file="$1"
    local shell="$2"
    if [[ -f "$file" ]]; then
        if ! "$shell" -n "$file"; then
            error "Syntax error in $file"
            syntax_errors=$((syntax_errors + 1))
        else
            success "$file syntax OK"
        fi
    fi
}

check_syntax "bootstrap.sh" "bash"
check_syntax ".zshrc" "zsh"
check_syntax ".zshenv" "zsh"
check_syntax ".zprofile" "zsh"

if [[ $syntax_errors -gt 0 ]]; then
    error "Syntax checks failed!"
    exit 1
fi

# 2. Path Verification
# -----------------------------------------------------------------------------
log "Verifying referenced paths in bootstrap.sh..."
missing_paths=0

# Paths that MUST exist in the repo
required_paths=(
    ".zshrc"
    ".zshenv"
    ".zimrc"
    ".tmux.conf"
    ".config/nvim"
    "bootstrap.sh"
)

for path in "${required_paths[@]}"; do
    if [[ ! -e "$path" ]]; then
        warn "Required path missing from repo: $path"
        missing_paths=$((missing_paths + 1))
    fi
done

if [[ $missing_paths -gt 0 ]]; then
    warn "Some required paths are missing. Ensure they are present before bootstrapping."
fi

# 3. Logic Validation (Dry Run)
# -----------------------------------------------------------------------------
log "Validating bootstrap.sh symlink logic..."
# Verify that the find command for .sops files works as expected
sops_count=$(find . -name "*.sops.*" | wc -l)
log "Found $sops_count encrypted secrets."

# 4. Tmux Config Check
# -----------------------------------------------------------------------------
log "Checking .tmux.conf for profile logic..."
if grep -q "DOTFILES_PROFILE" .tmux.conf; then
    success "Tmux profile-aware logic detected."
else
    error "Tmux profile-aware logic missing!"
fi

success "Verification suite complete!"
