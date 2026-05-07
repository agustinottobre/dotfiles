#!/bin/bash
# A simple bootstrap script to initialize the dotfiles using chezmoi.

set -e

# 1. Install chezmoi
if ! command -v chezmoi >/dev/null 2>&1; then
    echo "Installing chezmoi..."
    curl -sSLf https://get.chezmoi.io | sudo sh -s -- -b /usr/local/bin
else
    echo "chezmoi is already installed."
fi

# 2. Initialize chezmoi with this repository
# We use --source $(pwd) to ensure it uses the local repository files.
echo "Initializing and applying dotfiles with chezmoi from $(pwd)..."
/usr/local/bin/chezmoi init --apply --source $(pwd)

echo "Bootstrap complete!"
echo "Please restart your shell to see the changes."
