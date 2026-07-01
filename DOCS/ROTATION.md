# Key Rotation — Cheatsheet

## Rotate SSH key

```bash
# 1. Generate new key
ssh-keygen -t ed25519 -f ~/.ssh/github_id_rsa -C "you@email.com"

# 2. Upload public key to remote (GitHub/Bitbucket/server)
#    GitHub: https://github.com/settings/keys
#    Server: ssh-copy-id -i ~/.ssh/github_id_rsa.pub user@host

# 3. Delete old key from remote

# 4. Re-encrypt
config add --encrypt ~/.ssh/github_id_rsa
config commit -m "rotate: github SSH key" && config push

# 5. Deploy everywhere
config update && config apply
```

## Rotate age master key

```bash
# 1. Generate new key
age-keygen -o ~/new-key.txt

# 2. Update .chezmoi.toml.tmpl → change identity path if needed

# 3. Re-encrypt all .age files
cd $(chezmoi source-path)
mkdir -p /tmp/secrets
for f in private_dot_ssh/*.age; do
  name=$(basename "$f" .age)
  age -d -i ~/.config/chezmoi/key.txt "$f" > "/tmp/secrets/$name"
done
for f in /tmp/secrets/*; do
  name=$(basename "$f")
  age -r "age1YOUR_NEW_PUBKEY..." -o "private_dot_ssh/$name.age" "$f"
done
rm -rf /tmp/secrets

# 4. Commit + push
config commit -m "rotate: age master key" && config push

# 5. Distribute new key to all machines
scp ~/new-key.txt user@machine:~/.config/chezmoi/key.txt
# Then on each: config update && config apply
```

## Purge old key from git history

```bash
cd ~/dotfiles
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch private_dot_ssh/old_key.age' \
  --prune-empty --tag-name-filter cat -- --all
git push origin --force --all
```

## Emergency nuke

```bash
~/dotfiles/bin/nuke_dotfiles.sh
# Removes: ~/.ssh/*, ~/.ssh/config, ~/.config/chezmoi/key.txt
```
