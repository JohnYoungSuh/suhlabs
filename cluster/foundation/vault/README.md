# Vault Foundation Service

HashiCorp Vault deployment for secrets management and PKI (Public Key Infrastructure) for the AI Ops Substrate project.

## What This Provides

1. **Secrets Management** - Secure storage for sensitive data (API keys, passwords, certificates)
2. **PKI Engine** - Certificate Authority for issuing TLS certificates
3. **Dynamic Secrets** - Generate short-lived credentials on demand
4. **Encryption as a Service** - Encrypt/decrypt data without storing it

## Prerequisites

- Kubernetes cluster with kubectl access
- Helm 3.x installed
- CoreDNS deployed (for service discovery)
- Persistent storage provisioner (for Vault data)

## Quick Start

### Option 1: Automated Bootstrap (Recommended)

```bash
cd cluster/foundation/vault

# Deploy Vault
./deploy.sh

# Automated initialization and unsealing
./vault-bootstrap.sh auto

# Or use interactive menu
./vault-bootstrap.sh
```

The bootstrap script will:
- Initialize Vault and save keys/token to `.vault-keys.json`
- Automatically unseal Vault with saved keys
- Display root token for PKI setup

### Option 2: Manual Setup

```bash
cd cluster/foundation/vault

# Deploy Vault
./deploy.sh

# Initialize Vault (creates unseal keys and root token)
kubectl exec -n vault vault-0 -- vault operator init

# IMPORTANT: Save the output! You'll need:
# - 5 unseal keys (need 3 to unseal)
# - 1 root token (for admin access)

# Unseal Vault (use any 3 of the 5 keys)
kubectl exec -n vault vault-0 -- vault operator unseal <unseal-key-1>
kubectl exec -n vault vault-0 -- vault operator unseal <unseal-key-2>
kubectl exec -n vault vault-0 -- vault operator unseal <unseal-key-3>

# Verify Vault is unsealed
kubectl exec -n vault vault-0 -- vault status
```

### After Vault is Unsealed

```bash
# Initialize PKI (after unsealing)
cd ../vault-pki
export VAULT_TOKEN=<root-token-from-bootstrap>
./init-vault-pki.sh
```

## Deployment Architecture

### Standalone Mode (Default - Dev/Homelab)

```
┌─────────────────────────────────────┐
│ Vault Pod (vault-0)                │
│  - Single replica                   │
│  - File-based storage               │
│  - PersistentVolumeClaim (10Gi)     │
│  - UI enabled on :8200              │
└─────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│ Services                            │
│  - vault: 8200 (API)                │
│  - vault-ui: 8200 (Web UI)          │
│  - vault-internal: 8200 (headless)  │
└─────────────────────────────────────┘
```

## Vault Initialization

Vault starts in **sealed** state. You must initialize and unseal it before use.

### Initialization (Run Once)

```bash
kubectl exec -n vault vault-0 -- vault operator init
```

**Example Output:**
```
Unseal Key 1: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
Unseal Key 2: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
Unseal Key 3: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
Unseal Key 4: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
Unseal Key 5: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

Initial Root Token: hvs.xxxxxxxxxxxxxxxxxxxx

Vault initialized with 5 key shares and a key threshold of 3.
```

**CRITICAL:** Save these keys and token in a secure location:
- **Unseal Keys**: Required to unseal Vault after restart
- **Root Token**: Required for administrative operations

### Unsealing (Run After Every Restart)

Vault seals itself on restart for security. Unseal with 3 of 5 keys:

```bash
# Unseal with 3 keys (run each command separately)
kubectl exec -n vault vault-0 -- vault operator unseal <key-1>
kubectl exec -n vault vault-0 -- vault operator unseal <key-2>
kubectl exec -n vault vault-0 -- vault operator unseal <key-3>

# Check status
kubectl exec -n vault vault-0 -- vault status
```

**Status Output:**
```
Sealed: false         # ✅ Good - Vault is unsealed
Total Shares: 5
Threshold: 3
Unseal Progress: 0/3
```

### Auto-Unseal for Dev Environments

To avoid manual unsealing after every dev box restart, use the auto-unseal scripts:

**One-time setup:**
```bash
# After initializing Vault, save keys to Kubernetes secret
./save-keys-to-k8s.sh .vault-keys.json
```

**Auto-unseal after restarts:**
```bash
# Run this whenever your dev box restarts and Vault is sealed
./auto-unseal.sh
```

**Benefits:**
- ✅ Keys stored in Kubernetes (not in Git)
- ✅ One command to unseal
- ✅ No manual key entry
- ✅ Secure - keys never leave your cluster

**Note:** Keep a backup of `.vault-keys.json` in a secure location (password manager, encrypted drive, etc.). The `.gitignore` already excludes these files from Git.

## Bootstrap Script (vault-bootstrap.sh)

The `vault-bootstrap.sh` script automates initialization, unsealing, and sealing operations with secure key management.

### Features

