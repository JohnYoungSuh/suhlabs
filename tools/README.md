# SuhLabs Platform Tools

Helper scripts for managing the multi-repo SuhLabs platform.

## Git Helper Scripts

### **git-status-all.sh**

Check the status of all 5 SuhLabs repositories at once.

**Usage:**

```bash
./git-status-all.sh
```

**What it shows:**

- Current branch for each repo
- Uncommitted changes
- Commits ahead/behind remote
- Clean/dirty status

---

### **git-pull-all.sh**

Pull latest changes from all 5 repositories.

**Usage:**

```bash
./git-pull-all.sh
```

**Features:**

- Auto-stashes uncommitted changes
- Pulls with rebase
- Restores stashed changes
- Shows update summary

---

### **git-commit-all.sh**

Commit and push changes across all repositories with the same message.

**Usage:**

```bash
./git-commit-all.sh "commit message here"
```

**Example:**

```bash
./git-commit-all.sh "docs: Update platform documentation"
```

---

## Setup

### Make Scripts Executable

Run this once after cloning:

```bash
cd ~/projects/suhlabs/aiops-substrate/tools
chmod +x git-status-all.sh
chmod +x git-pull-all.sh
chmod +x git-commit-all.sh
```

### Verify Setup

```bash
./git-status-all.sh
```

---

## VS Code Workspace

### Setup Multi-Repo Workspace

1. Move the workspace file to parent directory:

   ```bash
   mv ../docs/suhlabs-platform-workspace.json ../suhlabs-platform.code-workspace
   ```

2. Open in VS Code:

   ```bash
   code ~/projects/suhlabs/suhlabs-platform.code-workspace
   ```

3. All 5 repos will appear in the sidebar

---

## Repository List

The scripts manage these 5 repositories:

1. **aiops-substrate** - Infrastructure/platform layer
2. **ai-agent-governance-framework** - Policy/governance service
3. **suhlabs-infr-ai-poc** - Infrastructure AI POC
4. **ml-antipatterns** - ML validation
5. **suhlabs-web** - Marketing/product website

---

## Full Documentation

See [docs/GIT-WORKFLOW.md](../docs/GIT-WORKFLOW.md) for complete Git workflows, branching strategies, and best practices.

---

## Quick Reference

```bash
# Daily workflow
./git-pull-all.sh                       # Morning: Pull updates
./git-status-all.sh                     # Check what changed
./git-commit-all.sh "Daily progress"    # Evening: Commit work

# Individual repo commands (if needed)
cd ~/projects/suhlabs/aiops-substrate
git status
git add .
git commit -m "message"
git push
```

---

## Troubleshooting

### Scripts not executable

```bash
chmod +x *.sh
```

### Repo not found

Ensure all 5 repos are cloned to `~/projects/suhlabs/`:

```bash
ls ~/projects/suhlabs/
# Should show:
# aiops-substrate
# ai-agent-governance-framework
# suhlabs-infr-ai-poc
# ml-antipatterns
# suhlabs-web
```

### Permission denied

```bash
# Check file permissions
ls -la *.sh

# Should show:
# -rwxr-xr-x  (executable)
```

---

## Contributing

When adding new helper scripts:

1. Add to this directory
2. Make executable (`chmod +x script.sh`)
3. Update this README
4. Follow existing script format (colors, error handling)

---

**For full Git workflow documentation, see:** [docs/GIT-WORKFLOW.md](../docs/GIT-WORKFLOW.md)
