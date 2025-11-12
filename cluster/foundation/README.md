# Foundation Services

Complete foundation infrastructure for the AI Ops Substrate project.

## Overview

This directory contains Day 4 foundation services that provide DNS, certificate management, and security infrastructure for the entire cluster.

**The Three Pillars:**

1. **CoreDNS** - Service discovery and custom DNS zones
2. **SoftHSM** - Hardware security module (development)
3. **Vault PKI** - Complete certificate authority infrastructure

## Quick Start

```bash
cd cluster/foundation

# Verify all services
./verify-all.sh

# Or verify individually:
cd coredns && ./deploy.sh
cd softhsm && ./init-softhsm.sh
cd vault-pki && ./init-vault-pki.sh && ./verify-pki.sh
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Foundation Layer                      │
│                  (Day 4 Infrastructure)                 │
└─────────────────────────────────────────────────────────┘
     │                  │                  │
     ▼                  ▼                  ▼
┌─────────┐      ┌──────────┐      ┌─────────────┐
│ CoreDNS │      │ SoftHSM  │      │  Vault PKI  │
│         │      │          │      │             │
│ • K8s   │      │ • PKCS11 │      │ • Root CA   │
│   DNS   │◄─────┤ • Vault  │◄─────┤ • Int CA    │
│ • corp. │      │   Seal   │      │ • Roles     │
│   local │      │ • Dev    │      │ • Auto      │
│         │      │   Only   │      │   Renewal   │
└─────────┘      └──────────┘      └─────────────┘
     │                                     │
     ▼                                     ▼
┌────────────────────────────────────────────────┐
│          Application Services                   │
│   (cert-manager, AI Ops Agent, etc.)           │
└────────────────────────────────────────────────┘
```

## Why These Three?

### CoreDNS: The Address Book

**What it does:**
- Resolves service names to IP addresses
- Enables Kubernetes service discovery
- Provides custom corp.local zone

**Why it's essential:**
- Services need to find each other by name
- Vault accessible at `vault.corp.local`
- Cert-manager needs to resolve Vault service

**Real-world analogy:** Like DNS servers that turn google.com into an IP address, CoreDNS turns `vault.vault.svc.cluster.local` into the actual Vault service IP.

### SoftHSM: The Key Vault (Development)

**What it does:**
- Stores cryptographic keys securely
- Provides PKCS#11 interface for Vault
- Enables auto-unseal for Vault

**Why it's essential:**
- Vault master key needs secure storage
- Auto-unseal eliminates manual intervention
- Prevents keys from being stored in plaintext

**Real-world analogy:** Like a safe deposit box at a bank. You don't keep the master key for your company's secrets in a text file on the server!

**Development vs Production:**
- Development: SoftHSM (software, on same machine)
- Production: YubiHSM 2 (hardware, dedicated device)

### Vault PKI: The Certificate Authority

**What it does:**
- Issues SSL/TLS certificates
- Manages certificate lifecycle (issue, renew, revoke)
- Provides Root CA + Intermediate CA hierarchy

**Why it's essential:**
- Services need certificates for HTTPS
- Cert-manager automates certificate issuance
- Establishes trust between services

**Real-world analogy:** Like a passport office. Services need certificates (passports) to prove their identity when communicating with each other.

## Service Dependencies

```
Deployment Order:
1. CoreDNS       (no dependencies)
2. SoftHSM       (no dependencies)
3. Vault         (needs SoftHSM)
4. Vault PKI     (needs Vault)
5. Cert-Manager  (needs CoreDNS + Vault PKI)
```

**Why this order matters:**

- **CoreDNS first**: Other services need DNS to find each other
- **SoftHSM before Vault**: Vault needs HSM for auto-unseal
- **Vault PKI after Vault**: Can't configure PKI without Vault running
- **Cert-Manager last**: Needs both DNS and PKI to work

## Service Details

### CoreDNS

**Location:** `coredns/`

