# Secrets Management Guide

## Overview

This project follows a **template-based secrets management pattern** for infrastructure as code (IaC) and Kubernetes manifests. This ensures:

- ✅ No secrets committed to git
- ✅ Secrets stored in HashiCorp Vault
- ✅ Runtime secret injection during deployment
- ✅ Automated secret scanning with gitleaks

## Template Pattern

### How It Works

1. **Template Files** (`.template` suffix) are committed to git with placeholders
2. **Deployment Scripts** inject actual secrets from Vault at deployment time
3. **Generated Files** (without `.template`) are excluded from git via `.gitignore`

### Example

**Template file**: `services/photoprism/kubernetes/02-minio.yaml.template`
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: minio-credentials
  namespace: photoprism
type: Opaque
stringData:
  rootUser: "${VAULT_MINIO_ROOT_USER}"
  rootPassword: "${VAULT_MINIO_ROOT_PASSWORD}"
```

**Deployment**:
```bash
# Load secrets from Vault
export VAULT_MINIO_ROOT_USER=$(vault kv get -field=username secret/photoprism/minio)
export VAULT_MINIO_ROOT_PASSWORD=$(vault kv get -field=password secret/photoprism/minio)

# Generate manifest from template
envsubst < 02-minio.yaml.template > 02-minio.yaml

# Apply to cluster
kubectl apply -f 02-minio.yaml
```

## Secrets Storage Hierarchy

### Development Environment

```
Vault (KV v2 Secrets Engine)
└── secret/
    ├── photoprism/
    │   ├── minio         # MinIO credentials
    │   ├── mariadb       # Database credentials
    │   └── admin         # PhotoPrism admin
    ├── ai-ops-agent/
    │   └── postgres      # AI Ops database
    └── freeipa/
        ├── admin         # FreeIPA admin
        └── ds            # Directory Server
```

### Production Environment

Use cert-manager + external-secrets-operator to sync from Vault to Kubernetes secrets automatically.

## Secret Scanning

### Gitleaks Configuration

The project uses gitleaks with custom configuration (`.gitleaks.toml`) to detect secrets while minimizing false positives.

**Allowlisted patterns** (not secrets):
- Password generation code: `Password="$(openssl rand -base64 32)"`
- Environment variables: `${VAULT_TOKEN}`
- Ansible lookups: `{{ lookup('password', ...) }}`
- Template files: `*.template`, `*.md`, `*.example`

**Baseline** (`.gitleaksignore`):
- Historical findings already remediated in current code
- Files that have been converted to templates

### Running Locally

```bash
# Install gitleaks
wget https://github.com/gitleaks/gitleaks/releases/download/v8.21.2/gitleaks_8.21.2_linux_x64.tar.gz
tar -xzf gitleaks_8.21.2_linux_x64.tar.gz
sudo mv gitleaks /usr/local/bin/

# Scan repository
gitleaks detect --config .gitleaks.toml -v

# Scan without git history (current files only)
gitleaks detect --config .gitleaks.toml --no-git -v
```

### CI/CD Integration

GitHub Actions workflow (`.github/workflows/security-scan.yml`) runs gitleaks on:
- Every push to main/master
- Every pull request
- Daily scheduled scans (2 AM UTC)

Results appear in GitHub Security tab.

## Best Practices

### DO ✅

1. **Use templates for all manifests with secrets**
   - Add `.template` suffix to filename
   - Use `${VARIABLE_NAME}` placeholders
   - Commit templates to git

2. **Store secrets in Vault**
   ```bash
   vault kv put secret/myapp/db \
     username="dbuser" \
     password="$(openssl rand -base64 32)"
   ```

3. **Exclude generated files from git**
   - Add to `.gitignore`
   - Keep only `.template` versions in git

4. **Generate strong random passwords**
   ```bash
   openssl rand -base64 32  # 256-bit password
   ```

5. **Use Kubernetes secrets with Vault references**
   ```yaml
   valueFrom:
     secretKeyRef:
       name: my-secret
       key: password
   ```

### DON'T ❌

1. **Never commit hardcoded secrets**
   ```yaml
   # BAD
   password: "changeme123"

   # GOOD
   password: "${VAULT_DB_PASSWORD}"
   ```

2. **Never use placeholder passwords in production**
   - "changeme", "admin123", "password" are red flags
   - Always generate cryptographically secure passwords

3. **Never skip secret scanning**
   - Pre-commit hooks prevent secret commits
   - CI/CD workflows enforce scanning

4. **Never store secrets in environment variables** (except Kubernetes managed)
   - Use Vault API or Kubernetes secret references
   - Env vars can leak in logs/process listings

5. **Never share Vault tokens**
   - Each service gets its own Vault token
   - Rotate tokens regularly
   - Use short TTLs for tokens

## Vault Integration

### Kubernetes Service Account Auth

Production setup uses Kubernetes service account authentication:

```bash
# Enable Kubernetes auth
vault auth enable kubernetes

