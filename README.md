# Dotfiles

Cross-platform dotfiles managed with [chezmoi](https://www.chezmoi.io/). Works on **macOS** and **Debian-based Linux**.

## Install

Same command on both OSes — bootstrap detects your system and installs everything automatically:

```bash
git clone git@github.com:agustinottobre/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./bootstrap.sh
exec zsh
```

What bootstrap does:
- Installs chezmoi (if missing)
- Installs system packages (apt on Debian, brew on macOS)
- Installs neovim, starship, fnm, zim, TPM
- Applies all dotfiles to your home

### First run on macOS

Homebrew is required. If not installed:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### First run on Debian

Nothing extra needed. Bootstrap uses `apt` directly.

## What's Included

| Component | Description |
|-----------|-------------|
| **Zsh + Zim** | Fast shell with zimfw, syntax highlighting, autosuggestions, history search |
| **Starship** | Cross-shell prompt with git, node, kubernetes info |
| **Tmux** | Terminal multiplexer with vi mode, smart pane switching, TPM plugins |
| **Neovim** | Kickstart.nvim + Tokyo Night theme, LSP, Telescope |
| **FZF** | Fuzzy finder with fd backend, keybindings |
| **FNM** | Fast Node Manager (replaces NVM) |

## OS-Specific Behavior

Dotfiles adapt automatically via chezmoi templates:

- **macOS**: Docker aliases, k3d, Dart/Flutter paths, Homebrew env, skhd, colima SSH, UseKeychain
- **Linux**: fdfind (not fd) for FZF, xsel clipboard, Linux Go paths

## Daily Workflow

```bash
config              # Fuzzy-find and edit any dotfile
config status       # Check what changed
config diff         # Review changes
config add ~/.new   # Track a new file

chezmoi apply       # Apply latest dotfiles
chezmoi update      # Pull from git + apply
```

## Testing

Run without touching your real dotfiles — both scripts use isolated `$HOME`.

```bash
# Linux
./tests/test_linux.sh --local       # Fast: fake home on current host
./tests/test_linux.sh 13            # Full: clean Debian 13 Incus container

# macOS (safe to run on your main Mac)
./tests/test_macos.sh               # Fake home, your dotfiles untouched
./tests/test_macos.sh --keep        # Keep test home for inspection
```

## Troubleshooting

### Tmux plugins missing
```bash
# Inside tmux
prefix + I
```

### Neovim plugins not loading
```bash
nvim --headless +'Lazy sync' +quit
```

### FZF not working
```bash
$(brew --prefix)/opt/fzf/install   # macOS
~/.fzf/install                     # Linux
```