- **Interactive Menu** - User-friendly menu for all operations
- **Automatic Key Storage** - Saves unseal keys and root token to `.vault-keys.json`
- **Auto Init+Unseal** - One command to initialize and unseal
- **Status Checking** - Quick status overview with token display
- **Seal/Unseal** - Easy seal/unseal operations

### Usage

**Interactive Menu:**
```bash
./vault-bootstrap.sh
```

**Command Line:**
```bash
# Initialize and unseal in one command
./vault-bootstrap.sh auto

# Individual commands
./vault-bootstrap.sh init      # Initialize Vault
./vault-bootstrap.sh unseal    # Unseal Vault
./vault-bootstrap.sh seal      # Seal Vault
./vault-bootstrap.sh status    # Show status
./vault-bootstrap.sh token     # Show root token
```

### Interactive Menu Options

```
1) Initialize Vault (first time setup)
2) Unseal Vault (unlock after restart)
3) Seal Vault (lock Vault)
4) Show Vault status
5) Show root token
6) Auto: Initialize + Unseal
7) Exit
```

### Keys File (.vault-keys.json)

The script stores unseal keys and root token in `.vault-keys.json`:

```json
{
  "unseal_keys_b64": [
    "key1...",
    "key2...",
    "key3...",
    "key4...",
    "key5..."
  ],
  "root_token": "hvs.xxxxx..."
}
```

**Security Notes:**
- File permissions set to `600` (owner read/write only)
- **DO NOT commit this file to git** (add to `.gitignore`)
- Backup this file securely
- For production, use HSM or cloud KMS instead

### Example: First Time Setup

```bash
# Deploy Vault
./deploy.sh

# Run automated bootstrap
./vault-bootstrap.sh auto
```

**Output:**
```
[INFO] Vault Bootstrap Script
[STEP] Initializing Vault...
[SUCCESS] ✅ Vault initialized successfully!

═══════════════════════════════════════════════════════════
                  VAULT CREDENTIALS
═══════════════════════════════════════════════════════════

Unseal Keys:
  Key 1: xxxxx...
  Key 2: xxxxx...
  Key 3: xxxxx...
  Key 4: xxxxx...
  Key 5: xxxxx...

Root Token: hvs.xxxxx...

═══════════════════════════════════════════════════════════

[STEP] Unsealing Vault...
[INFO] Using unseal key 1/3...
[INFO] Unseal progress: 1/3
[INFO] Using unseal key 2/3...
[INFO] Unseal progress: 2/3
[INFO] Using unseal key 3/3...
[INFO] Unseal progress: 3/3
[SUCCESS] ✅ Vault unsealed successfully!

[STEP] Checking Vault status...
[INFO] Initialized: ✅ Yes
[SUCCESS] Sealed: 🔓 No (Vault is ready)
[INFO] Root Token: hvs.xxxxx...
```

### Example: Unseal After Restart

```bash
# Vault automatically seals on pod restart
./vault-bootstrap.sh unseal
```

The script will automatically read keys from `.vault-keys.json` and unseal Vault.

## Accessing Vault

### Via kubectl exec

```bash
# Set root token for CLI access
export VAULT_TOKEN=<root-token>

# Execute Vault commands
kubectl exec -n vault vault-0 -- vault status
kubectl exec -n vault vault-0 -- vault secrets list
kubectl exec -n vault vault-0 -- vault auth list
```

### Via Web UI

```bash
# Port forward to access UI
kubectl port-forward -n vault svc/vault-ui 8200:8200
```

Then open: http://localhost:8200

Login with the root token from initialization.

### Via API

```bash
# Port forward for API access
kubectl port-forward -n vault svc/vault 8200:8200

# Example API call
export VAULT_TOKEN=<root-token>
curl -H "X-Vault-Token: $VAULT_TOKEN" http://localhost:8200/v1/sys/health
```

## PKI Configuration

After Vault is deployed and unsealed, configure the PKI engine:

```bash
cd cluster/foundation/vault-pki

# Set root token
export VAULT_TOKEN=<root-token-from-init>
export VAULT_ADDR=http://vault.vault.svc.cluster.local:8200

# Initialize PKI hierarchy (Root CA + Intermediate CA)
./init-vault-pki.sh

# Verify PKI setup
./verify-pki.sh
```

See [../vault-pki/README.md](../vault-pki/README.md) for detailed PKI documentation.

## Troubleshooting

### Vault Pod Not Starting

```bash
# Check pod status
kubectl get pods -n vault

# Check pod logs
kubectl logs -n vault vault-0

# Check events
kubectl describe pod vault-0 -n vault
```

Common issues:
- PersistentVolume not available
- Resource limits too low
- Port conflicts

### Vault is Sealed

```bash
# Check seal status
kubectl exec -n vault vault-0 -- vault status | grep Sealed

# If "Sealed: true", unseal with 3 keys
kubectl exec -n vault vault-0 -- vault operator unseal <key-1>
kubectl exec -n vault vault-0 -- vault operator unseal <key-2>
kubectl exec -n vault vault-0 -- vault operator unseal <key-3>
```

### Lost Unseal Keys or Root Token

If you lose unseal keys or root token:
- **Unseal Keys**: No recovery possible. Must destroy and reinitialize Vault
- **Root Token**: Generate new root token using unseal keys (advanced process)

