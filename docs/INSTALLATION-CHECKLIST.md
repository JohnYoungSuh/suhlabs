# 🎯 Advanced Features - Installation Checklist

Use this checklist to install and verify all advanced features.

---

## ✅ Phase 1: Install Git Hooks (5 minutes)

### **1.1 Make Scripts Executable**

```bash
cd ~/projects/suhlabs/aiops-substrate/tools
chmod +x *.sh
chmod +x hooks/*
```

- [ ] Completed

### **1.2 Run Hook Installer**

```bash
./install-hooks.sh
```

- [ ] Completed
- [ ] Saw success message
- [ ] No errors

### **1.3 Verify Hooks Installed**

```bash
ls -la ../.git/hooks/
```

**Expected output:**

```
-rwxr-xr-x pre-commit
-rwxr-xr-x commit-msg
```

- [ ] `pre-commit` exists and is executable
- [ ] `commit-msg` exists and is executable

### **1.4 Create VS Code Workspace** (Optional)

**Location:** Create in parent directory (`~/projects/suhlabs/`)

```bash
cd ~/projects/suhlabs

cat > suhlabs-platform.code-workspace << 'EOF'
{
  "folders": [
    {"name": "🌐 Web", "path": "./suhlabs-web"},
    {"name": "🏗️ Infrastructure", "path": "./aiops-substrate"},
    {"name": "🛡️ Governance", "path": "./ai-agent-governance-framework"},
    {"name": "🤖 AI POC", "path": "./suhlabs-infr-ai-poc"},
    {"name": "📊 ML Antipatterns", "path": "./ml-antipatterns"}
  ],
  "settings": {
    "git.detectSubmodules": true
  }
}
EOF

# Test: Open workspace
code suhlabs-platform.code-workspace
```

- [ ] Workspace file created
- [ ] Opens all 5 repos in VS Code
- [ ] All folders visible in sidebar

**Note:** This is optional but recommended for easier multi-repo development.

---

## ✅ Phase 2: Install Optional Tools (10 minutes)

### **2.1 Install ShellCheck**

```bash
sudo apt update
sudo apt install shellcheck -y
shellcheck --version
```

- [ ] Installed successfully
- [ ] Version displayed

### **2.2 Install Node.js Tools** (Optional)

```bash
# markdownlint
npm install -g markdownlint-cli

# commitlint
npm install -g @commitlint/cli @commitlint/config-conventional
```

- [ ] markdownlint installed (or skipped)
- [ ] commitlint installed (or skipped)

---

## ✅ Phase 3: Test Git Hooks (5 minutes)

### **3.1 Test Pre-commit Hook**

```bash
# Create a test file with a "secret"
echo "password = 'test123'" > test-secret.txt
git add test-secret.txt

# Try to commit (should fail)
git commit -m "test: Add secret"
```

**Expected:** ❌ Commit blocked with secret warning

- [ ] Pre-commit hook blocked the commit
- [ ] Saw secret detection warning

**Cleanup:**

```bash
git reset HEAD test-secret.txt
rm test-secret.txt
```

- [ ] Cleaned up test file

### **3.2 Test Commit Message Validation**

```bash
# Try bad commit message
git commit --allow-empty -m "bad commit"
```

**Expected:** ❌ Commit blocked with format error

- [ ] Commit-msg hook blocked bad format
- [ ] Saw format guidance

```bash
# Try good commit message
git commit --allow-empty -m "test(hooks): Verify hook installation"
```

**Expected:** ✅ Commit succeeded

- [ ] Commit succeeded with correct format

---

## ✅ Phase 4: Verify Configuration Files (2 minutes)

### **4.1 Check Files Exist**

```bash
cd ~/projects/suhlabs/aiops-substrate

ls -la .commitlintrc.json
ls -la .markdownlint.json
ls -la trivy.yaml
ls -la .github/CODEOWNERS
ls -la .github/workflows/validate.yml
ls -la .github/workflows/multi-repo-status.yml
```

- [ ] `.commitlintrc.json` exists
- [ ] `.markdownlint.json` exists
- [ ] `trivy.yaml` exists
- [ ] `.github/CODEOWNERS` exists
- [ ] `.github/workflows/validate.yml` exists
- [ ] `.github/workflows/multi-repo-status.yml` exists

---

## ✅ Phase 5: Test Makefile Commands (3 minutes)

### **5.1 Test Git Status**

```bash
make -f tools/Makefile.git git-status
```

