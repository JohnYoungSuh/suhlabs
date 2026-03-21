# Advanced Features - Installation & Usage Guide

## 🚀 What Was Installed

### **1. Git Hooks** ✅

Pre-commit and commit-message validation hooks to enforce code quality.

### **2. GitHub Actions CI/CD** ✅

Automated workflows for code validation on every push/PR.

### **3. Linter Configurations** ✅

ShellCheck, Markdownlint, and Commitlint configs.

### **4. CODEOWNERS** ✅

Automated review assignment for pull requests.

### **5. Enhanced Makefile** ✅

Quick commands for Git operations.

### **6. Security Scanning** ✅

Trivy vulnerability scanner integrated into CI.

---

## 📦 Installation

### **Step 1: Install Git Hooks**

```bash
cd ~/projects/suhlabs/aiops-substrate

# Make installer executable
chmod +x tools/install-hooks.sh

# Install hooks
./tools/install-hooks.sh
```

**What this does:**

- ✅ Installs pre-commit hook (secret detection, ShellCheck)
- ✅ Installs commit-msg hook (conventional commits)
- ✅ Backs up existing hooks if present

---

### **Step 2: Install Linter Tools** (Optional but Recommended)

```bash
# ShellCheck (for bash script linting)
sudo apt install shellcheck

# markdownlint-cli (for documentation)
npm install -g markdownlint-cli

# commitlint (for commit messages)
npm install -g @commitlint/cli @commitlint/config-conventional
```

---

### **Step 3: Test the Hooks**

```bash
# Try making a commit with bad format
git commit -m "bad commit message"
# Should fail with format guidance

# Try with correct format
git commit -m "feat(tools): Add new feature"
# Should pass
```

---

## 🎯 Daily Usage

### **Morning Workflow**

```bash
# Option 1: Use Make
make -f tools/Makefile.git git-morning

# Option 2: Use script directly
./tools/git-pull-all.sh
./tools/git-status-all.sh
```

### **During Development**

```bash
# Check status frequently
make -f tools/Makefile.git git-status

# Or
./tools/git-status-all.sh
```

### **Evening Workflow**

```bash
# Commit changes
make -f tools/Makefile.git git-commit MSG="feat(api): Add new endpoint"

# Or
./tools/git-commit-all.sh "feat(api): Add new endpoint"
```

---

## 🔍 What Each Hook Does

### **pre-commit Hook**

Runs **before** every commit:

1. ✅ **Secret Detection** - Prevents committing passwords, API keys
2. ✅ **ShellCheck** - Lints bash scripts for errors
3. ✅ **Large Files** - Warns about files >5MB
4. ✅ **Branch Warning** - Reminds you if committing to main

**To bypass** (emergency only):

```bash
git commit --no-verify -m "emergency fix"
```

---

### **commit-msg Hook**

Validates **commit message format**:

**Required format:**

```
<type>(<scope>): <subject>

Examples:
  feat(api): Add user authentication
  fix(db): Repair connection leak
  docs: Update README
```

**Valid types:**

- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation
- `style` - Formatting
- `refactor` - Code restructuring
- `perf` - Performance
- `test` - Tests
- `chore` - Maintenance
- `ci` - CI/CD changes

---

## 🤖 GitHub Actions Workflows

### **validate.yml** - Code Quality Check

**Runs on:** Every push and PR

**What it checks:**

- ✅ ShellCheck on all `.sh` files
- ✅ Secret scanning with TruffleHog
- ✅ YAML linting
- ✅ Markdown linting
- ✅ Commit message format (PRs only)
- ✅ Security vulnerabilities with Trivy
- ✅ Documentation completeness

**View results:** GitHub → Actions tab

---

### **multi-repo-status.yml** - Repo Sync Check

**Runs on:**

- Manual trigger
- Every Monday at 9 AM

**What it does:**

- Checks if repos are in sync
- Reports uncommitted changes
- Shows commits ahead/behind origin

**Trigger manually:**
GitHub → Actions → Multi-Repo Sync Status → Run workflow

---

## 📊 GitHub Workflows Overview

### **Existing vs New Workflows**

This repository had **existing CI/CD workflows** before adding advanced features.  
Here's how they relate:

#### **Existing Workflows** (Pre-existing in repository)

| Workflow            | Purpose                         | Status    |
| ------------------- | ------------------------------- | --------- |
| `ci.yml`            | Basic CI checks                 | ✅ Active |
| `cd.yml`            | Deployment pipeline             | ✅ Active |
| `sbom.yml`          | Software Bill of Materials      | ✅ Active |
| `security-scan.yml` | Security vulnerability scanning | ✅ Active |

#### **New Workflows** (Added by advanced features)

| Workflow                | Purpose                               | Status |
| ----------------------- | ------------------------------------- | ------ |
| `validate.yml`          | Comprehensive code quality (7 checks) | ✅ NEW |
| `multi-repo-status.yml` | Multi-repo sync monitoring            | ✅ NEW |

### **Workflow Relationship**

```
Existing Workflows:
├── ci.yml            → May include ShellCheck, basic tests
├── cd.yml            → Deployment automation
├── sbom.yml          → Dependency tracking
└── security-scan.yml → Security scanning

New Workflows (Advanced Features):
├── validate.yml      → Additional quality checks (overlaps with ci.yml)
└── multi-repo-status.yml → Multi-repo specific

Recommendation:
- Review ci.yml for overlap with validate.yml
- Consider consolidating or clearly separating concerns
- Keep both if they serve different purposes
```

