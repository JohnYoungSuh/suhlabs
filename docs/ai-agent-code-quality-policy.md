# AI Agent Code Quality & Security Policy

**Version:** 1.0
**Last Updated:** 2025-11-20
**Status:** Active
**Integration:** AI Agent Governance Framework

---

## Purpose

This policy defines mandatory code quality and security standards that ALL AI agents must enforce when generating, modifying, or reviewing code in the suhlabs organization.

---

## 1. YAML File Standards

### 1.1 Indentation Rules (CRITICAL)

**Policy:** All YAML files MUST use consistent 2-space indentation.

**Rules:**
- Base level: 0 spaces
- Each nested level: +2 spaces
- List items (`-`): Same indent as parent key + 2 spaces
- List item content: List marker position + 2 spaces

**Examples:**

✅ **CORRECT:**
```yaml
spec:
  containers:
    - name: app
      image: myapp:latest
      ports:
        - name: http
          containerPort: 8080
      env:
        - name: LOG_LEVEL
          value: "info"
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: app-data
```

❌ **INCORRECT:**
```yaml
spec:
  containers:
  - name: app              # Wrong: should be +2 from containers
    image: myapp:latest
    ports:
    - name: http           # Wrong: should be +2 from ports
      containerPort: 8080
```

### 1.2 Comment Indentation

**Policy:** Comments MUST be indented at the same level as the content they describe.

✅ **CORRECT:**
```yaml
volumes:
  - name: data
    # This is a persistent volume
    persistentVolumeClaim:
      claimName: app-data
```

❌ **INCORRECT:**
```yaml
volumes:
  - name: data
  # Wrong indent level
  persistentVolumeClaim:
    claimName: app-data
```

### 1.3 Empty YAML Files

**Policy:** NEVER commit completely empty YAML files.

**Action:** If a YAML file is not yet implemented, add a placeholder comment:

```yaml
# ============================================================================
# [Component Name] Configuration
# ============================================================================
# TODO: Implement [component] configuration
# Placeholder for future implementation
```

### 1.4 YAML Validation

**Mandatory Checks:**
- Run `yamllint` before committing
- Use `.yamllint.yml` configuration if present
- Fix ALL errors (not just warnings)

---

## 2. Terraform Standards

### 2.1 Empty Terraform Files

**Policy:** NEVER commit completely empty `.tf` files.

**Action:** If not yet implemented, use this structure:

```terraform
# ============================================================================
# [Resource Name] Terraform Configuration
# ============================================================================
# NOTE: This configuration is a placeholder for future [purpose].
# Remove this comment when implementing.

# Uncomment when ready:
# terraform {
#   required_version = ">= 1.6"
#
#   required_providers {
#     provider_name = {
#       source  = "namespace/provider"
#       version = "~> X.Y"
#     }
#   }
# }
```

### 2.2 Security Scanning

**Mandatory:** All Terraform code MUST pass `tfsec` scanning.

**Common Issues to Prevent:**
- Unencrypted storage
- Public S3 buckets
- Missing security groups
- Weak encryption algorithms
- Exposed secrets

---

## 3. Shell Script Standards

### 3.1 ShellCheck Compliance

**Policy:** All shell scripts MUST pass ShellCheck with zero warnings.

**Critical Rules:**

#### SC2034 - Unused Variables
```bash
# ❌ WRONG
UNUSED_VAR="value"  # Never used

# ✅ CORRECT
USED_VAR="value"
echo "$USED_VAR"

# ✅ OR if reserved for future use:
# RESERVED_VAR="value"  # Reserved for future implementation
```

#### SC2155 - Declare and Assign Separately
```bash
# ❌ WRONG (masks command exit code)
local result=$(some_command)

# ✅ CORRECT
local result
result=$(some_command)
```

#### SC2086 - Quote Variables
```bash
# ❌ WRONG
rm $file_path

# ✅ CORRECT
rm "$file_path"
```

### 3.2 Error Handling

**Policy:** Scripts MUST use proper error handling.

```bash
#!/bin/bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures

# OR for more control:
set -e
trap 'echo "Error on line $LINENO"' ERR
```

---

## 4. Secrets Management

### 4.1 NO Hardcoded Secrets (CRITICAL)

**Policy:** NEVER commit files containing hardcoded secrets, passwords, API keys, or credentials.

