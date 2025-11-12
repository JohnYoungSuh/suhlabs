# Vault PKI Engine Configuration

Complete PKI (Public Key Infrastructure) setup for corp.local with Root CA + Intermediate CA hierarchy.

## What This Provides

**Complete Certificate Authority (CA) Infrastructure:**
- Root CA (trust anchor)
- Intermediate CA (issues service certificates)
- PKI roles for different services
- Automatic certificate issuance via Vault API
- Foundation for cert-manager integration (Day 5)

## Quick Start

```bash
cd cluster/foundation/vault-pki

# Prerequisites:
# 1. Vault must be running and unsealed
# 2. You must have root token or sufficient permissions

# Set Vault address and token
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=<your-root-token>

# Initialize PKI
./init-vault-pki.sh

# Verify setup
./verify-pki.sh
```

## Architecture

### The Certificate Hierarchy

```
Root CA: "corp.local Root CA"
├─ Lifetime: 10 years (87600h)
├─ Key Size: 4096 bits RSA
├─ Purpose: Sign intermediate CAs only
└─ Storage: Vault PKI engine (pki/)

    └─ Intermediate CA: "kubernetes.corp.local Intermediate CA"
        ├─ Lifetime: 5 years (43800h)
        ├─ Key Size: 4096 bits RSA
        ├─ Purpose: Issue service certificates
        ├─ Storage: Vault PKI engine (pki_int/)
        └─ Signed by: Root CA

            ├─ Role: "ai-ops-agent"
            │   ├─ Domains: *.corp.local, *.cluster.local
            │   ├─ Max TTL: 30 days (720h)
            │   └─ Purpose: AI Ops services
            │
            ├─ Role: "kubernetes"
            │   ├─ Domains: *.svc.cluster.local
            │   ├─ Max TTL: 90 days (2160h)
            │   └─ Purpose: General K8s services
            │
            └─ Role: "cert-manager"
                ├─ Domains: *.cluster.local, *.corp.local
                ├─ Max TTL: 90 days (2160h)
                └─ Purpose: Cert-manager automation
```

### Why This Structure?

**Root CA Offline (Production):**
- Used ONCE to sign intermediate
- Then disconnected and secured
- If compromised = entire PKI destroyed
- Replacement = re-issue ALL certificates

**Intermediate CA Online:**
- Issues certificates 24/7
- If compromised = revoke + issue new intermediate
- Services get new certs automatically (cert-manager)
- Downtime = hours, not days

**Short Certificate Lifetimes:**
- 30 days = Force automation (good habit)
- Compromised cert only valid for 30 days max
- Auto-renewal via cert-manager (Day 5)

## PKI Roles Explained

### Role: ai-ops-agent

**Purpose:** Certificates for AI Ops Agent and related services

**Configuration:**
```hcl
allowed_domains = ["corp.local", "cluster.local"]
allow_subdomains = true
max_ttl = 720h  # 30 days
```

**Example Usage:**
```bash
# Issue certificate
vault write pki_int/issue/ai-ops-agent \
  common_name="ai-ops.corp.local" \
  ttl="720h"

# Or via cert-manager
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ai-ops-agent-tls
spec:
  issuerRef:
    name: vault-issuer
    kind: ClusterIssuer
  secretName: ai-ops-agent-tls
  commonName: ai-ops.corp.local
```

### Role: kubernetes

**Purpose:** General Kubernetes services

**Configuration:**
```hcl
allowed_domains = ["svc.cluster.local"]
allow_subdomains = true
max_ttl = 2160h  # 90 days
```

**Example:**
```bash
vault write pki_int/issue/kubernetes \
  common_name="my-service.default.svc.cluster.local" \
  ttl="2160h"
```

### Role: cert-manager

**Purpose:** Cert-manager to automate certificate issuance for ANY service

**Configuration:**
```hcl
allowed_domains = ["cluster.local", "corp.local"]
allow_subdomains = true
allow_glob_domains = true
max_ttl = 2160h  # 90 days
```

**Why Broader Permissions?**
- Cert-manager issues certs for all services
- Needs permission for any valid domain
- Still restricted to cluster.local and corp.local

## Certificate Lifecycle

### 1. Issuance

**Manual (Testing):**
```bash
vault write pki_int/issue/ai-ops-agent \
  common_name="test.corp.local" \
  ttl="24h"
```

**Automated (Production):**
```yaml
# Cert-manager Certificate resource
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-service-tls
spec:
  secretName: my-service-tls
  duration: 720h        # 30 days
  renewBefore: 240h     # Renew 10 days before expiry
  issuerRef:
    name: vault-issuer
    kind: ClusterIssuer
  commonName: my-service.corp.local
```

