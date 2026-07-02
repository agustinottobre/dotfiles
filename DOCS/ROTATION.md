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
config commit -m "rotate: github SSH key" && config git -- push

# 5. Deploy everywhere
config update && config apply
```

## Rotate age master key

```bash
# 1. Generate new key
chezmoi age-keygen --output ~/new-key.txt

# 2. Re-encrypt everything + update config (one command)
config rotate-key ~/new-key.txt

# 3. Commit
config commit -m "rotate: age master key" && config git -- push

# 4. Distribute new key to all machines
scp ~/new-key.txt user@machine:~/.config/chezmoi/key.txt
# Or delete ~/new-key.txt and distribute via password manager
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
~/dotfiles/bin/executable_nuke_dotfiles.sh
# Removes: ~/.ssh/*, ~/.ssh/config, ~/.config/chezmoi/key.txt
```