**Prohibited Patterns:**
```yaml
# ❌ NEVER DO THIS
password: "my-secret-password"
api_key: "sk-1234567890abcdef"
token: "ghp_xxxxxxxxxxxx"
AWS_SECRET_ACCESS_KEY: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

### 4.2 Template-Based Secrets

**Policy:** Use templates with environment variable placeholders.

**Pattern:**
1. Commit: `config.yaml.template` with placeholders
2. Gitignore: `config.yaml` (actual secrets)
3. Deploy: Script replaces placeholders from Vault/env vars

**Example:**
```yaml
# config.yaml.template (committed)
database:
  password: "${VAULT_DB_PASSWORD}"
  api_key: "${VAULT_API_KEY}"
```

```bash
# .gitignore (must include)
config.yaml
*.env
!.env.example
*.key
*.pem
*.token
```

### 4.3 Pre-Commit Hooks

**Mandatory:** Use pre-commit hooks to prevent secret commits.

**Required Tools:**
- gitleaks
- detect-secrets
- TruffleHog

---

## 5. Git Hygiene

### 5.1 Gitignore Standards

**Policy:** Update `.gitignore` BEFORE creating sensitive files.

**Mandatory Exclusions:**
```gitignore
# Secrets
*.key
*.pem
*.crt
*.token
*.env
!.env.example
*vault*keys*

# Build artifacts
*.tfstate
*.tfstate.*
.terraform/

# Local dev
venv/
.venv/
__pycache__/
*.pyc

# IDE
.vscode/settings.json
.idea/
```

### 5.2 Commit Messages

**Policy:** Use conventional commit format.

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `fix:` - Bug fixes
- `feat:` - New features
- `docs:` - Documentation
- `style:` - Formatting
- `refactor:` - Code restructuring
- `test:` - Testing
- `chore:` - Maintenance
- `security:` - Security fixes (CRITICAL)

---

## 6. Security Scanning Integration

### 6.1 Mandatory Scans

**Policy:** All code MUST pass these scans before merging:

| Scan Type | Tool | Severity Threshold |
|-----------|------|-------------------|
| Secret Detection | TruffleHog, GitLeaks | Zero tolerance |
| Container Security | Trivy, Grype | HIGH+ must be addressed |
| K8s Security | Kubesec | Score > 0 |
| IaC Security | tfsec | MEDIUM+ must be fixed |
| Dependency Scan | Safety, Dependabot | HIGH+ must be patched |
| Code Linting | ShellCheck, yamllint | Zero errors |

### 6.2 Scan Frequency

- **On every commit:** Secret scanning
- **On PR:** All scans
- **Daily:** Full security scan
- **Weekly:** Dependency updates

---

## 7. AI Agent Requirements

### 7.1 Pre-Generation Checklist

Before generating ANY code, AI agents MUST:

1. ✅ Check if similar files exist for style reference
2. ✅ Verify `.gitignore` is configured for file type
3. ✅ Confirm no secrets will be embedded
4. ✅ Use appropriate linting rules for language
5. ✅ Plan proper indentation structure
6. ✅ Include error handling

### 7.2 Post-Generation Validation

After generating code, AI agents MUST:

1. ✅ Run language-specific linter
2. ✅ Check for security anti-patterns
3. ✅ Verify indentation consistency
4. ✅ Scan for secrets/credentials
5. ✅ Add appropriate comments
6. ✅ Update `.gitignore` if needed

### 7.3 File Modification Rules

When modifying existing files, AI agents MUST:

1. ✅ Preserve existing indentation style
2. ✅ Match brace/bracket style
3. ✅ Keep consistent naming conventions
4. ✅ Maintain comment formatting
5. ✅ Run linter after changes

---

## 8. Language-Specific Rules

### 8.1 Python

```python
# Required at top of file
#!/usr/bin/env python3
"""Module docstring describing purpose."""

# Formatting
# - Use Black formatter
# - Max line length: 88 chars
# - Use type hints

# Linting
# - Pass flake8
# - Pass pylint (score > 8.0)
# - Pass mypy (strict mode)
```

### 8.2 Bash

```bash
#!/bin/bash
# Script description

set -euo pipefail  # REQUIRED

