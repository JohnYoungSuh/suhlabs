# Day 5: Cert-Manager with Vault Integration

**Goal**: Automatic certificate issuance and renewal using Vault PKI backend.

## Overview

cert-manager automates certificate management in Kubernetes:
- Automatically issues certificates from Vault PKI
- Handles certificate renewal before expiry
- Stores certificates as Kubernetes secrets
- Enables zero-touch certificate lifecycle management

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Certificate Request                   │
│                                                           │
│  Application Pod  →  Certificate  →  ClusterIssuer  →   │
│                         (CRD)          (Vault)           │
│                                            ↓             │
│                                      Vault PKI           │
│                                            ↓             │
│                          ← Certificate + Private Key     │
│                                            ↓             │
│                                    Kubernetes Secret     │
└─────────────────────────────────────────────────────────┘
```

## Prerequisites

From Day 4, you should have:
- ✅ Vault deployed with PKI engine
- ✅ Root CA and Intermediate CA configured
- ✅ PKI roles created (ai-ops-agent, kubernetes, cert-manager)
- ✅ SoftHSM configured for Vault auto-unseal

## Quick Start

### 1. Deploy cert-manager

```bash
cd cluster/foundation/cert-manager

# Set your Vault token
export VAULT_TOKEN=<your-root-token>

# Deploy cert-manager and configure Vault
./deploy.sh
```

This script will:
1. Install cert-manager v1.13.3
2. Wait for cert-manager pods to be ready
3. Configure Vault Kubernetes authentication
4. Create cert-manager policy in Vault
5. Create Vault ClusterIssuers

### 2. Test Certificate Issuance

```bash
# Apply test certificates
kubectl apply -f test-certificate.yaml

# Wait for certificates to be issued (usually <30 seconds)
kubectl get certificate -n default

# Expected output:
# NAME                      READY   SECRET                    AGE
# test-cert                 True    test-cert-tls             30s
# ai-ops-agent-cert         True    ai-ops-agent-tls          30s
# kubernetes-service-cert   True    kubernetes-service-tls    30s
```

### 3. Verify Installation

```bash
# Run comprehensive verification
./verify-cert-manager.sh

# Should show all green checkmarks
```

### 4. Inspect Issued Certificate

```bash
# Get certificate details
kubectl describe certificate test-cert -n default

# View certificate secret
kubectl get secret test-cert-tls -n default -o yaml

# Decode and view certificate
kubectl get secret test-cert-tls -n default -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
```

## Components

### 1. ClusterIssuers

Three ClusterIssuers are created, one for each PKI role:

**vault-issuer** (cert-manager role):
- General-purpose certificate issuance
- 30-day certificate lifetime
- Used by default for most services

**vault-issuer-ai-ops** (ai-ops-agent role):
- AI Ops Agent specific certificates
- Includes corp.local DNS names
- Client and server authentication

**vault-issuer-k8s** (kubernetes role):
- Kubernetes service certificates
- cluster.local DNS names only
- Server authentication

### 2. Certificate Resource

Example certificate definition:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-app-cert
  namespace: default
spec:
  secretName: my-app-tls
  issuerRef:
    name: vault-issuer
    kind: ClusterIssuer
  commonName: my-app.corp.local
  dnsNames:
    - my-app.corp.local
    - my-app.default.svc.cluster.local
  duration: 720h        # 30 days
  renewBefore: 240h     # Renew 10 days before expiry
  privateKey:
    algorithm: RSA
    size: 2048
  usages:
    - digital signature
    - key encipherment
    - server auth
    - client auth
```

### 3. Certificate Lifecycle

```
Day 0:   Certificate requested
         ↓
Day 0:   cert-manager requests cert from Vault
         ↓
Day 0:   Vault signs certificate (30-day lifetime)
         ↓
Day 0:   Certificate stored in Kubernetes secret
         ↓
Day 20:  cert-manager renews certificate (renewBefore: 240h)
         ↓
Day 20:  New certificate issued and replaces old one
         ↓
Day 30:  Old certificate expires (already replaced)
```

## Files

```
cluster/foundation/cert-manager/
├── README.md                   # This file
├── deploy.sh                   # Deployment script
├── verify-cert-manager.sh      # Verification script
├── vault-issuer.yaml           # ClusterIssuer definitions
└── test-certificate.yaml       # Example certificates
```

