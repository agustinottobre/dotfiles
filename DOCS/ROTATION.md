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

# 2. Re-encrypt everything (shows each file as it processes)
config rotate-key ~/new-key.txt

# 3. Review changes
config diff

# 4. Commit
config commit -m "rotate: age master key" && config git -- push

# 5. Distribute new key, secure old key
config lock                         # remove old key from disk
scp ~/new-key.txt machine:~/.config/chezmoi/key.txt   # per machine
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
