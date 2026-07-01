# SSH Keys — Cheatsheet

## TL;DR

Encrypted keys CAN be committed. The `.age` files in this repo are **placeholders** — replace them with real encrypted keys on first setup.

## Cheatsheet

```bash
# ── First-time: replace placeholders ──
config add --encrypt ~/.ssh/github_id_rsa
config add --encrypt ~/.ssh/bitbucket_id_rsa
config add --encrypt ~/.ssh/tower_id_rsa
config add --encrypt ~/.ssh/hostinger_id_rsa
config add --encrypt ~/.ssh/solarbox_id_rsa
config add --encrypt ~/.ssh/alwaysdata_id_ed25519
config add --encrypt ~/.ssh/linksys_wrt3200acm_id
config add --encrypt ~/.ssh/id_rsa
config diff && config apply && config commit -m "encrypt: SSH keys" && config push

# ── Daily ──
config add --encrypt ~/.ssh/new_key       # encrypt a new key
config edit ~/.ssh/config                  # edit SSH config
config diff                                # review changes
config commit -m "update: ssh keys"        # commit
config push                                # push

# ── On other machines ──
config update && config apply              # keys auto-decrypt to ~/.ssh/

# ── Nuke ──
~/dotfiles/bin/nuke_dotfiles.sh            # wipe all secrets from this machine
```

## Which tool

Use `config` (chezmoi wrapper), not raw `git`. Run commands from anywhere — chezmoi knows the source dir.

| Task | Command |
|------|---------|
| Encrypt a key | `config add --encrypt ~/.ssh/keyname` |
| Edit a dotfile | `config` (fzf) or `config edit ~/.zshrc` |
| See changes | `config diff` |
| Commit | `config commit -m "msg"` |
| Push | `config push` |

## Key inventory

| Source file | Deploys to |
|-------------|------------|
| `private_dot_ssh/id_rsa.age` | `~/.ssh/id_rsa` |
| `private_dot_ssh/github_id_rsa.age` | `~/.ssh/github_id_rsa` |
| `private_dot_ssh/bitbucket_id_rsa.age` | `~/.ssh/bitbucket_id_rsa` |
| `private_dot_ssh/tower_id_rsa.age` | `~/.ssh/tower_id_rsa` |
| `private_dot_ssh/hostinger_id_rsa.age` | `~/.ssh/hostinger_id_rsa` |
| `private_dot_ssh/solarbox_id_rsa.age` | `~/.ssh/solarbox_id_rsa` |
| `private_dot_ssh/alwaysdata_id_ed25519.age` | `~/.ssh/alwaysdata_id_ed25519` |
| `private_dot_ssh/linksys_wrt3200acm_id.age` | `~/.ssh/linksys_wrt3200acm_id` |
| `private_dot_ssh/config.tmpl` | `~/.ssh/config` |

See `DOCS/ROTATION.md` for key rotation. See `DOCS/SECRETS.md` for general secrets management.
