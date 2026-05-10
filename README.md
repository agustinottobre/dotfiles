# Dotfiles

Cross-platform dotfiles managed with [chezmoi](https://www.chezmoi.io/). Works on **macOS** and **Linux (Debian-based)**.

## Quick Start

```bash
git clone <your-repo> ~/dotfiles
cd ~/dotfiles && ./bootstrap.sh
source ~/.zshrc
```

## What's Included

| Component | Description |
|-----------|-------------|
| **Zsh + Zim** | Fast shell with zimfw framework, syntax highlighting, autosuggestions, history search |
| **Starship** | Cross-shell prompt with git, node, kubernetes info |
| **Tmux** | Terminal multiplexer with vi mode, smart pane switching, TPM plugins |
| **Neovim** | Configured with Kickstart.nvim + Tokyo Night theme, LSP, Telescope |
| **FZF** | Fuzzy finder for files, git, history |
| **FNM** | Fast Node Manager (replaces NVM) |

## Repository Structure

```
dotfiles/
├── bootstrap.sh                  # Main setup entry point
├── packages/
│   ├── apt.txt                # Debian packages
│   └── brew.txt               # macOS packages
├── dot_zshrc.tmpl             # Zsh config (Zim + FZF + aliases)
├── dot_zshenv.tmpl            # Environment variables
├── dot_zprofile.tmpl          # Login shell setup
├── dot_zimrc.tmpl             # Zim framework modules
├── dot_tmux.conf.tmpl        # Tmux configuration
├── dot_config/
│   ├── nvim/                  # Neovim (Kickstart + Tokyo Night)
│   └── starship.toml          # Starship prompt
└── bin/                       # Utility scripts
```

## Daily Workflow

```bash
# Edit any dotfile
config                          # Fuzzy find dotfiles in repo
config status                   # Check changes
config add <file>               # Add new file to chezmoi
config diff                     # Review changes
config update                   # Pull latest from repo

# Within chezmoi source directory
chezmoi apply                  # Apply dotfiles to home
chezmoi update                 # Update from repo
```

## OS-Specific Behavior

The dotfiles automatically adapt to your OS:

- **macOS**: Includes Docker aliases, k3d, Dart, Android SDK paths, Homebrew env
- **Linux**: Uses apt packages, Linux-specific Go paths, xsel clipboard

## Dependencies

### Installed Automatically
- `zsh`, `tmux`, `git`, `fzf`, `ripgrep` (via apt/brew)
- `starship`, `fnm`, `neovim` (via install script)

### Pre-installed Required
- `curl` or `wget`
- `chezmoi`

## Troubleshooting

### Shell not loading
```bash
exec zsh           # Restart zsh
source ~/.zshenv  # Source manually
```

### Neovim plugins not loading
```bash
nvim --headless +Lazy\ sync +quit  # Force sync plugins
```

### Tmux plugins missing
```bash
prefix + I        # Inside tmux, install plugins
```

### FZF not working
```bash
$(brew --prefix)/opt/fzf/install  # macOS
~/.fzf/install                    # Linux
```