## Usage Examples

### Example 1: Certificate for Web Service

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: web-app-cert
  namespace: production
spec:
  secretName: web-app-tls
  issuerRef:
    name: vault-issuer
    kind: ClusterIssuer
  commonName: web.corp.local
  dnsNames:
    - web.corp.local
    - www.corp.local
  duration: 720h
  renewBefore: 240h
  privateKey:
    algorithm: RSA
    size: 2048
```

### Example 2: Certificate for Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
  namespace: production
  annotations:
    cert-manager.io/cluster-issuer: vault-issuer
spec:
  tls:
    - hosts:
        - web.corp.local
      secretName: web-ingress-tls
  rules:
    - host: web.corp.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web-service
                port:
                  number: 80
```

cert-manager will automatically create a Certificate resource and request a certificate from Vault.

### Example 3: mTLS Between Services

**Service A (Client):**
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: service-a-client
  namespace: default
spec:
  secretName: service-a-client-tls
  issuerRef:
    name: vault-issuer
    kind: ClusterIssuer
  commonName: service-a.default.svc.cluster.local
  usages:
    - client auth
```

**Service B (Server):**
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: service-b-server
  namespace: default
spec:
  secretName: service-b-server-tls
  issuerRef:
    name: vault-issuer
    kind: ClusterIssuer
  commonName: service-b.default.svc.cluster.local
  usages:
    - server auth
```

Both services can now use mTLS for secure communication.

## Verification

### Check cert-manager Logs

```bash
# View cert-manager logs
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager --tail=50

# Look for successful certificate issuance
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager | grep "successfully issued"
```

### Check Certificate Status

```bash
# List all certificates
kubectl get certificate -A

# Describe certificate for details
kubectl describe certificate test-cert -n default

# Check certificate conditions
kubectl get certificate test-cert -n default -o jsonpath='{.status.conditions[?(@.type=="Ready")]}'
```

### Check Certificate Requests

```bash
# View certificate requests (intermediate resource)
kubectl get certificaterequest -n default

# Describe certificate request
kubectl describe certificaterequest -n default
```

### Validate Certificate Chain

```bash
# Extract certificate
kubectl get secret test-cert-tls -n default -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/test-cert.crt

# View certificate details
openssl x509 -in /tmp/test-cert.crt -text -noout

# Verify against Vault CA
kubectl port-forward -n vault svc/vault 8200:8200 &
export VAULT_ADDR='http://localhost:8200'
export VAULT_TOKEN=<your-token>
vault read -field=certificate pki_int/cert/ca > /tmp/intermediate-ca.crt

# Verify certificate
openssl verify -CAfile /tmp/intermediate-ca.crt /tmp/test-cert.crt
```

## Troubleshooting

### Issue 1: ClusterIssuer Not Ready

**Symptom:**
```bash
kubectl get clusterissuer vault-issuer
# NAME           READY   AGE
# vault-issuer   False   5m
```

**Diagnosis:**
```bash
kubectl describe clusterissuer vault-issuer
```

**Common Causes:**
1. **Vault not accessible**: Check Vault service is running
   ```bash
   kubectl get svc -n vault
   kubectl get pod -n vault
   ```

2. **Kubernetes auth not configured**: Verify Vault Kubernetes auth
   ```bash
   kubectl port-forward -n vault svc/vault 8200:8200 &
   export VAULT_ADDR='http://localhost:8200'
   export VAULT_TOKEN=<your-token>
   vault auth list | grep kubernetes
   vault read auth/kubernetes/config
   ```

3. **cert-manager role not found**: Check Vault role
   ```bash
   vault read auth/kubernetes/role/cert-manager
   ```

### Issue 2: Certificate Not Issuing

**Symptom:**
```bash
kubectl get certificate test-cert -n default
# NAME        READY   SECRET          AGE
# test-cert   False   test-cert-tls   5m
```

**Diagnosis:**
```bash
kubectl describe certificate test-cert -n default
kubectl get certificaterequest -n default
kubectl describe certificaterequest -n default
```

**Common Causes:**
1. **Vault PKI role mismatch**: Certificate requesting from wrong role
   - Check issuerRef in Certificate spec
   - Verify Vault PKI role exists: `vault list pki_int/roles`

