# Dotfiles Management

Modern, profile-based dotfiles management for macOS workstations and headless Linux servers.

## 🚀 TL;DR / Quick Start

**New Machine Setup:**
```bash
git clone git@bitbucket.org:agustinottobre/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./bootstrap.sh
```

**Daily Workflow:**
*   `config` - Fuzzy find and edit any dotfile.
*   `secrets decrypt` - Bring in your sensitive keys (in-memory).
*   `secrets encrypt` - Save changes back to encrypted `.sops` files.
*   `secrets cleanup` - **Securely wipe** raw secrets before logging out.
*   `secrets add <file>` - Protect a new file with encryption.

---

## 🛠 Features

### 1. Profile-Based Bootstrap
The `bootstrap.sh` script detects your OS and lets you choose:
*   **`mac-full`**: Complete workstation setup (Brew, Rust, GUI configs).
*   **`server-headless`**: Minimal CLI setup (Zsh, Tmux, Neovim Nightly AppImage).
    *   *Visual indicator*: Remote servers get a **Red** Tmux status bar automatically.

### 2. Secure Secret Management (SOPS + age)
Sensitive files (like `.ssh/config`) are stored encrypted as `*.sops.*` files.
*   **No local keys required**: Decrypt secrets into memory for a session and wipe them when done.
*   **Public Key Persistence**: Your public key is saved to `~/.dotfiles_public_key` so encryption is automated.
*   **Automatic Symlinking**: Any file you protect with `secrets add` is automatically symlinked during bootstrap.

### 3. Verification & Safety
Run the built-in tests whenever you modify the structure:
```bash
./tests/verify_configs.sh
```
This checks syntax across all scripts and ensures core paths and profile logic are intact.

## 📁 Repository Structure

*   `.config/` - App-specific configs (nvim, starship, alacritty, etc.).
*   `.ssh/` - SSH configurations (encrypted via SOPS).
*   `bin/` - Custom utility scripts.
*   `bootstrap.sh` - The unified entry point for setup.
*   `tests/` - Verification suite for maintenance.

---

## 🔒 Secrets Setup (One-time)
If you are moving a file to the encrypted flow for the first time:
1.  Generate a key: `age-keygen -o ~/.config/sops/age/keys.txt`
2.  Add the secret: `secrets add .ssh/id_rsa`
3.  The file is now ignored by Git in its raw form and tracked as `.ssh/id_rsa.sops`.

---
*Old IntelliJ settings are available in `Intellij_settings.zip`.*
*Iterm theme is available in `themes/gruvbox_dark_hard_AOX.itermcolors`.*
