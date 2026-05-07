#!/bin/bash

# =============================================================================
# Dotfiles Bootstrap Script
# =============================================================================

set -e

# Configuration
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"
PROFILE_FILE="$HOME/.dotfiles_profile"
PUBKEY_FILE="$HOME/.dotfiles_public_key"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# Detect OS
OS="$(uname -s)"
case "$OS" in
    Darwin) OS_TYPE="macos" ;;
    Linux) OS_TYPE="linux" ;;
    *) error "Unsupported OS: $OS" ;;
esac

# List of files to link based on profile
common_files=(
    ".zshrc"
    ".zshenv"
    ".zprofile"
    ".zimrc"
    ".tmux.conf"
    ".config/nvim"
    ".config/starship.toml"
)

# Add any files that have a .sops counterpart to the common files
# This ensures that if you 'secrets add' a file, it gets linked automatically
while read -r sops_file; do
    # Convert /path/to/repo/dir/file.sops -> dir/file
    relative_path="${sops_file#$DOTFILES_DIR/}"
    target_path="${relative_path%.sops}"
    # Add to common_files if not already there
    if [[ ! " ${common_files[@]} " =~ " ${target_path} " ]]; then
        common_files+=("$target_path")
    fi
done < <(find "$DOTFILES_DIR" -name "*.sops")

mac_only_files=(
    ".bashrc"
    ".gitconfig"
    ".myclirc"
    ".shell_profile"
    ".taskrc"
    ".config/alacritty"
    ".config/lvim"
    ".config/ranger"
    ".config/skhd"
    ".doom.d"
    ".emacs.d"
    ".task"
    ".vim"
    "bin"
    "macos-scripts"
)

# Profile selection
PROFILE=""
DECRYPT_SECRETS=false
CLEANUP=false
ENCRYPT_SECRETS=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile) PROFILE="$2"; shift 2 ;;
        --decrypt) DECRYPT_SECRETS=true; shift ;;
        --cleanup) CLEANUP=true; shift ;;
        --encrypt) ENCRYPT_SECRETS=true; shift ;;
        *) error "Unknown option: $1" ;;
    esac
done

# Encrypt mode (save changes back to .sops)
if [[ "$ENCRYPT_SECRETS" == true ]]; then
    log "Running encryption mode (updating .sops files)..."
    # To encrypt, we need the public key. 
    # Order: 1. .sops.yaml  2. ~/.dotfiles_public_key  3. Manual entry
    PUBLIC_KEY=""
    if [[ -f "$DOTFILES_DIR/.sops.yaml" ]]; then
        log "Using encryption rules from .sops.yaml"
    elif [[ -f "$PUBKEY_FILE" ]]; then
        PUBLIC_KEY=$(cat "$PUBKEY_FILE")
        log "Using public key from $PUBKEY_FILE"
    else
        read -p "Enter the age public key to encrypt with: " PUBLIC_KEY
        if [[ -z "$PUBLIC_KEY" ]]; then
            error "Public key is required for encryption."
        fi
        echo "$PUBLIC_KEY" > "$PUBKEY_FILE"
        log "Saved public key to $PUBKEY_FILE for future use."
    fi

    find "$DOTFILES_DIR" -name "*.sops" | while read -r encrypted_file; do
        local target_file="${encrypted_file%.sops}"
        log "Encrypting $target_file -> $encrypted_file"
        if [[ -n "$PUBLIC_KEY" ]]; then
            sops --encrypt --age "$PUBLIC_KEY" "$target_file" > "$encrypted_file"
        else
            sops --encrypt "$target_file" > "$encrypted_file"
        fi
    done
    success "Encryption complete. Changes saved to .sops files."
    exit 0
fi

# Cleanup mode
if [[ "$CLEANUP" == true ]]; then
    log "Running cleanup mode..."
    # Find all .sops files and remove their decrypted counterparts
    find "$DOTFILES_DIR" -name "*.sops" | while read -r encrypted_file; do
        local target_file="${encrypted_file%.sops}"
        if [[ -f "$target_file" ]]; then
            log "Removing decrypted file: $target_file"
            # Use shred if available for secure deletion, otherwise rm
            if command -v shred >/dev/null 2>&1; then
                shred -u "$target_file"
            else
                rm -f "$target_file"
            fi
        fi
    done
    success "Cleanup complete. Decrypted secrets removed."
    exit 0
