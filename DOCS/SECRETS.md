# Secrets Management — Cheatsheet

All sensitive files encrypted with [age](https://github.com/FiloSottile/age), managed by chezmoi.

## Cheatsheet

```bash
# ── Bootstrap (new machine) ──
git clone <repo-url> ~/dotfiles && cd ~/dotfiles && ./bootstrap.sh
# → installs chezmoi + age + packages
# → generates master key at ~/.config/chezmoi/key.txt
# → deploys dotfiles

# ⚠️ .age files are placeholders — replace them first: DOCS/KEYS.md

# ── Daily operations ──
config add --encrypt ~/.ssh/my_key        # encrypt & track a file
config edit ~/.ssh/config                  # edit a managed file
config diff                                # preview changes
config apply                               # deploy changes
config commit -m "msg" && config git -- push      # commit & push

# ── Master key backup ──
# Option A: Password manager
pass insert chezmoi/master-key < ~/.config/chezmoi/key.txt

# Option B: Copy to USB/offline storage
cp ~/.config/chezmoi/key.txt /secure/location/

# ── Troubleshooting ──
chezmoi doctor                              # diagnose chezmoi setup
ls ~/.ssh/                                  # check deployed keys
ssh -vT git@github.com                     # test SSH key works
chezmoi age-keygen --output ~/.config/chezmoi/key.txt   # regenerate master key (paste from backup)
```

## What's encrypted

| File | Purpose |
|------|---------|
| `~/.ssh/*.age` | SSH private keys (decrypted on apply) |
| `~/.config/chezmoi/key.txt` | Age master key (NOT in repo — back it up!) |

## Untrusted machines

```bash
./bootstrap.sh                    # deploy normally
# ... work ...
~/dotfiles/bin/executable_nuke_dotfiles.sh  # wipe everything when done
```

See `DOCS/KEYS.md` for SSH key workflow. See `DOCS/ROTATION.md` for key rotation.