2. **Permission denied**: cert-manager policy insufficient
   ```bash
   vault policy read cert-manager
   ```

3. **DNS name not allowed**: Check Vault PKI role allowed_domains
   ```bash
   vault read pki_int/roles/cert-manager
   ```

### Issue 3: Certificate Renewal Not Working

**Symptom:**
Certificate expires instead of renewing automatically.

**Diagnosis:**
```bash
# Check certificate renewal configuration
kubectl get certificate test-cert -n default -o yaml | grep -A2 renewBefore

# Check cert-manager logs for renewal attempts
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager | grep -i renew
```

**Common Causes:**
1. **renewBefore too short**: Should be at least 1/3 of duration
   - Fix: Update Certificate spec with longer renewBefore

2. **cert-manager controller not running**: Check pod status
   ```bash
   kubectl get pod -n cert-manager
   ```

### Issue 4: Private Key Rotation Not Working

**Symptom:**
Private key doesn't change after renewal.

**Fix:**
```yaml
spec:
  privateKey:
    rotationPolicy: Always  # Ensures key rotation on renewal
```

## Security Best Practices

### 1. Use Separate Issuers for Different Security Zones

```yaml
# Production services
issuerRef:
  name: vault-issuer-production
  kind: ClusterIssuer

# Development services
issuerRef:
  name: vault-issuer-development
  kind: ClusterIssuer
```

### 2. Limit Certificate Lifetime

Shorter lifetimes = less risk if compromised:
```yaml
spec:
  duration: 168h      # 7 days (more secure)
  renewBefore: 24h    # Renew 1 day before expiry
```

### 3. Use Proper Key Sizes

```yaml
spec:
  privateKey:
    algorithm: RSA
    size: 4096  # For long-lived certificates
    # size: 2048  # For short-lived certificates (30 days)
```

### 4. Restrict DNS Names

In Vault PKI role:
```bash
vault write pki_int/roles/production \
  allowed_domains="prod.corp.local" \
  allow_subdomains=true \
  allow_bare_domains=false
```

### 5. Monitor Certificate Expiry

Set up Prometheus alerts:
```yaml
- alert: CertificateExpiringSoon
  expr: certmanager_certificate_expiration_timestamp_seconds - time() < 86400 * 7
  annotations:
    summary: "Certificate {{ $labels.name }} expires in less than 7 days"
```

## Integration with Other Services

### AI Ops Agent with Auto-Issued Certificate

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ai-ops-agent
  namespace: ai-ops
spec:
  template:
    spec:
      containers:
      - name: agent
        image: ai-ops-agent:latest
        volumeMounts:
        - name: tls
          mountPath: /etc/tls
          readOnly: true
        env:
        - name: TLS_CERT_FILE
          value: /etc/tls/tls.crt
        - name: TLS_KEY_FILE
          value: /etc/tls/tls.key
      volumes:
      - name: tls
        secret:
          secretName: ai-ops-agent-tls
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ai-ops-agent
  namespace: ai-ops
spec:
  secretName: ai-ops-agent-tls
  issuerRef:
    name: vault-issuer-ai-ops
    kind: ClusterIssuer
  commonName: ai-ops-agent.ai-ops.svc.cluster.local
  dnsNames:
    - ai-ops-agent
    - ai-ops-agent.ai-ops.svc.cluster.local
  duration: 720h
  renewBefore: 240h
```

## Next Steps

**Day 6**: Deploy AI Ops Agent with automatic certificate issuance
**Day 7**: Implement mTLS between all services
**Day 8**: Set up certificate monitoring and alerting

## Key Takeaways

1. **Zero Touch**: Certificates are issued and renewed automatically
2. **Vault Integration**: All certificates signed by your Vault PKI
3. **Kubernetes Native**: Use standard Kubernetes resources
4. **Rotation Built-In**: Automatic renewal before expiry
5. **Security**: Short-lived certificates, automatic key rotation

## References

- [cert-manager Documentation](https://cert-manager.io/docs/)
- [cert-manager Vault Issuer](https://cert-manager.io/docs/configuration/vault/)
- [Vault PKI Secrets Engine](https://developer.hashicorp.com/vault/docs/secrets/pki)
- [Kubernetes TLS](https://kubernetes.io/docs/concepts/services-networking/ingress/#tls)