fi

# If no profile is provided, check if we are just decrypting
if [[ -z "$PROFILE" ]]; then
    if [[ "$DECRYPT_SECRETS" == true ]]; then
        log "No profile selected. Running in standalone decryption mode..."
        decrypt_secrets
        
        # After standalone decryption, we should ensure common files are symlinked
        # in case they were just created.
        log "Ensuring symlinks for common files..."
        for file in "${common_files[@]}"; do
            symlink_file "$DOTFILES_DIR/$file" "$HOME/$file"
        done
        success "Decryption and symlinking complete!"
        exit 0
    else
        echo "Select a profile to install:"
        echo "1) mac-full (Complete workstation setup)"
        echo "2) server-headless (Minimal CLI tools for remote servers)"
        read -p "Selection [1-2]: " profile_choice
        case "$profile_choice" in
            1) PROFILE="mac-full" ;;
            2) PROFILE="server-headless" ;;
            *) error "Invalid selection" ;;
        esac
    fi
fi

log "Detected OS: $OS_TYPE"
log "Installing profile: $PROFILE"

# 1. Install Dependencies
# -----------------------------------------------------------------------------
install_deps_macos() {
    log "Installing macOS dependencies via Homebrew..."
    if ! command -v brew >/dev/null 2>&1; then
        warn "Homebrew not found. Please install it first: https://brew.sh/"
        return
    fi
    
    brew install fzf tmux neovim zsh git go tree-sitter-cli sops age
    
    if ! command -v rustup >/dev/null 2>&1; then
        log "Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    fi
}