- [ ] Command ran successfully
- [ ] Showed status of repos

### **5.2 Test Validation**

```bash
make -f tools/Makefile.git git-validate
```

- [ ] ShellCheck ran (or skipped with warning)
- [ ] No critical errors

### **5.3 Test Help**

```bash
make -f tools/Makefile.git git-help
```

- [ ] Quick reference displayed

---

## ✅ Phase 6: Push to GitHub & Verify CI/CD (5 minutes)

### **6.1 Commit All New Files**

```bash
cd ~/projects/suhlabs/aiops-substrate

git add .github/ tools/ docs/ *.json *.yaml
git status
```

- [ ] All new files staged

### **6.2 Commit with Hooks**

```bash
git commit -m "feat(devops): Add enterprise Git automation

- Add pre-commit hooks for security and quality
- Add GitHub Actions CI/CD workflows
- Add linter configurations
- Add CODEOWNERS and enhanced tooling
"
```

- [ ] Commit succeeded (hooks passed)
- [ ] Saw pre-commit check messages

### **6.3 Push to GitHub**

```bash
git push origin main
```

- [ ] Push succeeded

### **6.4 Check GitHub Actions**

1. Go to GitHub repository
2. Click "Actions" tab
3. See "Validate Code Quality" workflow running

- [ ] GitHub Actions workflow triggered
- [ ] Workflow is running/completed
- [ ] All jobs passed (or diagnosed issues)

---

## ✅ Phase 7: Verify GitHub Integration (3 minutes)

### **7.1 Check Security Tab**

1. Go to GitHub → Security → Code scanning
2. Look for Trivy scan results

- [ ] Security tab has scan results (after first run)

### **7.2 Check CODEOWNERS**

1. Create a test PR (optional)
2. Verify automatic reviewer assignment

- [ ] CODEOWNERS working (or will test with first PR)

---

## ✅ Phase 8: Optional Enhancements (10 minutes)

### **8.1 Update Main Makefile** (Optional)

Add to existing `Makefile`:

```makefile
# Include Git automation targets
include tools/Makefile.git
```

- [ ] Updated main Makefile (or decided to use direct path)

### **8.2 Add Status Badge to README** (Optional)

Add to `README.md`:

```markdown
![Validate](https://github.com/YOUR_USERNAME/suhlabs/actions/workflows/validate.yml/badge.svg)
```

- [ ] Added CI/CD badge to README

### **8.3 Set Up Branch Protection** (Optional)

GitHub → Settings → Branches → Add rule for `main`:

- ✅ Require pull request reviews
- ✅ Require status checks to pass
- ✅ Require up to date branches

- [ ] Branch protection configured (or planned for later)

---

## 🎉 Final Verification

### **All Systems Check**

- [ ] **Git Hooks:** Installed and tested
- [ ] **Scripts:** All executable
- [ ] **Configs:** All files present
- [ ] **CI/CD:** Workflows pushed to GitHub
- [ ] **Makefile:** Commands working
- [ ] **Documentation:** All guides available

---

## 📋 What You Should Have Now

```
✅ Pre-commit hook (security + quality)
✅ Commit-msg hook (format validation)
✅ GitHub Actions (2 workflows)
✅ Configuration files (4 files)
✅ Enhanced Makefile
✅ Comprehensive documentation (3 guides)
✅ Helper scripts (all executable)
```

---

## 🚀 Ready to Use!

### **Daily Commands**

```bash
# Morning
make -f tools/Makefile.git git-morning

# Check status
make -f tools/Makefile.git git-status

# Commit
make -f tools/Makefile.git git-commit MSG="feat: Add feature"

# Help
make -f tools/Makefile.git git-help
```

---

## 📚 Documentation Reference

- **[ADVANCED-FEATURES-SUMMARY.md](ADVANCED-FEATURES-SUMMARY.md)** - Executive summary
- **[ADVANCED-FEATURES.md](ADVANCED-FEATURES.md)** - Complete guide
- **[GIT-WORKFLOW.md](GIT-WORKFLOW.md)** - Multi-repo workflows
- **[MULTI-REPO-SETUP.md](MULTI-REPO-SETUP.md)** - Initial setup

---

## ✅ Checklist Complete!

**Total Time:** ~30-45 minutes

**Result:** Enterprise-grade development infrastructure! 🏆

**Next:** Start using the tools in your daily workflow!

---

**Mark this document complete when all checkboxes are checked.**

_Last updated: 2025-12-20_
