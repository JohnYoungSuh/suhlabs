# Git Workflow for SuhLabs Platform

## Overview

The SuhLabs platform consists of **5 independent Git repositories** that work together to form the complete product.

```
SuhLabs Appliance Platform:
├── aiops-substrate                    # Infrastructure/platform layer
├── ai-agent-governance-framework      # Policy/governance service
├── suhlabs-infr-ai-poc               # Infrastructure AI POC
├── ml-antipatterns                    # ML validation
└── suhlabs-web                        # Marketing/product website
```

**Each repository is independent** with its own:

- Git history
- Branches
- Remote on GitHub
- Versioning
- Release cycle

---

## Repository Organization

### **Recommended Folder Structure**

```bash
~/projects/suhlabs/                    # Main organization folder
├── aiops-substrate/                   # Repo 1
│   ├── .git/
│   └── tools/
│       ├── git-status-all.sh         # Check all repos
│       ├── git-pull-all.sh           # Pull all repos
│       └── git-commit-all.sh         # Commit all repos
├── ai-agent-governance-framework/     # Repo 2
│   └── .git/
├── suhlabs-infr-ai-poc/              # Repo 3
│   └── .git/
├── ml-antipatterns/                   # Repo 4
│   └── .git/
└── suhlabs-web/                       # Repo 5
    └── .git/
```

---

## VS Code Workspace Setup

### **Open All 5 Repos at Once**

1. Rename the workspace file:

   ```bash
   cd ~/projects/suhlabs/aiops-substrate/docs
   mv suhlabs-platform-workspace.json ../suhlabs-platform.code-workspace
   ```

2. Open the workspace:

   ```bash
   code ~/projects/suhlabs/suhlabs-platform.code-workspace
   ```

3. VS Code will show all 5 repos in the sidebar with icons:
   - 🌐 Web (Marketing Site)
   - 🏗️ Infrastructure (Platform)
   - 🛡️ Governance (Policy Service)
   - 🤖 AI POC (Infrastructure AI)
   - 📊 ML Antipatterns (Validation)

---

## Daily Workflows

### **Morning: Pull Latest Changes**

```bash
# Option 1: Pull all repos at once (recommended)
cd ~/projects/suhlabs/aiops-substrate
./tools/git-pull-all.sh

# Option 2: Pull manually per repo
cd ~/projects/suhlabs/aiops-substrate && git pull
cd ~/projects/suhlabs/ai-agent-governance-framework && git pull
cd ~/projects/suhlabs/suhlabs-infr-ai-poc && git pull
cd ~/projects/suhlabs/ml-antipatterns && git pull
cd ~/projects/suhlabs/suhlabs-web && git pull
```

---

### **During Work: Check Status**

```bash
# Option 1: Check all repos at once
cd ~/projects/suhlabs/aiops-substrate
./tools/git-status-all.sh

# Option 2: Check specific repo
cd ~/projects/suhlabs/aiops-substrate
git status
```

---

### **End of Day: Commit and Push**

```bash
# Option 1: Commit all repos with same message
cd ~/projects/suhlabs/aiops-substrate
./tools/git-commit-all.sh "docs: Update architecture documentation"

# Option 2: Commit each repo individually
cd ~/projects/suhlabs/aiops-substrate
git add .
git commit -m "feat: Add new deployment automation"
git push

cd ~/projects/suhlabs/ai-agent-governance-framework
git add .
git commit -m "feat: Add new validation rules"
git push
```

---

## Common Workflows

### **Workflow 1: Feature Across Multiple Repos**

When a feature requires changes in multiple repositories:

```bash
# Example: Add new governance policy that infrastructure uses

# Step 1: Work in governance repo
cd ~/projects/suhlabs/ai-agent-governance-framework
git checkout -b feature/deployment-validation
# ... make changes ...
git add .
git commit -m "feat: Add deployment validation policy"
git push origin feature/deployment-validation

# Step 2: Work in infrastructure repo
cd ~/projects/suhlabs/aiops-substrate
git checkout -b feature/use-deployment-validation
# ... make changes to use the new policy ...
git add .
git commit -m "feat: Integrate deployment validation policy"
git push origin feature/use-deployment-validation

# Step 3: Create PRs on GitHub
# - Merge governance PR first
# - Then merge infrastructure PR

# Step 4: Update main branches
cd ~/projects/suhlabs/ai-agent-governance-framework
git checkout main
git pull

cd ~/projects/suhlabs/aiops-substrate
git checkout main
git pull
```

