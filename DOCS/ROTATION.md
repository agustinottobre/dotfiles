# SSH Key Rotation Guide

Complete reference for rotating SSH keys managed in this dotfiles repo.

---

## Overview

All secrets are encrypted with [age](https://github.com/FiloSottile/age) and managed by chezmoi.
The repo contains:

| File | Description |
|------|-------------|
| `private_dot_ssh/config.tmpl` | SSH config (all hosts) |
| `private_dot_ssh/github_id_rsa.age` | GitHub personal access key |
| `private_dot_ssh/bitbucket_id_rsa.age` | Bitbucket access key |
| `private_dot_ssh/tower_id_rsa.age` | Proxmox tower server key |
| `private_dot_ssh/hostinger_id_rsa.age` | Hostinger VPS key |
| `private_dot_ssh/solarbox_id_rsa.age` | Solarbox web server key |
| `private_dot_ssh/alwaysdata_id_ed25519.age` | alwaysdata.net SSH key |
| `private_dot_ssh/linksys_wrt3200acm_id.age` | Router SSH key |

The age **master key** lives at `~/.config/chezmoi/key.txt` — this is the only thing that can decrypt everything. Guard it accordingly.

---

## 1. Rotate the Age Master Key (the master key that encrypts everything)

Do this when the master key is compromised, or as periodic hygiene (yearly recommended).

### Step 1.1 — Generate a new age key pair

```bash
age-keygen -o ~/new-key.txt
# Example output:
# Age public key: age1EXAMPLEEXAMPLEEXAMPLEEXAMPLE...
```

### Step 1.2 — Update chezmoi.toml

In `dot_config/chezmoi/chezmoi.toml.tmpl`, update the `identity` path:

```toml
[age]
    identity = "{{ .chezmoi.homeDir }}/.config/chezmoi/new-key.txt"
```

Commit and push this change first (no secrets are leaked yet — it's just a path).

### Step 1.3 — Re-encrypt all .age files

```bash
# Decrypt all secrets to a temp directory
mkdir -p /tmp/secrets
chezmoi cd
for f in private_dot_ssh/*.age; do
  name=$(basename "$f" .age)
  # Decrypt with OLD key
  age -d -i ~/.config/chezmoi/key.txt "$f" > "/tmp/secrets/$name"
done

# Re-encrypt all with NEW key
for f in /tmp/secrets/*; do
  name=$(basename "$f")
  age -r "age1NEWKEYHERE..." -o "private_dot_ssh/$name.age" "$f"
done

# Cleanup temp files
rm -rf /tmp/secrets

# Apply and verify
chezmoi apply
```

### Step 1.4 — Distribute the new key to all machines

On every machine that uses these dotfiles:

```bash
# Copy the new key file
scp new-key.txt user@machine:~/.config/chezmoi/key.txt

# Or from the dotfiles repo (if already committed):
cp dotfiles/private_dot_ssh/new-master-key.age ~/.config/chezmoi/key.txt
# (but keep the key OUT of the repo if possible — see "Key Storage" section)
```

### Step 1.5 — Remove old key from all machines

```bash
rm ~/.config/chezmoi/key.txt.bak  # if you backed it up
```

---

## 2. Rotate a Compromised SSH Key

Do this immediately when an SSH key is exposed (pushed to GitHub, leaked, etc.).

### Step 2.1 — Generate a new SSH key

```bash
ssh-keygen -t ed25519 -f ~/.ssh/github_id_rsa -C "agustinottobre@gmail.com"
```

### Step 2.2 — Update the remote server with the new public key

**GitHub:**
1. Go to https://github.com/settings/keys
2. Delete the old SSH key
3. Add the new public key: `cat ~/.ssh/github_id_rsa.pub`

**Bitbucket:**
1. Go to https://bitbucket.org/account/settings/ssh-keys/
2. Delete old key, add new one

**Proxmox tower:** Delete old key from `/root/.ssh/authorized_keys`, add new one

**Hostinger:** Hostinger dashboard → SSH Keys → replace

### Step 2.3 — Re-encrypt the private key in dotfiles

```bash
# On your LOCAL machine (where the new private key lives):
chezmoi encrypt ~/.ssh/github_id_rsa > ~/dotfiles/private_dot_ssh/github_id_rsa.age

# Commit and push
cd ~/dotfiles
git add private_dot_ssh/github_id_rsa.age
git commit -m "rotate: github SSH key"
git push
```

### Step 2.4 — Deploy to all machines

```bash
# On each machine:
cd ~/dotfiles && git pull && chezmoi apply
```

---

## 3. Add a New SSH Key

### Step 3.1 — Add the private key to the repo

```bash
# Generate key if needed
ssh-keygen -t ed25519 -f ~/.ssh/new_service_id_rsa -C "description"

# Add host entry to SSH config (via chezmoi edit)
chezmoi edit ~/.ssh/config
# Add:
# Host newservice
#   HostName ssh.newservice.com
#   IdentityFile ~/.ssh/new_service_id_rsa

# Encrypt and add to repo
chezmoi encrypt ~/.ssh/new_service_id_rsa > private_dot_ssh/new_service_id_rsa.age
```

### Step 3.2 — Commit

```bash
git add private_dot_ssh/new_service_id_rsa.age
# (config.tmpl is auto-updated by chezmoi edit)
git commit -m "add: new_service SSH key and config"
git push
```

---

## 4. Verify Encrypted Files Are Working

After any changes, verify the apply works on a clean machine:

```bash
# Clone dotfiles to a test machine
git clone https://github.com/your/dotfiles.git ~/dotfiles

# Apply (will prompt for the age key if not present)
chezmoi apply --source=~/dotfiles

# Verify SSH config
cat ~/.ssh/config

# Verify a key is present
ls -la ~/.ssh/ | grep _id_rsa
```

---

## 5. Removing an Old Key from Git History

When you rotate a key, the old encrypted `.age` file is still in git history. To permanently remove it:

```bash
# WARNING: This rewrites git history. Coordinate with anyone using the repo.
cd ~/dotfiles

# Remove the old .age file from all commits
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch private_dot_ssh/old_key_id_rsa.age' \
  --prune-empty --tag-name-filter cat -- --all

# Push with force (coordinate with collaborators first!)
git push origin --force --all
git push origin --force --tags
```

After this, the old key is permanently gone from the repo history.

---

## 6. Emergency: Wipe All Secrets from a Machine

If a machine is compromised and you need to wipe fast:

```bash
# Run the nuke script (destroys all decrypted secrets)
~/dotfiles/bin/nuke_dotfiles.sh

# Or manually:
rm -rf ~/.ssh/*_id_rsa*    # removes all private keys
rm -f ~/.ssh/config         # removes SSH config
rm -f ~/.config/chezmoi/key.txt  # removes master key (cannot decrypt .age files anymore)
```

---

## Key Storage Recommendations

The master key at `~/.config/chezmoi/key.txt` is the critical secret.

**Option A — In the repo (encrypted by GitHub):**
```bash
# Store it in the repo as an encrypted file
age -r "github-recipient" -o key.txt.age ~/.config/chezmoi/key.txt
# Commit key.txt.age to dotfiles repo
# Retrieve: age -d -i key.txt.age > ~/.config/chezmoi/key.txt
```
Risk: If GitHub is breached, the encrypted key could be brute-forced (age is strong but not unbreakable).

**Option B — Password manager:**
Store `~/.config/chezmoi/key.txt` contents in your password manager (1Password, Bitwarden, etc.). Retrieve with:
```bash
# MacOS
pass show chezmoi/master-key > ~/.config/chezmoi/key.txt
```

**Option C — Paper backup:**
```bash
cat ~/.config/chezmoi/key.txt | qrcode -o key.png
# Print and store in safe
```
Retrieve by scanning the QR code.

**Recommended:** Option B (password manager) for convenience + security. Option C for offline backup.