### **Next Steps**

1. **Review existing workflows** to understand what they check
2. **Identify overlaps** between `ci.yml` and `validate.yml`
3. **Options:**
   - Keep both (if they serve different stages/purposes)
   - Merge them (to avoid duplication)
   - Disable one (if completely redundant)

---

## 🛠️ Makefile Commands

### **Multi-Repo Git Operations**

```bash
make -f tools/Makefile.git git-status    # Check all repos
make -f tools/Makefile.git git-pull      # Pull all repos
make -f tools/Makefile.git git-commit MSG="your message"
```

### **Hooks Management**

```bash
make -f tools/Makefile.git git-hooks-install
make -f tools/Makefile.git git-hooks-uninstall
```

### **Validation**

```bash
make -f tools/Makefile.git git-validate  # Run ShellCheck
```

### **Workflow Shortcuts**

```bash
make -f tools/Makefile.git git-morning   # Pull + Status
make -f tools/Makefile.git git-evening   # Status + Reminder
make -f tools/Makefile.git dev-start     # Start dev session
make -f tools/Makefile.git dev-end       # End dev session
```

### **Tagging**

```bash
make -f tools/Makefile.git git-tag VERSION=v1.0.0
```

---

## 📋 Configuration Files

| File                 | Purpose                  |
| -------------------- | ------------------------ |
| `.commitlintrc.json` | Commit message rules     |
| `.markdownlint.json` | Documentation linting    |
| `trivy.yaml`         | Security scanning config |
| `.github/CODEOWNERS` | Review assignments       |

---

## 🔒 Security Features

### **1. Secret Detection**

**Pre-commit hook detects:**

- Passwords (`password =`)
- API keys (`api_key =`)
- Private keys (`BEGIN RSA PRIVATE KEY`)

**GitHub Actions:**

- TruffleHog scans entire history
- Runs on every push

### **2. Vulnerability Scanning**

**Trivy scanner:**

- Checks for CVEs in dependencies
- Reports uploaded to GitHub Security tab
- Runs on every push

**View results:**
GitHub → Security → Code scanning alerts

---

## 🚨 Troubleshooting

### **Hook Won't Run**

```bash
# Check if hooks are executable
ls -la .git/hooks/

# Should show:
# -rwxr-xr-x  pre-commit
# -rwxr-xr-x  commit-msg

# If not:
chmod +x .git/hooks/pre-commit
chmod +x .git/hooks/commit-msg
```

### **ShellCheck Not Found**

```bash
# Install ShellCheck
sudo apt install shellcheck

# Or skip in hook (already handled)
```

### **Commit Rejected**

```bash
# Read the error message carefully
# It will tell you what's wrong

# Common issues:
# 1. Secret detected → Remove secret
# 2. Bad commit format → Use: type(scope): message
# 3. ShellCheck failed → Fix script errors
```

### **Bypass Hook (Emergency)**

```bash
# Skip hooks (use sparingly!)
git commit --no-verify -m "emergency fix"
```

---

## 📊 View CI/CD Status

### **On GitHub**

1. Go to your repository
2. Click **Actions** tab
3. See all workflow runs
4. Click any run to see details

### **Add Status Badge to README**

```markdown
![Validate](https://github.com/JohnYoungSuh/suhlabs/actions/workflows/validate.yml/badge.svg)
```

---

## ✨ Best Practices

### **Daily Routine**

```bash
# Morning
make -f tools/Makefile.git git-morning

# During work
make -f tools/Makefile.git git-status  # Check often

# Evening
make -f tools/Makefile.git git-commit MSG="feat: Add feature"
```

### **Before Pushing**

```bash
# Validate locally
make -f tools/Makefile.git git-validate

# Check status
git log --oneline -3

# Push
git push
```

### **Working on Features**

```bash
# Always use feature branches
git checkout -b feature/new-feature

# Commit with conventional format
git commit -m "feat(api): Add new endpoint"

# Create PR (don't push to main directly)
```

---

## 🎓 Example Workflows

### **Adding a New Feature**

```bash
# 1. Pull latest
./tools/git-pull-all.sh

# 2. Create branch
git checkout -b feature/user-auth

# 3. Make changes
# ... edit files ...

# 4. Validate
make -f tools/Makefile.git git-validate

# 5. Commit (hooks will validate)
git commit -m "feat(auth): Add user authentication"

# 6. Push and create PR
git push origin feature/user-auth
```

### **Fixing a Bug**

```bash
# 1. Create hotfix branch
git checkout -b fix/login-bug

# 2. Fix the bug
# ... edit files ...

# 3. Commit
git commit -m "fix(auth): Repair login validation"

# 4. Push
git push origin fix/login-bug
```

### **Releasing a Version**

```bash
# 1. Ensure clean state
./tools/git-status-all.sh

# 2. Tag all 5 repos
cd ~/projects/suhlabs/aiops-substrate
make -f tools/Makefile.git git-tag VERSION=v1.0.0

# Repeat for other repos...
```

---

## 📝 Summary

You now have:

- ✅ Pre-commit hooks for quality enforcement
- ✅ Automated CI/CD pipelines
- ✅ Security scanning
- ✅ Code owners for reviews
- ✅ Enhanced Makefile commands
- ✅ Comprehensive validation

**This is enterprise-grade setup!** 🎉

---

**Questions?** See [GIT-WORKFLOW.md](GIT-WORKFLOW.md) for more details.