**Key Features:**
- Standard Kubernetes DNS (cluster.local)
- Custom DNS zone (corp.local)
- Upstream forwarding for external DNS
- CNAMEs for service aliases

**Configuration:**
```yaml
# values.yaml
servers:
  - zones:
      - zone: cluster.local
      - zone: corp.local
    plugins:
      - name: kubernetes
      - name: file
        parameters: corp.local
```

**DNS Records:**
```
ns1.corp.local      → 10.96.0.10 (CoreDNS)
vault.corp.local    → CNAME vault.vault.svc.cluster.local
ai-ops.corp.local   → CNAME ai-ops-agent.ai-ops.svc.cluster.local
*.corp.local        → 10.0.1.100 (Wildcard)
```

**Testing:**
```bash
# Test cluster.local
kubectl run -it test --image=busybox:1.36 --rm --restart=Never -- \
  nslookup kubernetes.default.svc.cluster.local

# Test corp.local
kubectl run -it test --image=busybox:1.36 --rm --restart=Never -- \
  nslookup vault.corp.local
```

### SoftHSM

**Location:** `softhsm/`

**Key Features:**
- PKCS#11 interface for Vault
- Software-based HSM (development)
- Token initialization for Vault
- Persistence via PersistentVolumes

**Configuration:**
```yaml
# vault-deployment.yaml
seal "pkcs11" {
  lib = "/usr/lib/softhsm/libsofthsm2.so"
  slot = "0"
  pin = "1234"
  key_label = "vault-root-key"
  generate_key = "true"
}
```

**Security Note:**
⚠️ SoftHSM is for DEVELOPMENT ONLY
- Keys stored in software
- Same machine as Vault
- No physical security

For production, use YubiHSM 2 or AWS CloudHSM.

### Vault PKI

**Location:** `vault-pki/`

**Key Features:**
- Root CA (10 year lifetime)
- Intermediate CA (5 year lifetime)
- Three PKI roles:
  - `ai-ops-agent`: 30 day certs
  - `kubernetes`: 90 day certs
  - `cert-manager`: 90 day certs
- Automatic certificate issuance
- CRL (Certificate Revocation List)

**PKI Hierarchy:**
```
Root CA (10y, 4096-bit RSA)
├─ Offline in production
└─ Signs intermediate CAs only

    └─ Intermediate CA (5y, 4096-bit RSA)
        ├─ Online 24/7
        └─ Issues service certificates

            ├─ ai-ops-agent (30d max TTL)
            ├─ kubernetes (90d max TTL)
            └─ cert-manager (90d max TTL)
```

**Certificate Issuance:**
```bash
# Manual (testing)
vault write pki_int/issue/ai-ops-agent \
  common_name="test.corp.local" \
  ttl="24h"

# Automated (production via cert-manager)
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-service-tls
spec:
  secretName: my-service-tls
  duration: 720h  # 30 days
  renewBefore: 240h  # Renew 10 days early
  issuerRef:
    name: vault-issuer
    kind: ClusterIssuer
  commonName: my-service.corp.local
```

## Verification

### Automated Verification

Run the master verification script:

```bash
./verify-all.sh
```

This runs 7 test suites:
1. Prerequisites check
2. CoreDNS verification
3. Vault + SoftHSM verification
4. Vault PKI verification
5. Integration testing
6. Security checks
7. Performance checks

### Manual Verification

**CoreDNS:**
```bash
cd coredns
kubectl get pods -n kube-system -l k8s-app=coredns
kubectl logs -n kube-system -l k8s-app=coredns
```

**Vault:**
```bash
kubectl get pods -n vault
kubectl exec -n vault vault-0 -- vault status
```

**SoftHSM:**
```bash
kubectl exec -n vault vault-0 -- softhsm2-util --show-slots
```

**Vault PKI:**
```bash
cd vault-pki
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=<your-root-token>
./verify-pki.sh
```

## Integration Testing