Prevention: Store keys/token in:
1. Secure password manager
2. Encrypted file in secure location
3. Hardware security module (HSM) for production

### Can't Access Vault API

```bash
# Check service
kubectl get svc -n vault

# Check if Vault is unsealed
kubectl exec -n vault vault-0 -- vault status

# Test connectivity from inside cluster
kubectl run -it --rm debug --image=curlimages/curl -- \
  curl -v http://vault.vault.svc.cluster.local:8200/v1/sys/health
```

### PKI Initialization Fails

```bash
# Ensure Vault is unsealed
kubectl exec -n vault vault-0 -- vault status

# Verify VAULT_TOKEN is set
echo $VAULT_TOKEN

# Check Vault logs for errors
kubectl logs -n vault vault-0 | grep -i error

# Verify Vault connectivity
kubectl exec -n vault vault-0 -- vault status
```

## Security Best Practices

### Dev/Homelab Environment (Current Setup)

✅ **Acceptable:**
- TLS disabled (internal cluster traffic only)
- Single replica (not HA)
- Root token for initial setup
- File-based storage

⚠️ **Recommended:**
- Store unseal keys in encrypted password manager
- Rotate root token after creating admin policies
- Enable audit logging
- Regular backups of /vault/data PVC

### Production Environment (Future)

For production, upgrade to:
1. **HA Mode**: 3+ replicas with Raft storage
2. **TLS Enabled**: All communication encrypted
3. **Auto-Unseal**: Using cloud KMS or HSM
4. **RBAC**: Role-based access control, no root token
5. **Audit Logging**: All operations logged
6. **Backup/DR**: Regular snapshots and disaster recovery plan

## Integration with Other Services

### Cert-Manager (Day 5)

Cert-manager will use Vault PKI to issue certificates:

```yaml
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: vault-issuer
spec:
  vault:
    server: http://vault.vault.svc.cluster.local:8200
    path: pki_int/sign/kubernetes
    auth:
      kubernetes:
        role: cert-manager
```

### AI Ops Agent

Will use Vault for:
- API key storage
- TLS certificate management
- Dynamic database credentials

## Resource Usage

**Current Limits (Dev/Homelab):**
```yaml
resources:
  requests:
    cpu: 250m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

**Storage:**
- PersistentVolumeClaim: 10Gi
- Backend: File storage at /vault/data

**For Production:**
- Increase CPU to 1000m/2000m
- Increase memory to 1Gi/2Gi
- Consider SSD storage for better performance

## Monitoring

### Health Checks

```bash
# System health
kubectl exec -n vault vault-0 -- vault status

# Seal status
kubectl exec -n vault vault-0 -- vault operator unseal -status

# Check if ready to serve requests
curl http://localhost:8200/v1/sys/health
```

**Health Endpoint Responses:**
- `200`: Unsealed and ready
- `429`: Unsealed and standby (in HA mode)
- `472`: Disaster recovery mode
- `473`: Performance standby
- `501`: Not initialized
- `503`: Sealed

### Prometheus Metrics

Vault exposes Prometheus metrics at `:8200/v1/sys/metrics`

Enable ServiceMonitor when Prometheus is deployed:

```yaml
# values.yaml
serverTelemetry:
  serviceMonitor:
    enabled: true
```

## Backup and Recovery

### Backup Vault Data

```bash
# Option 1: Snapshot (recommended)
kubectl exec -n vault vault-0 -- vault operator raft snapshot save backup.snap

# Option 2: PVC backup
kubectl get pvc -n vault
# Then backup the PVC using your backup solution
```

### Restore from Backup

```bash
# Restore from snapshot
kubectl exec -n vault vault-0 -- vault operator raft snapshot restore backup.snap
```

## Upgrading Vault

```bash
# Update image version in values.yaml
# server:
#   image:
#     tag: "1.21.0"  # New version

# Apply upgrade
helm upgrade vault hashicorp/vault \
  -n vault \
  -f values.yaml \
  --wait

# Vault will restart and seal itself
# Unseal with 3 keys after upgrade
```

## Next Steps

After Vault is deployed and PKI configured:

1. **Deploy cert-manager** (Day 5)
2. **Create ClusterIssuer** pointing to Vault PKI
3. **Test certificate issuance** for ingress
4. **Deploy AI Ops Agent** with Vault integration

## Learning Outcomes

By deploying Vault, you learn:

- ✅ HashiCorp Vault architecture
- ✅ Seal/unseal concepts
- ✅ PKI and certificate management
- ✅ Secrets management best practices
- ✅ Kubernetes StatefulSet patterns

## Reference

- [Vault Documentation](https://www.vaultproject.io/docs)
- [Vault Helm Chart](https://github.com/hashicorp/vault-helm)
- [Vault PKI Secrets Engine](https://www.vaultproject.io/docs/secrets/pki)
- [Vault Kubernetes Auth](https://www.vaultproject.io/docs/auth/kubernetes)

---

**Status**: Foundation service for Day 4 (Hour 2-3)
