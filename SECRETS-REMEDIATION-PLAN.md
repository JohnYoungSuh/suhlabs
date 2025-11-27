# Secrets Remediation Plan

## Executive Summary

Gitleaks detected **24 potential secrets** in the repository. After analysis:
- **8 TRUE POSITIVES**: Hardcoded placeholder passwords that need remediation
- **16 FALSE POSITIVES**: Password generation code, variable references, and documentation

## Analysis Results

### Category 1: TRUE POSITIVES (Require Action)

These files contain hardcoded placeholder passwords that should be moved to proper secrets management:

#### 1. services/photoprism/kubernetes/03-mariadb.yaml
- **Line ~90**: `password: "root-password-change-me"`
- **Line ~95**: `password: "photoprism-password-change-me"`
- **Risk**: Medium (deployment template, but committed to git)
- **Action**: Convert to Kubernetes Secret or Vault reference

#### 2. services/photoprism/kubernetes/02-minio.yaml
- **Line ~87**: `Password: "minioadmin-change-me"`
- **Risk**: Medium (deployment template)
- **Action**: Convert to Kubernetes Secret or Vault reference

#### 3. services/photoprism/kubernetes/04-photoprism.yaml
- **Line ~45**: `PASSWORD: "change-me-admin-password"`
- **Line ~60**: `PASSWORD: "photoprism-password-change-me"`
- **Risk**: Medium (deployment template)
- **Action**: Convert to Kubernetes Secret or Vault reference

#### 4. cluster/core/minio/minio.yaml
- **Line ~90**: `password: "changeme123"`
- **Risk**: Medium (simple password in deployment)
- **Action**: Replace with generated password or Vault reference

#### 5. tests/integration/test_docker_services.py
- **Line ~139**: `password="changeme123"`
- **Risk**: Low (test code only)
- **Action**: Use environment variable or test fixtures

### Category 2: FALSE POSITIVES (Safe - Allowlist)

These findings are NOT security issues:

#### Password Generation Code (Safe)
- **scripts/deploy-with-vault.sh** (6 findings): `Password="$(openssl rand -base64 32)"` - Generates passwords dynamically
- **services/photoprism/deploy-family.sh** (4 findings): Similar password generation
- **cluster/ai-ops-agent/ai_ops_agent/onboarding/__init__.py** (2 findings): Python password generation using `secrets` module

#### Variable References (Safe)
- **ansible/roles/freeipa/tasks/main.yml** (2 findings): Ansible template lookups `{{ lookup(...) }}`

#### Documentation (Safe)
- **services/photoprism/kubernetes/06-authelia.yaml** (3 findings): Comments showing password hash generation examples

## Remediation Strategy

### Phase 1: Update Gitleaks Configuration (Immediate)

Add the following patterns to `.gitleaks.toml` allowlist to reduce false positives:

```toml
[allowlist]
regexes = [
    # Existing patterns...
    '''Password="\$\(openssl rand''',      # Password generation
    '''password="\$\(openssl rand''',      # Password generation
    '''Password="\$\{[a-zA-Z_]+\}"''',     # Variable references
    '''password = .*.join\(secrets''',     # Python secrets module
    '''\{\{ lookup\(''',                   # Ansible lookups
    '''hash-password .yourpassword.''',    # Documentation examples
]

paths = [
    '''\.template$''',
    '''\.md$''',
    '''\.example$''',
    '''SECURITY-SCAN-REVIEW\.md''',       # Documentation
    '''docs/14-DAY-SPRINT\.md''',         # Sprint docs
]
```

### Phase 2: Remediate Hardcoded Passwords (Priority)

#### Option A: Use Kubernetes Secrets (Recommended for aiops-substrate)

Create Kubernetes secrets and reference them in manifests:

```bash
# Generate secure passwords
MARIADB_ROOT_PASS=$(openssl rand -base64 32)
MARIADB_USER_PASS=$(openssl rand -base64 32)
MINIO_PASS=$(openssl rand -base64 32)
PHOTOPRISM_ADMIN_PASS=$(openssl rand -base64 32)

# Create Kubernetes secrets
kubectl create secret generic mariadb-secret \
  --from-literal=root-password="${MARIADB_ROOT_PASS}" \
  --from-literal=user-password="${MARIADB_USER_PASS}" \
  -n photoprism

kubectl create secret generic minio-secret \
  --from-literal=password="${MINIO_PASS}" \
  -n photoprism

kubectl create secret generic photoprism-secret \
  --from-literal=admin-password="${PHOTOPRISM_ADMIN_PASS}" \
  -n photoprism
```

Then update manifests to reference secrets:

```yaml
# Before:
- name: MYSQL_ROOT_PASSWORD
  value: "root-password-change-me"

# After:
- name: MYSQL_ROOT_PASSWORD
  valueFrom:
    secretKeyRef:
      name: mariadb-secret
      key: root-password
```

#### Option B: Use HashiCorp Vault (Production Pattern)

Already implemented in this project - extend to photoprism services:

```bash
# Store in Vault
vault kv put secret/photoprism/mariadb \
  root_password="${MARIADB_ROOT_PASS}" \
  user_password="${MARIADB_USER_PASS}"

vault kv put secret/photoprism/minio \
  password="${MINIO_PASS}"
```

