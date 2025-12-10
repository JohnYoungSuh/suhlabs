---
description: Configure GitHub SSH authentication for VS Code
---

# Configure GitHub SSH Authentication for VS Code

This workflow helps you configure VS Code to work seamlessly with your GitHub SSH key (with passphrase).

## Prerequisites
- You already have an SSH key with a passphrase configured
- You're working in WSL (Ubuntu)

## Steps

### 1. Trust GitHub's Host Key
Add GitHub's host key to your known hosts to avoid connection prompts:

```bash
ssh-keyscan github.com >> ~/.ssh/known_hosts
```

### 2. Configure SSH Agent for Automatic Authentication
Add the following to your shell configuration file (`~/.bashrc` or `~/.zshrc`) to ensure the agent starts automatically and loads your key:

```bash
# Add this to the bottom of ~/.bashrc
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519  # Replace with your key name if different (e.g., id_rsa)
```

### 3. Reload Shell Configuration
After adding the above configuration:

```bash
source ~/.bashrc
```

You'll be prompted to enter your passphrase one time. After this, VS Code will inherit the authenticated session.

### 4. Verify in VS Code
1. Open the **Output** panel in VS Code (`Ctrl` + `Shift` + `U`)
2. Select **Git** from the dropdown
3. Try a `git fetch` or `git push`
4. You should see it succeed without prompting for a passphrase

### 5. Test SSH Connection
Verify your SSH connection to GitHub:

```bash
ssh -T git@github.com
```

You should see a message like: `Hi [username]! You've successfully authenticated...`

## Alternative: VS Code GitHub Authentication (HTTPS)
If you prefer not to manage SSH keys, VS Code has built-in GitHub authentication that works over HTTPS:

1. Click the **Accounts** icon (person icon) in the bottom-left Activity Bar
2. Select **"Sign in with GitHub"**
3. Follow the browser prompt to authorize
4. VS Code will now handle authentication automatically for all git operations

Note: If using this method, you'll need to switch your remote to HTTPS:
```bash
git remote set-url origin https://github.com/[username]/[repo].git
```

## Troubleshooting

### SSH Agent Not Persisting
If the SSH agent doesn't persist across sessions, you may need to use `keychain` or add the configuration to your shell profile more permanently.

### Wrong Key Being Used
If you have multiple SSH keys, specify which one to use for GitHub in `~/.ssh/config`:

```
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
```