---

### **Workflow 2: Coordinated Release**

When releasing a new version of the platform:

```bash
# Tag each repo with the same version number

# 1. Tag infrastructure
cd ~/projects/suhlabs/aiops-substrate
git tag -a v1.0.0 -m "Release v1.0.0: Freemium MVP"
git push origin v1.0.0

# 2. Tag governance
cd ~/projects/suhlabs/ai-agent-governance-framework
git tag -a v1.0.0 -m "Release v1.0.0: Freemium MVP"
git push origin v1.0.0

# 3. Tag AI POC
cd ~/projects/suhlabs/suhlabs-infr-ai-poc
git tag -a v1.0.0 -m "Release v1.0.0: Freemium MVP"
git push origin v1.0.0

# 4. Tag ML antipatterns
cd ~/projects/suhlabs/ml-antipatterns
git tag -a v1.0.0 -m "Release v1.0.0: Freemium MVP"
git push origin v1.0.0

# 5. Tag web
cd ~/projects/suhlabs/suhlabs-web
git tag -a v1.0.0 -m "Release v1.0.0: Freemium MVP"
git push origin v1.0.0

# 6. Create GitHub releases for each repo
# 7. Build appliance ISO with all v1.0.0 components
```

---

### **Workflow 3: Emergency Hotfix**

When you need to fix a critical bug:

```bash
# 1. Create hotfix branch
cd ~/projects/suhlabs/aiops-substrate
git checkout main
git pull
git checkout -b hotfix/critical-security-fix

# 2. Make the fix
# ... edit files ...

# 3. Commit and push
git add .
git commit -m "fix: Critical security vulnerability in certificate validation"
git push origin hotfix/critical-security-fix

# 4. Create PR, get review, merge immediately

# 5. Tag hotfix release
git checkout main
git pull
git tag -a v1.0.1 -m "Hotfix v1.0.1: Security patch"
git push origin v1.0.1
```

---

## Branching Strategy

### **Main Branches**

Each repository follows the same strategy:

```
main (or master)          # Production-ready code
└── develop               # Integration branch (optional)
```

### **Feature Branches**

```bash
feature/new-feature       # New features
fix/bug-description       # Bug fixes
hotfix/critical-fix       # Emergency fixes
docs/documentation        # Documentation updates
chore/maintenance         # Maintenance tasks
```

### **Examples**

```bash
# Infrastructure repo
git checkout -b feature/add-monitoring
git checkout -b fix/vault-unsealing-issue
git checkout -b docs/update-installation-guide

# Governance repo
git checkout -b feature/policy-validation-api
git checkout -b fix/permission-check-bug
```

---

## Commit Message Conventions

Use **Conventional Commits** format:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### **Types**

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `chore`: Maintenance tasks
- `refactor`: Code refactoring
- `test`: Adding tests
- `ci`: CI/CD changes
- `perf`: Performance improvements

### **Examples**

```bash
# Good commits
git commit -m "feat(governance): Add deployment validation policy"
git commit -m "fix(infra): Repair certificate renewal logic"
git commit -m "docs(readme): Update architecture diagram"
git commit -m "chore(deps): Update Kubernetes to v1.28"

# Bad commits (avoid these)
git commit -m "updates"
git commit -m "fix stuff"
git commit -m "WIP"
```

---

## Helper Scripts

### **1. git-status-all.sh**

Check status of all 5 repos:

```bash
cd ~/projects/suhlabs/aiops-substrate
./tools/git-status-all.sh
```

**Output:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   📊 SuhLabs Platform - Git Status Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📁 aiops-substrate
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Branch: main
   Status: ⚠️  Has changes

## main
 M docs/GIT-WORKFLOW.md
 M tools/git-status-all.sh

📁 ai-agent-governance-framework
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Branch: main
   Status: ✓ Clean