Use cert-manager + external-secrets-operator to sync to Kubernetes.

#### Option C: Template Files (Development Pattern)

Rename files with `.template` extension and create deployment script:

```bash
# services/photoprism/kubernetes/03-mariadb.yaml.template
password: "${MARIADB_ROOT_PASSWORD}"  # Will be replaced by deploy script

# Deploy script generates actual files with real secrets
envsubst < 03-mariadb.yaml.template > 03-mariadb.yaml
```

Add `*.yaml` to `.gitignore` (except templates).

### Phase 3: Test File Remediation

For `tests/integration/test_docker_services.py`:

```python
# Before:
password="changeme123"

# After:
import os
password = os.environ.get("TEST_PASSWORD", "changeme123")  # Fallback for local dev
```

### Phase 4: Git History Cleanup (Optional)

Since these are placeholder passwords (not real secrets), git history cleanup is **NOT CRITICAL**. However, for best practices:

```bash
# Use BFG Repo-Cleaner or git-filter-repo to remove from history
# Only do this if passwords were ever real production credentials

# Example with BFG:
bfg --replace-text passwords.txt aiops-substrate
git reflog expire --expire=now --all
git gc --prune=now --aggressive
```

**IMPORTANT**: Coordinate with team before rewriting git history!

### Phase 5: Implement Secrets Detection in Pre-Commit

Add to `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.21.2
    hooks:
      - id: gitleaks
```

Install pre-commit hook:

```bash
pip install pre-commit
pre-commit install
pre-commit run --all-files  # Test on existing files
```

## Implementation Checklist

- [ ] **Step 1**: Update `.gitleaks.toml` with expanded allowlist patterns
- [ ] **Step 2**: Test gitleaks locally: `/tmp/gitleaks detect --config .gitleaks.toml -v`
- [ ] **Step 3**: Choose remediation strategy (Option A, B, or C)
- [ ] **Step 4**: Create Kubernetes secrets for photoprism services
- [ ] **Step 5**: Update manifest files to reference secrets
- [ ] **Step 6**: Update cluster/core/minio/minio.yaml with proper secret
- [ ] **Step 7**: Update test file to use environment variables
- [ ] **Step 8**: Test deployments with new secrets
- [ ] **Step 9**: Commit updated `.gitleaks.toml` and manifests
- [ ] **Step 10**: Verify GitHub Actions security scan passes
- [ ] **Step 11**: Install pre-commit hook for future prevention
- [ ] **Step 12**: Document secrets management in README.md

## Timeline Estimate

- **Phase 1** (Gitleaks config): 15 minutes
- **Phase 2** (Remediate passwords): 30-45 minutes
- **Phase 3** (Test file): 5 minutes
- **Phase 4** (Git history): Optional, 1-2 hours if needed
- **Phase 5** (Pre-commit): 15 minutes

**Total**: ~1.5 hours (excluding optional git history cleanup)

## Risk Assessment

### Current Risk: LOW-MEDIUM

**Why LOW:**
- All detected passwords are placeholders (e.g., "change-me", "changeme123")
- No real production credentials are exposed
- Repository appears to be personal/educational project

**Why concerns exist:**
- Hardcoded passwords in manifests train bad habits
- If accidentally deployed with these passwords, creates security risk
- Violates security best practices in project documentation

### Post-Remediation Risk: MINIMAL

After implementing this plan:
- All secrets properly managed via Kubernetes Secrets or Vault
- Gitleaks configured to catch real issues without false positives
- Pre-commit hooks prevent future secret commits
- Follows project's own governance framework requirements

## Governance Framework Compliance

Per `/home/suhlabs/projects/suhlabs/ai-agent-governance-framework/UNIFIED-AI-AGENT-GOVERNANCE-FRAMEWORK-v3.0.md`:

- ✅ **Section 10**: Secrets must be in approved stores (Vault, K8s Secrets)
- ✅ **Section 23**: No credential exposure to stdout (this plan ensures that)
- ✅ **Section 8.2**: Secrets declared in orchestration manifests, not runtime

This remediation plan brings the project into full compliance.

## Questions for User

Before proceeding with remediation, please confirm:

1. **Which remediation strategy do you prefer?**
   - A: Kubernetes Secrets (simplest, good for dev)
   - B: Vault (production-ready, already implemented for other services)
   - C: Template files (flexible, requires deployment scripts)

2. **Do these photoprism services exist in production?**
   - If yes, we should rotate passwords
   - If no/dev-only, we can just replace with secure values

3. **Should we clean git history?**
   - Recommended if real secrets were ever committed
   - Not critical for placeholder passwords
   - Requires force-push coordination

4. **Priority level:**
   - Immediate (fix today)
   - High (fix this week)
   - Medium (fix when convenient)

## Next Steps

Once you answer the questions above, I will:
1. Update `.gitleaks.toml` configuration
2. Implement chosen remediation strategy
3. Test all changes locally
4. Create a PR with the fixes
5. Verify GitHub Actions security scan passes

---

**Report Generated**: 2025-11-27
**Gitleaks Version**: 8.21.2
**Total Findings**: 24 (8 true positives, 16 false positives)
**Estimated Remediation Time**: 1.5 hours