### 2. Renewal

**Automatic (Cert-Manager):**
- Checks certificates every hour
- Renews when `renewBefore` threshold reached
- Updates Kubernetes secret automatically
- Applications pick up new cert (if configured to reload)

**Manual (Emergency):**
```bash
# Revoke old certificate
vault write pki_int/revoke serial_number=<serial>

# Issue new certificate
vault write pki_int/issue/ai-ops-agent \
  common_name="test.corp.local" \
  ttl="24h"
```

### 3. Revocation

**Revoke Single Certificate:**
```bash
# Get serial number
openssl x509 -in cert.pem -noout -serial

# Revoke
vault write pki_int/revoke serial_number=<serial>

# CRL is automatically updated
```

**Revoke Intermediate CA (Nuclear Option):**
```bash
# Use root CA to revoke intermediate
vault write pki/revoke \
  serial_number=<intermediate-serial>

# All certificates issued by this intermediate are now invalid!
# Issue new intermediate and re-issue all certs
```

## Production vs Development

### Development Setup (Current)

```
Root CA: Online in Vault
├─ Convenience: Easy testing
├─ Security: ⭐☆☆☆☆
└─ Use case: Learning, local dev

Intermediate CA: Online in Vault
├─ Sealed with: SoftHSM
├─ Security: ⭐⭐☆☆☆
└─ Use case: Development, testing
```

### Production Setup (Future)

```
Root CA: Offline in Safe
├─ Hardware: YubiHSM 2 on air-gapped laptop
├─ Access: Dual control, physical security
├─ Security: ⭐⭐⭐⭐⭐
└─ Used: Once per year (if that)

Intermediate CA: Online in Vault
├─ Sealed with: YubiHSM 2 cluster
├─ Security: ⭐⭐⭐⭐☆
└─ Issues: Thousands of certs per day
```

### The Offline Ceremony (Production)

**When:** Need to sign new intermediate CA (every 5 years, or if compromised)

**Process:**
```
┌─────────────────────────────────────────────┐
│ ROOT CA SIGNING CEREMONY                    │
├─────────────────────────────────────────────┤
│ Time: 2-4 hours                             │
│ People: 2 (dual control)                    │
│ Location: Secure facility                   │
└─────────────────────────────────────────────┘

1. Schedule ceremony (1 week notice)
2. Security team prepares secure room
3. Two authorized personnel enter
4. Boot air-gapped laptop (never been online)
5. Connect YubiHSM containing root CA key
6. Insert USB with intermediate CA CSR
7. Verify CSR integrity (checksums)
8. Sign CSR with root CA:
   vault write pki/root/sign-intermediate \
     csr=@intermediate.csr \
     ttl=43800h
9. Save signed certificate to USB
10. Verify signature
11. Disconnect YubiHSM
12. Lock YubiHSM in safe
13. Shut down laptop
14. Exit secure room
15. Deliver signed cert to ops team
16. Log all actions

Cost: ~$2000 (personnel time + facility)
Frequency: Every 5 years (or emergency)
```

## Troubleshooting

### Certificate Not Issuing

```bash
# Check role permissions
vault read pki_int/roles/ai-ops-agent

# Check role allows the domain
# allowed_domains should include your domain

# Try manual issuance
vault write pki_int/issue/ai-ops-agent \
  common_name="test.corp.local" \
  ttl="1h"

# Check Vault logs
kubectl logs -n vault deploy/vault
```

### Chain Verification Failed

```bash
# Get full chain
vault read -field=certificate pki/cert/ca > root.pem
vault read -field=certificate pki_int/cert/ca > intermediate.pem
cat intermediate.pem root.pem > chain.pem

# Verify leaf cert
openssl verify -CAfile chain.pem leaf.cert.pem

# Common issues:
# - Intermediate not signed by root
# - Wrong CA bundle (missing root or intermediate)
# - Certificate issued before intermediate was signed
```

### CRL Not Updating

```bash
# Check CRL config
vault read pki_int/config/crl

# Manually trigger CRL generation
vault write pki_int/config/crl expiry=72h

# Fetch CRL
curl $VAULT_ADDR/v1/pki_int/crl | openssl crl -inform DER -text
```

### Role Permissions Too Restrictive

```bash
# Update role
vault write pki_int/roles/ai-ops-agent \
  allowed_domains="corp.local,cluster.local,example.com" \
  allow_subdomains=true \
  max_ttl="720h"

# Test
vault write pki_int/issue/ai-ops-agent \
  common_name="test.example.com" \
  ttl="1h"
```