### DNS → Vault

Test that CoreDNS can resolve Vault service:

```bash
kubectl run -it test --image=busybox:1.36 --rm --restart=Never -- \
  nslookup vault.vault.svc.cluster.local

# Should show:
# Address 1: 10.96.x.x vault.vault.svc.cluster.local
```

### Vault → SoftHSM

Check Vault is using PKCS#11 seal:

```bash
kubectl exec -n vault vault-0 -- vault status

# Look for:
# Seal Type: pkcs11
```

### Vault PKI → CoreDNS

Issue a certificate with DNS name:

```bash
vault write pki_int/issue/ai-ops-agent \
  common_name="ai-ops.corp.local" \
  ttl="24h"

# Verify DNS can resolve the name
kubectl run -it test --image=busybox:1.36 --rm --restart=Never -- \
  nslookup ai-ops.corp.local
```

## Troubleshooting

### CoreDNS Issues

**Pods not starting:**
```bash
kubectl describe pod -n kube-system -l k8s-app=coredns
# Common issues:
# - Port 53 already in use
# - Invalid zone file syntax
# - Resource limits too low
```

**DNS not resolving:**
```bash
# Check CoreDNS config
kubectl get configmap coredns -n kube-system -o yaml

# Test from inside pod
kubectl run -it debug --image=busybox:1.36 --rm --restart=Never -- sh
cat /etc/resolv.conf
nslookup kubernetes.default
```

### Vault Issues

**Vault sealed:**
```bash
kubectl exec -n vault vault-0 -- vault status
# If sealed=true:

# Option 1: Unseal with keys
kubectl exec -n vault vault-0 -- vault operator unseal <key1>
kubectl exec -n vault vault-0 -- vault operator unseal <key2>
kubectl exec -n vault vault-0 -- vault operator unseal <key3>

# Option 2: Check SoftHSM auto-unseal
kubectl logs -n vault vault-0
# Look for PKCS#11 errors
```

**SoftHSM token missing:**
```bash
kubectl exec -n vault vault-0 -- softhsm2-util --show-slots
# Should show "vault-hsm" token

# If missing, reinitialize:
cd softhsm
./init-softhsm.sh
```

### PKI Issues

**Certificate issuance failing:**
```bash
# Check role permissions
vault read pki_int/roles/ai-ops-agent

# Check domain is allowed
# allowed_domains should include your domain

# Try manual issuance with debug
vault write -verbose pki_int/issue/ai-ops-agent \
  common_name="test.corp.local" \
  ttl="1h"
```

**Chain verification failed:**
```bash
# Get full chain
vault read -field=certificate pki/cert/ca > root.pem
vault read -field=certificate pki_int/cert/ca > intermediate.pem
cat intermediate.pem root.pem > chain.pem

# Verify leaf cert
openssl verify -CAfile chain.pem leaf.cert.pem
```

## Security Considerations

### Development vs Production

**Development Setup (Current):**
```
✅ Good for learning and testing
✅ Easy to reset and experiment
⚠️ SoftHSM = software keys (not secure)
⚠️ Root CA online (should be offline)
⚠️ Simple passwords/PINs
⚠️ No audit logging
```

**Production Requirements:**
```
✓ YubiHSM 2 or AWS CloudHSM
✓ Root CA offline (air-gapped)
✓ Strong passwords (16+ chars, random)
✓ Comprehensive audit logging
✓ Dual control for sensitive operations
✓ Regular key rotation
✓ Backup and disaster recovery
```

### Security Best Practices

1. **Short Certificate Lifetimes**
   - Service certs: 30 days max
   - Forces automation
   - Limits blast radius of compromise

2. **Role-Based Access**
   - Each service gets its own PKI role
   - Least privilege principle
   - Domain restrictions

3. **Audit Everything**
   - Enable Vault audit logging
   - Monitor certificate issuance
   - Alert on suspicious activity

