# Secrets Management with Chezmoi & Age

This repository uses `age` for native encryption of sensitive files (like SSH keys).

## 1. Adding a New Secret
To add a sensitive file to the repository:
```bash
# Example: Adding a private key
chezmoi encrypt ~/.ssh/id_rsa > private_dot_ssh/private_id_rsa.age
```

## 2. Editing an Existing Secret
Never edit the `.age` files directly. Use `chezmoi edit`:
```bash
# This decrypts to a temp file, opens your editor, and re-encrypts on save
chezmoi edit ~/.ssh/config
```

## 3. Working on Untrusted Servers
If you are working on a machine you don't fully trust, follow this protocol:

1.  **Bootstrap:** Run `./bootstrap.sh`.
2.  **Identify:** Your `age` master key is at `~/.config/chezmoi/key.txt`.
3.  **Work:** Use your tools as normal.
4.  **Nuke:** When finished, run the cleanup script to wipe all keys and decrypted data:
    ```bash
    nuke_dotfiles.sh
    ```

## 4. Key Rotation
If your master `age` key is compromised:
1.  Generate a new key: `age-keygen -o new_key.txt`.
2.  Update the `recipient` in `dot_config/chezmoi/chezmoi.toml.tmpl`.
3.  Re-encrypt all `.age` files in the repository using the new public key.