## Security Best Practices

### 1. Short Certificate Lifetimes

✅ **Good:**
```
Service certs: 30 days
Intermediate CA: 5 years
Root CA: 10 years
```

❌ **Bad:**
```
Service certs: 10 years
Intermediate CA: forever
Root CA: forever
```

**Why:** Shorter lifetimes limit blast radius of compromise.

### 2. Role-Based Access Control

✅ **Good:**
```
ai-ops-agent role: Only *.corp.local
kubernetes role: Only *.svc.cluster.local
cert-manager role: *.cluster.local (needs broad access)
```

❌ **Bad:**
```
One role for everything with allow_any_name=true
```

**Why:** Principle of least privilege.

### 3. Audit Everything

```bash
# Enable audit logging in Vault
vault audit enable file file_path=/vault/logs/audit.log

# Monitor certificate issuance
tail -f /vault/logs/audit.log | grep pki_int/issue

# Alert on suspicious patterns
# - High volume of issuance
# - Unusual domains
# - After-hours access
```

### 4. Regular Key Rotation

**Recommended Schedule:**
- Root CA: 10 years (rarely rotated)
- Intermediate CA: 5 years
- Service certs: 30 days (auto-rotated)

**Rotation Process:**
```bash
# Generate new intermediate
vault write pki_int/intermediate/generate/internal \
  common_name="New Intermediate CA"

# Sign with root (offline ceremony)
vault write pki/root/sign-intermediate csr=@new.csr

# Import signed cert
vault write pki_int/intermediate/set-signed \
  certificate=@new_intermediate.pem

# Old intermediate still valid until expiry
# Cert-manager will start using new intermediate for renewals
```

## Files Generated

After running `init-vault-pki.sh`:

```
cluster/foundation/vault-pki/
├── root_ca.crt              # Root CA certificate
├── intermediate.cert.pem    # Intermediate CA certificate
├── ca_bundle.pem            # Full chain (intermediate + root)
├── pki_intermediate.csr     # Intermediate CSR (historical)
├── test_cert.pem            # Test certificate
├── test_cert.key            # Test private key
└── cert-manager-policy.hcl  # Vault policy
```

**Import to OS Trust Store:**
```bash
# macOS
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain root_ca.crt

# Linux (Ubuntu/Debian)
sudo cp root_ca.crt /usr/local/share/ca-certificates/corp-local-root.crt
sudo update-ca-certificates

# Linux (RHEL/CentOS)
sudo cp root_ca.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust
```

## Integration with Cert-Manager (Day 5)

**Preview of what's coming:**

```yaml
# ClusterIssuer pointing to Vault PKI
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: vault-issuer
spec:
  vault:
    server: http://vault.vault.svc:8200
    path: pki_int/sign/cert-manager
    caBundle: <base64-encoded-ca-bundle>
    auth:
      kubernetes:
        role: cert-manager
        mountPath: /v1/auth/kubernetes
        secretRef:
          name: cert-manager-vault-token
          key: token
```

After cert-manager is configured, services automatically get certificates:

```yaml
# Just add this annotation to your service
apiVersion: v1
kind: Service
metadata:
  annotations:
    cert-manager.io/cluster-issuer: vault-issuer
```

No manual certificate management!

## Learning Outcomes

By setting up Vault PKI, you learn:

- ✅ PKI hierarchy (root → intermediate → leaf)
- ✅ Certificate lifetimes and rotation
- ✅ Role-based certificate issuance
- ✅ Vault PKI engine configuration
- ✅ Certificate chain verification
- ✅ CRL (Certificate Revocation List)
- ✅ Production vs development PKI
- ✅ HSM integration concepts

## Next Steps

1. **Verify PKI is working**: `./verify-pki.sh`
2. **Import root CA to your OS trust store** (for local testing)
3. **Day 5**: Deploy cert-manager
4. **Day 5**: Configure cert-manager to use Vault PKI
5. **Day 5+**: Services get certificates automatically!

## Reference

- [Vault PKI Secrets Engine](https://developer.hashicorp.com/vault/docs/secrets/pki)
- [PKI Best Practices](https://developer.hashicorp.com/vault/tutorials/secrets-management/pki-engine)
- [Cert-Manager Vault Integration](https://cert-manager.io/docs/configuration/vault/)
- [Certificate Lifetimes (Let's Encrypt)](https://letsencrypt.org/2015/11/09/why-90-days.html)

---

**Status**: Foundation service for Day 4 (Hour 3)
**Prerequisites**: Vault deployed with SoftHSM (Hour 2)
**Next**: Hour 4 - Verification and documentation
