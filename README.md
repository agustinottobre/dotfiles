# Dotfiles

Cross-platform dotfiles managed with [chezmoi](https://www.chezmoi.io/). Works on **macOS** and **Debian-based Linux**.

## Install

```bash
git clone git@github.com:agustinottobre/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./bootstrap.sh
exec zsh
```

Bootstrap installs chezmoi, system packages, neovim, starship, fnm, zim, TPM, and applies all dotfiles. Requires **Homebrew** on macOS.

---

## TLDR — Daily Operations

### Packages: add or remove

```bash
# Add a package — edit one file, works on both OS
vim .chezmoidata/packages.yaml

# Example: add 'htop' to both
#   linux:
#     apt:
#     - htop          # ← add here
#   darwin:
#     brew:
#     - htop          # ← and here

# Apply (script re-runs automatically because the hash changed)
chezmoi apply

# Remove: just delete the line and apply
```

Packages are defined in `.chezmoidata/packages.yaml` — a single YAML file with OS-specific lists. The install script auto-detects changes via SHA256 hash and only re-runs when you modify the list.

### Configs: add, edit, remove

```bash
config              # fuzzy-find and edit any managed dotfile
config add ~/.new   # track a new file
config status       # check what's different from source
config diff         # review pending changes
config apply        # apply source to home
```

The `config()` function is a chezmoi wrapper. Any `chezmoi` command works: `config managed`, `config forget ~/.old`, `config re-add ~/.changed`.

### Secrets: encrypt and decrypt

```bash
# Prerequisites (done by bootstrap, check once):
ls ~/.config/chezmoi/key.txt              # your age private key
grep recipient ~/.config/chezmoi/chezmoi.toml  # public key set

# Encrypt a new secret file
chezmoi add --encrypt ~/.secret/file

# Decrypt (automatic on apply)
chezmoi apply

# Edit an encrypted file
chezmoi edit ~/.secret/file

# ⚠️  Back up your key! ~/.config/chezmoi/key.txt
# Lose it = lose every encrypted file forever.
```

### SSH: keys and config

```bash
# Add a new SSH key (encrypted, never hits git in plaintext)
cp ~/.ssh/my_new_key ~/dotfiles/private_dot_ssh/
cd ~/dotfiles/private_dot_ssh/
chezmoi add --encrypt my_new_key         # creates my_new_key.age

# Add a new SSH host
config edit ~/.ssh/config

# Template variables available in SSH config:
#   {{ .chezmoi.homeDir }}  → /home/user or /Users/user
# OS-specific blocks:
#   {{ if eq .chezmoi.os "darwin" }}...macOS only...{{ end }}
```

SSH config (`private_dot_ssh/config.tmpl`) uses chezmoi templates for portability. Keys are stored as `.age` encrypted files in the repo — auto-decrypted on `chezmoi apply`.

---

## What's Included

| Component | Description |
|-----------|-------------|
| **Zsh + Zim** | Fast shell with syntax highlighting, autosuggestions, history search |
| **Starship** | Cross-shell prompt with git info |
| **Tmux** | Terminal multiplexer, vi mode, TPM plugins |
| **Neovim** | Kickstart.nvim + Tokyo Night, LSP, Telescope, CodeCompanion |
| **FZF** | Fuzzy finder with fd backend, keybindings (Ctrl+R, Ctrl+T) |
| **FNM** | Fast Node Manager |

## OS-Specific Behavior

Automatic via chezmoi templates. No manual symlinks or conditionals in shell.

| Feature | macOS | Linux |
|---------|-------|-------|
| FZF backend | `fd` | `fdfind` |
| nvim install | `/usr/local/bin/nvim` | `~/.local/bin/nvim` |
| Docker | `docker-machine` aliases | — |
| Kubernetes | k3d, kubeconfigRefresh | — |
| Dart/Flutter | pub-cache bin | — |
| SSH | UseKeychain, colima, lima | IdentitiesOnly |

## Testing

Both scripts use isolated `$HOME` — your real dotfiles are untouched.

```bash
# Linux
./tests/test_linux.sh               # fake home on current host

# macOS
./tests/test_macos.sh               # fake home, safe on your main Mac
./tests/test_macos.sh --keep        # keep test home for inspection
```

## Troubleshooting

```bash
# Check chezmoi health
chezmoi doctor

# Tmux plugins
prefix + I                          # inside tmux

# Neovim plugins
nvim --headless +'Lazy sync' +quit

# FZF keybindings
$(brew --prefix)/opt/fzf/install    # macOS
~/.fzf/install                      # Linux

# Reset run_onchange scripts (force re-install after template changes)
chezmoi state delete-bucket --bucket=entryState
```

## Clipboard (nvim + tmux)

Uses [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) defaults: `clipboard=unnamedplus` syncs all yank/delete/paste with the system clipboard.

| Action | What it does | OS |
|--------|-------------|-----|
| `y` / `yy` in nvim | Copies to system clipboard | both |
| `d` / `x` in nvim | Deletes — also goes to clipboard | both |
| `p` / `P` in nvim | Pastes from clipboard (last yank or delete) | both |
| `"0p` in nvim | Paste from yank register (ignores deletes) | both |
| `Cmd+C` / `Ctrl+Shift+C` | Copy from terminal to system clipboard | macOS / Linux |
| `Cmd+V` / `Ctrl+Shift+V` | Paste from system clipboard into terminal | macOS / Linux |
| `C-c` in tmux | Copy tmux selection to system clipboard | both |
| `C-v` in tmux | Paste from system clipboard | both |

**Tip**: If a delete overwrites your yank, use `"0p` to paste what you yanked (the `"0` register only holds explicit yanks, never deletes).