```

---

### **2. git-pull-all.sh**

Pull latest changes from all repos:

```bash
cd ~/projects/suhlabs/aiops-substrate
./tools/git-pull-all.sh
```

**Features:**

- Auto-stashes uncommitted changes
- Pulls with rebase
- Applies stashed changes back
- Shows summary of updates

---

### **3. git-commit-all.sh**

Commit changes across all repos with same message:

```bash
cd ~/projects/suhlabs/aiops-substrate
./tools/git-commit-all.sh "docs: Update project documentation"
```

**What it does:**

- Checks each repo for changes
- Commits changes with your message
- Pushes to remote
- Shows summary

---

## Make Helper Scripts Executable

After creating the scripts, make them executable:

```bash
cd ~/projects/suhlabs/aiops-substrate/tools
chmod +x git-status-all.sh
chmod +x git-pull-all.sh
chmod +x git-commit-all.sh
```

---

## Dependency Management

### **Document Inter-Repo Dependencies**

In each repo's README, document which versions of other repos it depends on:

**Example: `aiops-substrate/README.md`**

```markdown
## Dependencies

This release is tested with:

- ai-agent-governance-framework: v1.0.0
- suhlabs-infr-ai-poc: v0.5.0
- ml-antipatterns: v0.3.0
```

---

## Best Practices

### **1. Keep Repos in Sync**

```bash
# Start of week: Pull everything
./tools/git-pull-all.sh

# Work on specific repos
# ...

# End of day: Check and commit
./tools/git-status-all.sh
./tools/git-commit-all.sh "work: Daily progress"
```

---

### **2. Use Feature Branches**

```bash
# Never commit directly to main
git checkout -b feature/my-feature

# Work, commit, push
git push origin feature/my-feature

# Create PR on GitHub
# Merge after review
```

---

### **3. Coordinate Breaking Changes**

If a change in one repo breaks another:

1. Create feature branches in both repos
2. Test integration locally
3. Merge in order (dependencies first)
4. Update version numbers

**Example:**

```bash
# Governance adds new API (breaking change)
cd ~/projects/suhlabs/ai-agent-governance-framework
git checkout -b feature/new-api-v2
# ... implement ...
git push origin feature/new-api-v2

# Infrastructure updates to use new API
cd ~/projects/suhlabs/aiops-substrate
git checkout -b feature/use-api-v2
# ... update code ...
git push origin feature/use-api-v2

# Merge order: governance first, then infrastructure
```

---

### **4. Tag Releases Consistently**

```bash
# Always tag all 5 repos with same version
v1.0.0 - Initial release
v1.1.0 - New features
v1.1.1 - Hotfix
v2.0.0 - Breaking changes
```

---

## Troubleshooting

### **Problem: Uncommitted changes when pulling**

```bash
# Stash changes
git stash

# Pull
git pull

# Apply stashed changes
git stash pop
```

---

### **Problem: Merge conflicts**

```bash
# See conflicted files
git status

# Edit files to resolve conflicts
# Look for <<<<<<< HEAD markers

# Mark as resolved
git add <file>

# Continue
git commit
```

---

### **Problem: Forgot which repo I'm in**

```bash
# Check current repo
pwd
git remote -v

# Or use git-status-all.sh to see everything
```

---

## Quick Reference

```bash
# Daily commands
./tools/git-status-all.sh              # Check all repos
./tools/git-pull-all.sh                # Update all repos
./tools/git-commit-all.sh "message"    # Commit all repos

# Single repo commands
git status                              # Check status
git add .                               # Stage all changes
git commit -m "message"                 # Commit
git push                                # Push to remote
git pull                                # Get latest
git checkout -b feature/name            # New branch
git branch                              # List branches

# Tagging
git tag -a v1.0.0 -m "Release v1.0.0"  # Create tag
git push origin v1.0.0                  # Push tag
git tag -l                              # List tags
```

---

## Summary

**Key Principles:**

1. ✅ Each repo is independent (separate Git history)
2. ✅ Use helper scripts to manage all repos together
3. ✅ Use VS Code workspace to see all repos at once
4. ✅ Follow conventional commit messages
5. ✅ Use feature branches (never commit directly to main)
6. ✅ Tag releases consistently across all repos
7. ✅ Document dependencies between repos

**Your workflow:**

- Morning: `./tools/git-pull-all.sh`
- During work: `./tools/git-status-all.sh`
- End of day: `./tools/git-commit-all.sh "message"`

---

**Questions? See the README in each repository or ask in team discussions.**
