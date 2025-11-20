# Security Fixes Summary

## Date: 2025-11-18

### Issues Found

A security audit revealed hardcoded passwords and sensitive defaults in Kubernetes manifests that were being committed to the repository.

**Critical Issues:**
- Default passwords in PhotoPrism manifests (services/photoprism/kubernetes/)
- Weak secrets in Authelia configuration
- Missing .gitignore patterns for sensitive files
- Merge conflict in .gitignore

### Changes Made

#### 1. Fixed .gitignore
- ✅ Resolved merge conflict
- ✅ Added comprehensive patterns for:
  - Virtual environments (venv/, .venv/)
  - Private keys (*.key, *.pem, *.crt)
  - Tokens (*.token, token.txt)
  - SSH keys (id_rsa, id_dsa, etc.)
  - Specific PhotoPrism YAML files with secrets

**File:** `.gitignore`

#### 2. Created Template-Based Secret Management

**Pattern:**
- `.yaml.template` files → Committed to git (with placeholders)
- `.yaml` files → Local only, in .gitignore (with real values)

**Template Files Created:**
- `services/photoprism/kubernetes/02-minio.yaml.template`
- `services/photoprism/kubernetes/03-mariadb.yaml.template`
- `services/photoprism/kubernetes/04-photoprism.yaml.template`
- `services/photoprism/kubernetes/06-authelia.yaml.template`

**Placeholders Used:**
```yaml
# Instead of:
PHOTOPRISM_ADMIN_PASSWORD: "change-me-admin-password"

# Templates use:
PHOTOPRISM_ADMIN_PASSWORD: "${VAULT_PHOTOPRISM_ADMIN_PASSWORD}"
```

#### 3. Created Deployment Scripts

**scripts/deploy-with-vault.sh**
- Fetches secrets from HashiCorp Vault
- Replaces placeholders in templates
- Deploys to Kubernetes with real secrets
- Supports dry-run mode
- Can initialize Vault secrets interactively

**scripts/setup-local-dev.sh**
- Copies templates to working .yaml files for local development
- Prompts before overwriting existing files

#### 4. Created Documentation

**docs/SECRET-MANAGEMENT.md**
- Complete guide for secret management
- Local development workflow
- Production deployment with Vault
- Vault secret structure
- Security best practices
- Troubleshooting guide
- Compliance information

#### 5. Added Pre-Commit Hooks

**Files:**
- `.pre-commit-config.yaml` - Pre-commit hook configuration
- `.gitleaks.toml` - Gitleaks secret detection rules
- `scripts/install-pre-commit.sh` - Easy installation script

**Protection Against:**
- Hardcoded API keys (GitHub, OpenAI, Anthropic, AWS, etc.)
- Private SSH/TLS keys
- Passwords in plaintext
- Database connection strings
- JWT tokens
- Committing .yaml files (only .template should be committed)
- Unreplaced Vault placeholders

### How It Works

#### Local Development
```bash
# 1. Setup local files
./scripts/setup-local-dev.sh

# 2. Edit .yaml files with local values
vim services/photoprism/kubernetes/04-photoprism.yaml

# 3. Deploy locally
kubectl apply -f services/photoprism/kubernetes/
```

#### Production Deployment
```bash
# 1. Authenticate to Vault
export VAULT_ADDR=https://vault.suhlabs.internal:8200
vault login

# 2. Deploy with Vault secrets
./scripts/deploy-with-vault.sh services/photoprism/kubernetes
```

#### Before Committing
```bash
# Install pre-commit hooks (one time)
./scripts/install-pre-commit.sh

# Hooks run automatically on commit
git commit -m "Update PhotoPrism configuration"

# Or run manually
pre-commit run --all-files
```

### What's Protected

#### Files That Won't Be Committed (in .gitignore)
- `services/photoprism/kubernetes/02-minio.yaml`
- `services/photoprism/kubernetes/03-mariadb.yaml`
- `services/photoprism/kubernetes/04-photoprism.yaml`
- `services/photoprism/kubernetes/06-authelia.yaml`
- All `*.key`, `*.pem`, `*.crt` files
- All `*.token` files
- Virtual environments
- SSH keys

#### Files That WILL Be Committed
- All `.yaml.template` files
- Configuration without secrets
- Documentation
- Scripts

### Migration Steps

If you have existing .yaml files with secrets:

1. **Backup your current .yaml files:**
   ```bash
   cp services/photoprism/kubernetes/04-photoprism.yaml ~/backup/
   ```

2. **The original .yaml files are now in .gitignore**, so they won't be committed anymore

3. **For git cleanup (if secrets were already committed):**
   ```bash
   # Check git history
   git log --all -- services/photoprism/kubernetes/04-photoprism.yaml

   # If secrets were committed, you may want to:
   # 1. Rotate all exposed secrets in Vault
   # 2. Consider using git-filter-repo to remove from history
   ```

### Verification

Check that your setup is secure:

```bash
# 1. Verify .gitignore is working
git status
# Should NOT show .yaml files in services/photoprism/kubernetes/

# 2. Check for secrets in staged files
pre-commit run --all-files

# 3. Search for unreplaced placeholders
grep -r 'VAULT_' services/photoprism/kubernetes/*.yaml
# Should return "No such file" or no results

# 4. Verify templates don't have real secrets
grep -r 'change-me\|changeme' services/photoprism/kubernetes/*.template
# Should only find placeholder text, not actual passwords
```

### Next Steps

1. ✅ Review and commit the new template files
2. ✅ Install pre-commit hooks: `./scripts/install-pre-commit.sh`
3. ✅ Setup local development: `./scripts/setup-local-dev.sh`
4. ⚠️  Rotate any secrets that may have been exposed
5. ⚠️  Consider cleaning git history if secrets were committed

### Support

- **Documentation:** docs/SECRET-MANAGEMENT.md
- **Local Dev:** `./scripts/setup-local-dev.sh`
- **Production:** `./scripts/deploy-with-vault.sh --help`
- **Pre-commit:** `./scripts/install-pre-commit.sh`

### Compliance

This implementation satisfies:
- ✅ MCP Policy (cluster/ai-ops-agent/config/mcp-policies.yaml)
- ✅ No secrets in version control
- ✅ Secrets encrypted at rest (Vault)
- ✅ Audit logging capability
- ✅ Secret rotation support