# Use shellcheck directives if needed
# shellcheck disable=SC2034
RESERVED_VAR="future-use"
```

### 8.3 YAML/JSON

```yaml
# Always validate syntax
# Use yamllint or jsonlint
# Keep consistent 2-space indentation
# Use string quotes for values with special chars
```

### 8.4 Terraform

```terraform
# Required formatting: terraform fmt
# Required validation: terraform validate
# Security scan: tfsec
# Use terraform-docs for documentation
```

---

## 9. Exception Handling

### 9.1 Security Exceptions

**Process:**
1. Document WHY exception is needed
2. Get approval from security team
3. Add comment with JIRA/issue reference
4. Set expiration date for review

```yaml
# SECURITY-EXCEPTION: JIRA-1234
# Reason: Legacy system requires HTTP (no HTTPS support)
# Approved by: security@example.com
# Expires: 2025-12-31
# Compensating control: VPN-only access
url: "http://legacy.internal"
```

### 9.2 Linting Exceptions

```bash
# Only when absolutely necessary
# shellcheck disable=SC2154  # Variable defined in sourced file
echo "$EXTERNAL_VAR"
```

---

## 10. Enforcement

### 10.1 Automated Enforcement

**CI/CD Pipeline MUST:**
- Block PRs failing security scans
- Require linting passes
- Prevent secret commits
- Enforce commit message format

### 10.2 Manual Review

**Code reviews MUST check:**
- [ ] No hardcoded secrets
- [ ] Proper indentation
- [ ] Error handling present
- [ ] Comments are meaningful
- [ ] Tests included (if applicable)

### 10.3 Violations

**Severity Levels:**

| Level | Examples | Action |
|-------|----------|--------|
| **CRITICAL** | Committed secrets | Immediate revert, rotate secrets |
| **HIGH** | Failed security scans | Block merge |
| **MEDIUM** | Linting errors | Block merge |
| **LOW** | Style inconsistencies | Request changes |

---

## 11. Training & Resources

### 11.1 Required Reading

- [ ] OWASP Top 10
- [ ] Kubernetes Security Best Practices
- [ ] Terraform Security Best Practices
- [ ] This policy document

### 11.2 Tools Documentation

- [yamllint](https://yamllint.readthedocs.io/)
- [ShellCheck](https://www.shellcheck.net/)
- [tfsec](https://aquasecurity.github.io/tfsec/)
- [TruffleHog](https://github.com/trufflesecurity/trufflehog)
- [gitleaks](https://github.com/gitleaks/gitleaks)

---

## 12. Policy Updates

**Version History:**

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2025-11-20 | Initial policy based on security scan findings | AI Agent |

**Review Schedule:** Quarterly

**Change Process:**
1. Propose changes via PR
2. Security team review
3. Update version number
4. Announce to team

---

## Appendix A: Quick Reference Card

### Before Every Commit
```bash
# 1. Run linters
yamllint .
shellcheck **/*.sh
terraform fmt -check
terraform validate

# 2. Scan for secrets
gitleaks detect
trufflehog filesystem .

# 3. Check git status
git status
# Ensure no .env, *.key, *.pem files staged

# 4. Review diff
git diff --staged
# Look for: passwords, keys, tokens, TODO/FIXME

# 5. Commit with proper message
git commit -m "fix(security): resolve YAML indentation errors"
```

### YAML Indentation Cheat Sheet
```yaml
# Level 0
key: value
nested:          # Level 0
  key: value     # Level 1 (2 spaces)
  list:          # Level 1
    - item1      # Level 2 (4 spaces) - list marker
      subkey: v  # Level 3 (6 spaces) - under list item
    - item2      # Level 2
      subkey: v  # Level 3
```

---

## Appendix B: Pre-Commit Hook Setup

```bash
# Install pre-commit
pip install pre-commit

# Create .pre-commit-config.yaml
cat > .pre-commit-config.yaml <<'EOF'
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.0
    hooks:
      - id: gitleaks

  - repo: https://github.com/adrienverge/yamllint
    rev: v1.33.0
    hooks:
      - id: yamllint
        args: [--strict]

  - repo: https://github.com/koalaman/shellcheck-precommit
    rev: v0.9.0
    hooks:
      - id: shellcheck

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: check-yaml
      - id: check-json
      - id: check-added-large-files
      - id: detect-private-key
      - id: trailing-whitespace
      - id: end-of-file-fixer
EOF

# Install hooks
pre-commit install

# Test
pre-commit run --all-files
```

---

**Policy Owner:** Security Team
**Questions:** security@suhlabs.internal
**Last Audit:** 2025-11-20