4. **Regular Rotation**
   - Intermediate CA: Every 5 years
   - Service certs: Every 30 days (automatic)
   - Root CA: Every 10 years (rarely)

## Performance Tuning

### CoreDNS

**Cache TTL:**
```yaml
# values.yaml
- name: cache
  parameters: 30  # seconds
```
- Higher = less load, stale data
- Lower = fresh data, more queries

**Replicas:**
```yaml
replicaCount: 3  # For production
```

**Resources:**
```yaml
resources:
  limits:
    cpu: 500m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

### Vault

**Resources:**
```yaml
resources:
  limits:
    cpu: 1000m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi
```

**HA Mode (Production):**
```yaml
server:
  ha:
    enabled: true
    replicas: 3
    raft:
      enabled: true
```

## Learning Outcomes

By completing Day 4 foundation services, you learn:

### Conceptual Understanding
- ✅ PKI hierarchy (root → intermediate → leaf)
- ✅ HSM concepts (PKCS#11, auto-unseal)
- ✅ DNS in Kubernetes (service discovery)
- ✅ Certificate lifecycles (issue, renew, revoke)
- ✅ Defense in depth (multiple security layers)

### Practical Skills
- ✅ Deploying CoreDNS with custom zones
- ✅ Configuring SoftHSM for Vault
- ✅ Initializing Vault PKI engine
- ✅ Creating PKI roles and policies
- ✅ Integration testing
- ✅ Troubleshooting DNS and certificate issues

### Production Readiness
- ✅ Understanding development vs production
- ✅ Security best practices
- ✅ Performance tuning
- ✅ Disaster recovery concepts
- ✅ Compliance requirements (audit logging)

## Next Steps

After completing foundation services verification:

1. **Day 4 (Hours 5-8)**: Ansible automation
   - Install Ansible
   - Create inventory
   - Bootstrap playbook
   - Idempotency testing

2. **Day 5**: Cert-manager integration
   - Deploy cert-manager
   - Configure Vault issuer
   - Automatic certificate issuance
   - Service integration

3. **Day 6+**: Application services
   - AI Ops Agent with auto-issued certificates
   - Monitoring with TLS
   - Service mesh with mTLS

## Reference Documentation

- [CoreDNS Official Docs](https://coredns.io/)
- [Kubernetes DNS Spec](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
- [SoftHSM Project](https://www.opendnssec.org/softhsm/)
- [PKCS#11 Specification](http://docs.oasis-open.org/pkcs11/pkcs11-base/v2.40/os/pkcs11-base-v2.40-os.html)
- [Vault PKI Secrets Engine](https://developer.hashicorp.com/vault/docs/secrets/pki)
- [Vault Auto-Unseal](https://developer.hashicorp.com/vault/docs/concepts/seal)
- [Cert-Manager Vault Integration](https://cert-manager.io/docs/configuration/vault/)

## Files in This Directory

```
cluster/foundation/
├── README.md                    # This file
├── verify-all.sh                # Master verification script
│
├── coredns/
│   ├── README.md                # CoreDNS documentation
│   ├── deploy.sh                # Deployment script
│   ├── values.yaml              # Helm configuration
│   └── corp.local.db            # DNS zone file
│
├── softhsm/
│   ├── README.md                # SoftHSM documentation
│   ├── init-softhsm.sh          # Initialization script
│   ├── vault-deployment.yaml    # Vault with SoftHSM
│   └── softhsm2.conf            # SoftHSM configuration
│
└── vault-pki/
    ├── README.md                # PKI documentation
    ├── init-vault-pki.sh        # PKI initialization
    ├── verify-pki.sh            # PKI verification
    └── cert-manager-policy.hcl  # Vault policy for cert-manager
```

---

**Status**: Day 4 (Hours 1-4) - Foundation Services Complete

**Prerequisites**: Kind cluster, kubectl, helm, vault CLI

**Next**: Day 4 (Hours 5-8) - Ansible Automation
