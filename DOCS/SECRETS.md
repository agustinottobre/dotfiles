# Secrets Management with Chezmoi & Age

All sensitive files in this repo are encrypted with [age](https://github.com/FiloSottile/age) and managed by chezmoi.

---

## Quick Start

### First-time setup (new machine)

```bash
# Install chezmoi
curl -sSL https://get.chezmoi.io | sh

# Clone your dotfiles
git clone https://github.com/your/dotfiles.git ~/dotfiles

# Initialize chezmoi from the repo
chezmoi init --source ~/dotfiles

# Apply — decrypts everything to home directory
chezmoi apply

# age is installed automatically (via apt/brew packages)
# The first run generates your master key at ~/.config/chezmoi/key.txt
```

### Daily workflow

```bash
# Use any encrypted file (decrypts automatically)
cat ~/.ssh/config

# Edit an encrypted file (opens editor, re-encrypts on save)
chezmoi edit ~/.ssh/config

# Add a new secret
# 1. Put the unencrypted file on your local machine
# 2. Encrypt it:
chezmoi add --encrypt ~/.ssh/my_key
# 3. Commit
git add private_dot_ssh/my_key.age
git commit -m "add: my_key SSH key"
```

---

## Encrypted Files in This Repo

| File | What it is |
|------|-----------|
| `private_dot_ssh/config.tmpl` | SSH config for all hosts |
| `private_dot_ssh/github_id_rsa.age` | GitHub SSH private key |
| `private_dot_ssh/bitbucket_id_rsa.age` | Bitbucket SSH private key |
| `private_dot_ssh/tower_id_rsa.age` | Proxmox tower server SSH key |
| `private_dot_ssh/hostinger_id_rsa.age` | Hostinger VPS SSH key |
| `private_dot_ssh/solarbox_id_rsa.age` | Solarbox web server SSH key |
| `private_dot_ssh/alwaysdata_id_ed25519.age` | alwaysdata.net SSH key |
| `private_dot_ssh/linksys_wrt3200acm_id.age` | Router SSH key |

---

## Master Key Location

The age master key lives at: **`~/.config/chezmoi/key.txt`**

This is the only thing that can decrypt all `.age` files. If you lose it, your secrets are gone. If someone else gets it, they can decrypt everything.

**Back it up immediately after first generation:**
```bash
# Option A: Password manager
pass insert chezmoi/master-key < ~/.config/chezmoi/key.txt

# Option B: Encrypted USB
sudo cryptsetup open /dev/sdX1 backup
sudo mount /dev/mapper/backup /mnt
cp ~/.config/chezmoi/key.txt /mnt/chezmoi-key-$(date +%Y%m%d).txt
sudo umount /mnt
sudo cryptsetup close backup
```

---

## Key Rotation

For step-by-step rotation instructions (master key, SSH keys, adding new keys, removing from git history), see:

**`DOCS/ROTATION.md`** — complete rotation and disaster recovery guide

Quick summary:

```bash
# Rotate an SSH key (example: github)
# 1. Generate new key
ssh-keygen -t ed25519 -f ~/.ssh/github_id_rsa -C "agustinottobre@gmail.com"
# 2. Update remote (GitHub settings → SSH keys)
# 3. Re-encrypt to dotfiles
chezmoi add --encrypt ~/.ssh/github_id_rsa
# 4. Commit and push
git add private_dot_ssh/github_id_rsa.age && git commit -m "rotate: github key" && git push
```

---

## Working on Untrusted Machines

If you're on a machine you don't fully trust:

```bash
# 1. Bootstrap normally
./bootstrap.sh

# 2. Work as usual — secrets are decrypted to ~/.ssh/

# 3. When done, wipe everything
~/dotfiles/bin/nuke_dotfiles.sh
# This removes:
#   - All private keys in ~/.ssh/
#   - ~/.ssh/config
#   - ~/.config/chezmoi/key.txt
#   - Any other decrypted secrets
```

---

## Troubleshooting

**"Permission denied (publickey)" after applying dotfiles:**
```bash
# Verify your keys are in ~/.ssh/
ls -la ~/.ssh/

# Verify the key is the right one for the host
ssh -vT git@github.com
# Look for "Offering public key" in the output
```

**"No such file or directory: key.txt" on first run:**
```bash
# Manually generate the age key
age-keygen -o ~/.config/chezmoi/key.txt

# Or install age first (it should be installed by the package scripts)
# Linux: sudo apt-get install age
# macOS: brew install age
```

**Can't decrypt a file (wrong key):**
```bash
# Check which key chezmoi is using
chezmoi doctor

# If you have the right key in a different location:
age-keygen -o ~/.config/chezmoi/key.txt  # paste the actual key content
```