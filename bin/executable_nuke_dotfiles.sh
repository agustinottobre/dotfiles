#!/bin/bash
# Nuke sensitive dotfiles and keys from an untrusted machine.

set -e

# List of sensitive locations to wipe
SENSITIVE_PATHS=(
    "$HOME/.ssh"
    "$HOME/.config/chezmoi"
    "$HOME/.local/share/chezmoi"
    "$HOME/.dotfiles_backup"
)

echo "⚠️  WARNING: This will permanently delete your SSH keys and Chezmoi configuration on this machine."
read -p "Are you sure you want to proceed? (y/N) " confirm

if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
    for path in "${SENSITIVE_PATHS[@]}"; do
        if [ -e "$path" ]; then
            echo "Overwriting and removing: $path"
            # Use shred if available for secure deletion
            if command -v shred >/dev/null 2>&1; then
                find "$path" -type f -exec shred -u {} \;
            fi
            rm -rf "$path"
        fi
    done
    echo "Done. All sensitive data wiped."
else
    echo "Aborted."
fi