install_deps_linux() {
    log "Installing Linux dependencies via apt..."
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        # Install base dependencies
        local pkgs=(zsh tmux git curl wget age build-essential xsel)
        for pkg in "${pkgs[@]}"; do
            sudo apt-get install -y "$pkg" || warn "Package $pkg not found or failed to install via apt."
        done

        # Install Node.js and npm (needed for some Neovim plugins like mcphub)
        if ! command -v node >/dev/null 2>&1; then
            log "Installing Node.js via NodeSource..."
            curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
            sudo apt-get install -y nodejs
        fi

        # Install global npm packages
        if command -v npm >/dev/null 2>&1; then
            log "Installing global npm packages (mcp-hub, tree-sitter-cli)..."
            # Using 0.20.8 for tree-sitter-cli to ensure compatibility with older GLIBC (e.g. Debian 12)
            sudo npm install -g mcp-hub@latest tree-sitter-cli@0.20.8 || warn "Failed to install some npm packages."
        fi
    else
        warn "apt-get not found. Skipping apt installation."
    fi

    # Ensure local bin exists and is in PATH for the rest of the script
    mkdir -p "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"

    # Install tpm (Tmux Plugin Manager)
    if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
        log "Installing tpm..."
        git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    fi

    # Install sops if missing
    if ! command -v sops >/dev/null 2>&1; then
        log "sops not found. Installing from GitHub..."
        local ARCH=$(uname -m)
        local SOPS_ARCH="linux.amd64"
        [[ "$ARCH" == "aarch64" ]] && SOPS_ARCH="linux.arm64"
        
        local SOPS_VERSION=$(curl -s https://api.github.com/repos/getsops/sops/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ -n "$SOPS_VERSION" ]]; then
            log "Downloading sops $SOPS_VERSION for $SOPS_ARCH..."
            curl -L -o "$HOME/.local/bin/sops" "https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.${SOPS_ARCH}"
            chmod +x "$HOME/.local/bin/sops"
        else
            warn "Could not determine latest sops version. Please install sops manually."
        fi
    fi

    # Install age if missing and not installed via apt
    if ! command -v age >/dev/null 2>&1; then
        log "age not found. Installing from GitHub..."
        local ARCH=$(uname -m)
        local AGE_ARCH="linux-amd64"
        [[ "$ARCH" == "aarch64" ]] && AGE_ARCH="linux-arm64"
        
        local AGE_VERSION=$(curl -s https://api.github.com/repos/FiloSottile/age/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ -n "$AGE_VERSION" ]]; then
            log "Downloading age $AGE_VERSION..."
            local TEMP_DIR=$(mktemp -d)
            curl -L -o "$TEMP_DIR/age.tar.gz" "https://github.com/FiloSottile/age/releases/download/${AGE_VERSION}/age-${AGE_VERSION}-${AGE_ARCH}.tar.gz"
            tar -xzf "$TEMP_DIR/age.tar.gz" -C "$TEMP_DIR"
            find "$TEMP_DIR" -type f -name "age" -exec mv {} "$HOME/.local/bin/age" \;
            find "$TEMP_DIR" -type f -name "age-keygen" -exec mv {} "$HOME/.local/bin/age-keygen" \;
            rm -rf "$TEMP_DIR"
            chmod +x "$HOME/.local/bin/age" "$HOME/.local/bin/age-keygen"
        fi
    fi

    # Install fzf if missing or needs integration
    if [[ ! -d "$HOME/.fzf" || ! -f "$HOME/.fzf.zsh" || ! -f "$HOME/.local/bin/fzf" ]]; then
        log "Installing/Configuring fzf (latest binary + Zsh integration)..."
        [[ -d "$HOME/.fzf" ]] && rm -rf "$HOME/.fzf"
        git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
        
        # Manually download the latest binary to ensure it supports toggle-raw (0.48.0+)
        local ARCH=$(uname -m)
        local FZF_ARCH="linux_amd64"
        [[ "$ARCH" == "aarch64" ]] && FZF_ARCH="linux_arm64"
        
        local FZF_VERSION=$(curl -s https://api.github.com/repos/junegunn/fzf/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ -n "$FZF_VERSION" ]]; then
            # Strip leading 'v' for the filename (e.g., v0.72.0 -> 0.72.0)
            local FZF_VER_STRIPPED="${FZF_VERSION#v}"
            log "Downloading fzf $FZF_VERSION..."
            if curl -SfL -o "$HOME/.local/bin/fzf.tar.gz" "https://github.com/junegunn/fzf/releases/download/${FZF_VERSION}/fzf-${FZF_VER_STRIPPED}-${FZF_ARCH}.tar.gz"; then
                tar -xzf "$HOME/.local/bin/fzf.tar.gz" -C "$HOME/.local/bin"
                rm "$HOME/.local/bin/fzf.tar.gz"
                chmod +x "$HOME/.local/bin/fzf"
                success "fzf $FZF_VERSION installed to $HOME/.local/bin"
            else
                warn "Failed to download fzf binary. Falling back to system version or git installer."
            fi
        fi

        # Run installer for scripts only (bin is already handled)
        "$HOME/.fzf/install" --bin --key-bindings --completion --no-update-rc --no-bash --no-fish
        
        # Explicitly create/overwrite ~/.fzf.zsh with prioritized PATH
        cat > "$HOME/.fzf.zsh" <<EOF
# Setup fzf
# ---------
# Prepend local bin to ensure we use the version that supports toggle-raw
if [[ ! "\$PATH" == *\$HOME/.local/bin* ]]; then
  export PATH="\$HOME/.local/bin:\$PATH"
fi

if [[ ! "\$PATH" == *\$HOME/.fzf/bin* ]]; then
  export PATH="\$PATH:\$HOME/.fzf/bin"
fi

# Auto-completion
# ---------------
[[ \$- == *i* ]] && source "\$HOME/.fzf/shell/completion.zsh" 2> /dev/null

# Key bindings
# ------------
source "\$HOME/.fzf/shell/key-bindings.zsh"
EOF
    fi

    # Install Neovim Nightly
    if ! command -v nvim >/dev/null 2>&1; then
        log "Installing Neovim Nightly..."
        local ARCH=$(uname -m)
        if [[ "$ARCH" == "x86_64" ]]; then
            local NVIM_BIN="$HOME/.local/bin/nvim"
            curl -L -o "$NVIM_BIN" https://github.com/neovim/neovim/releases/download/nightly/nvim-linux-x86_64.appimage
            chmod u+x "$NVIM_BIN"
            
            # Check if FUSE is available
            if ! command -v fusermount >/dev/null 2>&1 && ! command -v fusermount3 >/dev/null 2>&1; then
                warn "FUSE not detected. Neovim AppImage may not run directly."
                log "Attempting AppImage extraction as fallback..."
                local OLD_PWD=$(pwd)
                cd "$HOME/.local/bin"
                ./nvim --appimage-extract >/dev/null
                mv squashfs-root nvim-extracted
                # Create a wrapper script to run the extracted binary
                cat > nvim <<EOF
#!/bin/bash
\$HOME/.local/bin/nvim-extracted/AppRun "\$@"
EOF
                chmod +x nvim
                cd "$OLD_PWD"
                success "Neovim installed via extraction (no FUSE required)."
            fi
        else
            warn "Neovim AppImage only supported on x86_64. Skipping."
        fi
    fi
}

if [[ "$PROFILE" == "mac-full" ]]; then
    install_deps_macos
elif [[ "$PROFILE" == "server-headless" ]]; then
    install_deps_linux
fi

# 2. Generate Profile File
# -----------------------------------------------------------------------------
log "Generating $PROFILE_FILE..."
cat > "$PROFILE_FILE" <<EOF
# Automatically generated by dotfiles bootstrap
export DOTFILES_PROFILE="$PROFILE"
EOF

# 3. Decrypt Secrets (SOPS)
# -----------------------------------------------------------------------------
decrypt_secrets() {
    local key_file="$HOME/.config/sops/age/keys.txt"
    
    if [[ -n "$SOPS_AGE_KEY" ]]; then
        log "Using SOPS_AGE_KEY from environment."
    elif [[ -f "$key_file" ]]; then
        log "Using SOPS key from $key_file."
        export SOPS_AGE_KEY_FILE="$key_file"
        
        # If we have a local key file, let's extract/update the public key 
        # so --encrypt works later without prompting.
        if command -v age-keygen >/dev/null 2>&1; then
            mkdir -p "$(dirname "$PUBKEY_FILE")"
            age-keygen -y "$key_file" > "$PUBKEY_FILE" 2>/dev/null
        fi
    else
        warn "No SOPS key found in environment or at $key_file."
        read -p "Enter your age private key (or press Enter to skip): " manual_key
        if [[ -n "$manual_key" ]]; then
            export SOPS_AGE_KEY="$manual_key"
        else
            warn "Skipping secret decryption."
            return
        fi
    fi

    log "Decrypting secrets..."
    # Find all .sops files and decrypt them
    find "$DOTFILES_DIR" -name "*.sops" | while read -r encrypted_file; do
        local target_file="${encrypted_file%.sops}"
        log "Decrypting $encrypted_file -> $target_file"
        sops --decrypt "$encrypted_file" > "$target_file"
    done
}

if [[ "$DECRYPT_SECRETS" == true ]]; then
    decrypt_secrets
else
    log "Skipping secret decryption (use --decrypt to enable)."
fi

# 4. Symlink Files
# -----------------------------------------------------------------------------
symlink_file() {
    local src="$1"
    local dest="$2"

    if [[ -e "$dest" || -L "$dest" ]]; then
        if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
            success "Already linked: $dest"
            return
        fi
        
        log "Backing up existing $dest to $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
        mv "$dest" "$BACKUP_DIR/"
    fi

    log "Linking $src -> $dest"
    mkdir -p "$(dirname "$dest")"
    ln -s "$src" "$dest"
}

log "Linking common files..."
for file in "${common_files[@]}"; do
    symlink_file "$DOTFILES_DIR/$file" "$HOME/$file"
done

if [[ "$PROFILE" == "mac-full" ]]; then
    log "Linking macOS specific files..."
    for file in "${mac_only_files[@]}"; do
        symlink_file "$DOTFILES_DIR/$file" "$HOME/$file"
    done
fi

# 4. Finalize
# -----------------------------------------------------------------------------
log "Setting up Zsh as default shell..."
ZSH_PATH=$(which zsh)
if [[ "$SHELL" != "$ZSH_PATH" ]]; then
    if [[ "$OS_TYPE" == "linux" ]]; then
        # Try usermod first (works better on some systems non-interactively if sudo is available)
        sudo usermod -s "$ZSH_PATH" "$(whoami)" || chsh -s "$ZSH_PATH" || warn "Failed to change shell. Please run: chsh -s $ZSH_PATH"
    else
        chsh -s "$ZSH_PATH" || warn "Failed to change shell. Please run: chsh -s $ZSH_PATH"
    fi
fi

success "Bootstrap complete! Please restart your shell."
warn "Note: If this is a server, you might need to install 'fuse' for Neovim AppImage to work, or run it with --appimage-extract."
