# Dotfiles

Cross-platform dotfiles managed with [chezmoi](https://www.chezmoi.io/). Works on **macOS** and **Debian-based Linux**.

## Tech Stack
- chezmoi (Go binary for dotfile management)
- Zsh + Zim (shell, fast plugin framework)
- Starship (cross-shell prompt)
- Tmux + TPM (multiplexer, vi mode)
- Neovim (kickstart.nvim + Tokyo Night, LSP, Telescope, CodeCompanion)
- FZF + fd (fuzzy finder)
- FNM (Fast Node Manager)
- age (encryption for secrets)

## Commands
- Apply dotfiles: `chezmoi apply` or `config apply`
- Edit a managed file: `config edit ~/.file`
- Track a new file: `config add ~/.new`
- Check status: `config status` / `config diff`
- Install packages (auto on change): `chezmoi apply`
- Test on Linux: `./tests/test_linux.sh`
- Test on macOS: `./tests/test_macos.sh`
- Reset run_onchange scripts: `chezmoi state delete-bucket --bucket=entryState`

## Code Conventions
- **Templates use chezmoi's Go template syntax**: `{{ if eq .chezmoi.os "darwin" }}...{{ end }}`
- **OS-specific blocks**: always wrapped in template conditionals, never separate files for minor differences
- **Packages declared in one place**: `.chezmoidata/packages.yaml` with `linux.apt` and `darwin.brew` lists
- **Secrets stored as `.age` files**: created with `chezmoi add --encrypt`, auto-decrypted on apply
- **Dotfile naming**: chezmoi prefix convention — `dot_bashrc.tmpl` → `~/.bashrc`, `private_dot_ssh/` → `~/.ssh/`
- **Non-dotfile files excluded via `.chezmoiignore`**: README, tests, docs, bootstrap
- **Shell config order**: `.zshenv` (env vars), `.zprofile` (login), `.zshrc` (interactive), `.zimrc` (zim modules)

## Boundaries
- Never commit plaintext secrets — always encrypt with `chezmoi add --encrypt`
- Never modify the `chezmoi.toml` placeholder (`REPLACE_WITH_YOUR_AGE_PUBLIC_KEY`) — bootstrap handles it
- Never commit `.chezmoi.toml.tmpl` changes that hardcode personal data
- Test scripts use isolated `$HOME` — never touch real dotfiles
- Package changes trigger `run_onchange_install-packages.sh.tmpl` automatically via SHA256 hash change
- `config` is a shell function defined in `.zshrc` — not available until shell is sourced

## Project Map

### Core Infrastructure
| File | Purpose |
|------|---------|
| `bootstrap.sh` | One-shot setup: installs chezmoi, age key, init, apply |
| `.chezmoi.toml.tmpl` | chezmoi config template, auto-fills age recipient |
| `.chezmoiignore` | Excludes non-dotfiles from chezmoi management |
| `.chezmoidata/packages.yaml` | Declarative OS-specific package lists |
| `run_onchange_install-packages.sh.tmpl` | Installs packages on change (hash-triggered) |

### Shell (Zsh + Zim)
| File | What it does |
|------|-------------|
| `dot_zshenv.tmpl` | Environment variables (PATH, EDITOR, FZF opts, OS detection) |
| `dot_zprofile.tmpl` | Login shell (homebrew, GPG, SSH agent, starship init) |
| `dot_zshrc.tmpl` | Interactive shell (aliases, completions, zim init, config() wrapper, OS-specific) |
| `dot_zimrc` | Zim module config (zmodule declarations) |

### Terminal & Tools
| File | What it does |
|------|-------------|
| `dot_tmux.conf` | Tmux with vi mode, TPM plugins, OS-specific clipboard |
| `dot_bashrc.tmpl` | Minimal bash fallback |
| `dot_config/starship.toml` | Starship prompt theme |
| `dot_config/nvim/` | Neovim kickstart.nvim config |
| `dot_config/alacritty/` | Alacritty terminal config |
| `dot_config/lvim/` | LunarVim fallback config |
| `dot_config/ranger/` | Ranger file manager config |

### Secrets & Security
| Path | What |
|------|------|
| `private_dot_ssh/config.tmpl` | SSH config with chezmoi templates |
| `private_dot_ssh/*.age` | Encrypted SSH keys |
| `dot_gitconfig.tmpl` | Git identity with template variables |
| `dot_gitignore` | Global gitignore |

### macOS-only
| File | What |
|------|------|
| `dot_config/skhd/skhdrc` | Simple Hotkey Daemon config |
| `macos-scripts/` | macOS automation scripts |

### Other
| Path | Purpose |
|------|---------|
| `bin/` | Personal scripts added to PATH |
| `tests/` | Isolated-home test scripts |
| `DOCS/` | Reference documentation |
| `themes/` | Terminal color themes |
| `.task/` | Taskwarrior config (excluded from chezmoi) |

## Patterns

### Adding a package
```yaml
# .chezmoidata/packages.yaml
packages:
  linux:
    apt:
    - htop          # add here
  darwin:
    brew:
    - htop          # and here
```
Then `chezmoi apply` — the script detects the hash change and re-runs.

### Adding a new dotfile
```zsh
config add ~/.newfile            # copies to source, prefixes as dot_newfile
config edit ~/.newfile           # edits the source version
# To make it OS-conditional, rename to .tmpl and add template logic:
# {{ if eq .chezmoi.os "darwin" }}...{{ end }}
```

### Adding a secret
```zsh
chezmoi add --encrypt ~/.secret/file
# Creates private_dot_secret/file.age in source
# Auto-decrypted on apply when age key is present
```

### OS-conditional template pattern
```
{{ if eq .chezmoi.os "darwin" }}
# macOS-specific
export PATH="/opt/homebrew/bin:$PATH"
{{ else }}
# Linux
export PATH="$HOME/.local/bin:$PATH"
{{ end }}
```

## Known Gotchas
- `config` function is defined in `.zshrc` — not available until `exec zsh` after bootstrap
- `.chezmoi.toml.tmpl` uses `REPLACE_WITH_YOUR_AGE_PUBLIC_KEY` placeholder — bootstrap.sh replaces it, don't remove
- `fzf` backend differs: `fd` on macOS, `fdfind` on Linux
- Tmux clipboard: `xsel` on Linux, `pbcopy/pbpaste` on macOS
- `run_onchange_*` scripts only re-run when the script content changes (SHA256), not on every apply
- Encrypted `.age` files are silently ignored when age key is absent (`.chezmoiignore` template logic)
- Neovim: default clipboard is `unnamedplus` — be aware yanks/deletes go to system clipboard
