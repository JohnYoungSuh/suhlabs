# Secret Management Guide

This document describes how to securely manage secrets in the suhlabs infrastructure.

## Overview

We use a **template-based approach** to prevent secrets from being committed to git:

- **`.yaml.template` files** → Committed to git (contain placeholders)
- **`.yaml` files** → Local only, in .gitignore (contain real secrets)
- **Vault** → Production secrets storage

## Quick Start

### For Local Development

1. **Create local working files from templates:**
   ```bash
   ./scripts/setup-local-dev.sh
   ```

2. **Edit the generated `.yaml` files** (not `.template` files) and replace placeholders:
   ```bash
   # Example: services/photoprism/kubernetes/04-photoprism.yaml
   # Change this:
   PHOTOPRISM_ADMIN_PASSWORD: "${VAULT_PHOTOPRISM_ADMIN_PASSWORD}"

   # To this (for local dev):
   PHOTOPRISM_ADMIN_PASSWORD: "my-local-dev-password"
   ```

3. **Deploy locally:**
   ```bash
   kubectl apply -f services/photoprism/kubernetes/
   ```

### For Production (Using Vault)

1. **Authenticate to Vault:**
   ```bash
   export VAULT_ADDR=https://vault.suhlabs.internal:8200
   vault login
   ```

2. **Initialize secrets (first time only):**
   ```bash
   ./scripts/deploy-with-vault.sh --init services/photoprism/kubernetes
   ```

3. **Deploy with Vault secrets:**
   ```bash
   ./scripts/deploy-with-vault.sh services/photoprism/kubernetes
   ```

## File Structure

```
services/photoprism/kubernetes/
├── 00-namespace.yaml              # No secrets, committed to git
├── 01-storage.yaml                # No secrets, committed to git
├── 02-minio.yaml                  # LOCAL ONLY - in .gitignore
├── 02-minio.yaml.template         # Committed to git
├── 03-mariadb.yaml                # LOCAL ONLY - in .gitignore
├── 03-mariadb.yaml.template       # Committed to git
├── 04-photoprism.yaml             # LOCAL ONLY - in .gitignore
├── 04-photoprism.yaml.template    # Committed to git
├── 06-authelia.yaml               # LOCAL ONLY - in .gitignore
└── 06-authelia.yaml.template      # Committed to git
```

## Vault Secret Structure

Secrets are organized in Vault as follows:

```
secret/photoprism/
├── minio
│   ├── rootUser
│   └── rootPassword
├── mariadb
│   ├── rootPassword
│   └── password
├── app
│   ├── adminPassword
│   ├── databasePassword
│   ├── s3AccessKey
│   └── s3SecretKey
└── authelia
    ├── jwtSecret
    ├── sessionSecret
    ├── encryptionKey
    ├── smtpPassword
    └── adminPasswordHash
```

## Managing Vault Secrets

### View Secrets

```bash
# View all secrets for a path
vault kv get secret/photoprism/minio

# Get a specific field
vault kv get -field=rootPassword secret/photoprism/minio
```

### Update Secrets

```bash
# Update a single field
vault kv patch secret/photoprism/minio rootPassword="new-password"

# Update entire secret
vault kv put secret/photoprism/minio \
    rootUser="minioadmin" \
    rootPassword="new-password"
```

### Rotate Secrets

```bash
# 1. Update in Vault
vault kv patch secret/photoprism/minio rootPassword="$(openssl rand -base64 32)"

# 2. Redeploy
./scripts/deploy-with-vault.sh services/photoprism/kubernetes

# 3. Verify
kubectl rollout status deployment/minio -n photoprism
```

## Security Best Practices

### ✅ DO

- ✅ Commit `.yaml.template` files to git
- ✅ Use Vault for production secrets
- ✅ Use strong, randomly generated passwords
- ✅ Rotate secrets regularly
- ✅ Use different secrets for each environment
- ✅ Review changes before committing

### ❌ DON'T

- ❌ Commit `.yaml` files with real secrets
- ❌ Use default passwords like "changeme"
- ❌ Share secrets in Slack/email
- ❌ Reuse passwords across services
- ❌ Store secrets in environment variables permanently
- ❌ Commit files with "TODO: change this password"

## Git Pre-Commit Protection

We use git pre-commit hooks to prevent accidental secret commits:

```bash
# Install pre-commit hooks
pip install pre-commit
pre-commit install

# This will automatically scan for:
# - API keys and tokens
# - Private keys
# - Passwords in plaintext
# - Certificate files
```

## Troubleshooting

### "I accidentally committed a secret!"

1. **DO NOT** just delete it in the next commit - it's still in git history!

2. **Remove from git history:**
   ```bash
   # Use git-filter-repo (recommended)
   pip install git-filter-repo
   git-filter-repo --invert-paths --path services/photoprism/kubernetes/04-photoprism.yaml

   # Force push (WARNING: coordinate with team)
   git push --force
   ```

3. **Rotate the exposed secret immediately:**
   ```bash
   vault kv patch secret/photoprism/app adminPassword="$(openssl rand -base64 32)"
   ./scripts/deploy-with-vault.sh services/photoprism/kubernetes
   ```

### "My local deployment isn't working"

Check that you've replaced all placeholders:

```bash
# Search for unreplaced placeholders
grep -r 'VAULT_' services/photoprism/kubernetes/*.yaml

# Should return no results if all placeholders are replaced
```

### "I need to generate a password hash for Authelia"

```bash
# Run authelia in a container to generate hash
docker run --rm authelia/authelia:latest authelia hash-password 'your-password'

# Copy the output to your .yaml file or Vault
```

## Compliance

This secret management approach satisfies:

- **MCP Policy** (cluster/ai-ops-agent/config/mcp-policies.yaml)
  - ✅ secrets_encryption: enabled
  - ✅ "Secrets must be stored in Vault, not plain text"

- **Security Standards**
  - ✅ No secrets in version control
  - ✅ Secrets encrypted at rest (Vault)
  - ✅ Secrets encrypted in transit (TLS)
  - ✅ Audit logging (Vault audit backend)

## Additional Resources

- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [External Secrets Operator](https://external-secrets.io/) (alternative approach)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) (GitOps-friendly alternative)

## Support

For questions or issues:

1. Check this documentation
2. Review `scripts/deploy-with-vault.sh --help`
3. Check AI Ops Agent logs: `kubectl logs -n ai-ops-agent deployment/ai-ops-agent`