# Configure
vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token

# Create policy
vault policy write myapp-policy - <<EOF
path "secret/data/myapp/*" {
  capabilities = ["read"]
}
EOF

# Create role
vault write auth/kubernetes/role/myapp \
  bound_service_account_names=myapp \
  bound_service_account_namespaces=default \
  policies=myapp-policy \
  ttl=1h
```

### Cert-Manager Integration

Certificates are issued automatically via cert-manager + Vault PKI:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-service-cert
spec:
  secretName: my-service-tls
  duration: 720h        # 30 days
  renewBefore: 240h     # Renew at day 20
  issuerRef:
    name: vault-issuer-ai-ops
    kind: ClusterIssuer
  commonName: my-service.corp.local
```

See `cluster/foundation/cert-manager/` for full setup.

## Ansible Integration

### Password Generation

Ansible can generate and store passwords in Vault:

```yaml
- name: Generate database password
  set_fact:
    db_password: "{{ lookup('password', '/dev/null length=32 chars=ascii_letters,digits') }}"

- name: Store in Vault
  community.hashi_vault.vault_write:
    path: secret/myapp/db
    data:
      password: "{{ db_password }}"
```

### Reading from Vault

```yaml
- name: Read secret from Vault
  set_fact:
    db_password: "{{ lookup('community.hashi_vault.vault_read', 'secret/myapp/db').data.password }}"

- name: Use secret in deployment
  kubernetes.core.k8s:
    definition:
      apiVersion: v1
      kind: Secret
      stringData:
        password: "{{ db_password }}"
```

## Troubleshooting

### Gitleaks False Positives

If gitleaks flags legitimate code:

1. **Update allowlist in `.gitleaks.toml`**
   ```toml
   [rules.allowlist]
   regexes = [
       '''your-pattern-here''',
   ]
   ```

2. **Or add to baseline `.gitleaksignore`**
   ```
   commit-hash:file-path:rule-id:line-number
   ```

3. **Test locally before committing**
   ```bash
   gitleaks detect --config .gitleaks.toml -v
   ```

### Vault Connection Issues

```bash
# Check Vault status
vault status

# Test connectivity
kubectl exec -n vault vault-0 -- vault status

# Check service resolution
kubectl run -it test --image=busybox:1.36 --rm -- nslookup vault.vault.svc.cluster.local

# Verify cert-manager can reach Vault
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager
```

### Secret Not Found

```bash
# List secrets in path
vault kv list secret/myapp/

# Read specific secret
vault kv get secret/myapp/db

# Check permissions
vault token capabilities secret/myapp/db
```

## Security Compliance

### Governance Framework Alignment

Per `/home/suhlabs/projects/suhlabs/ai-agent-governance-framework/UNIFIED-AI-AGENT-GOVERNANCE-FRAMEWORK-v3.0.md`:

- ✅ **Section 10**: Secrets in approved stores (Vault, K8s Secrets with cert-manager)
- ✅ **Section 23**: No credential exposure to stdout
- ✅ **Section 8.2**: Secrets declared in orchestration manifests, not runtime
- ✅ **Section 20.1**: Environment variables managed by orchestration (not shell scripts)

### Audit Trail

All Vault operations are logged:

```bash
# Enable audit logging
vault audit enable file file_path=/vault/logs/audit.log

# Review audit log
kubectl exec -n vault vault-0 -- cat /vault/logs/audit.log | jq
```

## Migration from Hardcoded Secrets

If you find hardcoded secrets:

1. **Store in Vault**
   ```bash
   vault kv put secret/myapp/config api_key="actual-secret-value"
   ```

2. **Update manifest to template**
   ```bash
   mv myapp.yaml myapp.yaml.template
   # Replace hardcoded value with ${VAULT_MYAPP_API_KEY}
   ```

3. **Update deployment script**
   ```bash
   export VAULT_MYAPP_API_KEY=$(vault kv get -field=api_key secret/myapp/config)
   envsubst < myapp.yaml.template > myapp.yaml
   ```

4. **Add to .gitignore**
   ```
   myapp.yaml
   ```

5. **Remove from git history (if production secret)**
   ```bash
   # Use BFG Repo-Cleaner or git-filter-repo
   git filter-repo --path myapp.yaml --invert-paths
   ```

## References

- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
- [cert-manager Vault Integration](https://cert-manager.io/docs/configuration/vault/)
- [Gitleaks Configuration](https://github.com/gitleaks/gitleaks)
- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- Project Vault Setup: `cluster/foundation/vault-pki/README.md`
- Remediation Plan: `SECRETS-REMEDIATION-PLAN.md`

---

**Last Updated**: 2025-11-27
**Pattern**: Template-based with Vault integration
**Status**: ✅ Production-ready for aiops-substrate project
