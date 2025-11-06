# DNS and Certificate Management

**Status**: Production-ready
**Components**: BIND DNS, cert-manager, Let's Encrypt, FreeIPA CA
**Domain Pattern**: `$fam_name.family.suhlabs.com` (e.g., `suh.family.suhlabs.com`)

---

## Overview

This document describes the DNS and certificate management infrastructure for family homelab deployments. The system provides:

1. **DNS Server** (BIND9) - Authoritative DNS for family domains
2. **cert-manager** - Automated certificate lifecycle management in Kubernetes
3. **Let's Encrypt Integration** - Free, trusted TLS certificates for public-facing services
4. **FreeIPA CA Integration** - Internal certificate authority for service-to-service communication

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  DNS Layer (BIND9)                                          │
│  ├── suh.family.suhlabs.com (authoritative)                │
│  ├── CAA records → letsencrypt.org only                    │
│  ├── MX records → mail.suh.family.suhlabs.com              │
│  └── A records → Kubernetes ingress VIP (10.100.0.5)       │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  cert-manager (Kubernetes)                                  │
│  ├── ClusterIssuer: letsencrypt-prod                       │
│  │   └── ACME HTTP-01 challenge via ingress                │
│  ├── ClusterIssuer: letsencrypt-staging                    │
│  │   └── For testing (higher rate limits)                  │
│  └── ClusterIssuer: freeipa-ca                             │
│      └── Internal CA for service-to-service TLS            │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  Services with TLS                                          │
│  ├── grafana.suh.family.suhlabs.com → Let's Encrypt       │
│  ├── vault.suh.family.suhlabs.com → Let's Encrypt         │
│  ├── mail.suh.family.suhlabs.com → Let's Encrypt (certbot)│
│  └── Internal APIs → FreeIPA CA                            │
└─────────────────────────────────────────────────────────────┘
```

---

## Deployment

### Prerequisites

1. **Infrastructure deployed**:
   ```bash
   make apply-prod              # Provision VMs with Terraform
   make ansible-deploy-k3s      # Deploy Kubernetes cluster
   ```

2. **FreeIPA deployed** (for internal CA):
   ```bash
   make ansible-deploy-freeipa
   ```

3. **Ansible collections installed**:
   ```bash
   make ansible-install-collections
   ```

4. **kubectl configured**:
   ```bash
   make ansible-kubeconfig
   export KUBECONFIG=~/.kube/config-aiops-prod
   ```

### Step 1: Deploy DNS and Certificate Infrastructure

```bash
make ansible-deploy-dns-certs
```

This will:
- Configure BIND DNS with `suh.family.suhlabs.com` domain
- Create DNS records for all services
- Add CAA records restricting certificate issuance to Let's Encrypt
- Install cert-manager v1.13.3 to Kubernetes
- Create ClusterIssuers for Let's Encrypt (production + staging)
- Create ClusterIssuer for FreeIPA CA
- Fetch FreeIPA CA certificate and import to Kubernetes

### Step 2: Verify DNS Resolution

```bash
# From any machine on the network
dig @10.100.0.X suh.family.suhlabs.com SOA
dig @10.100.0.X mail.suh.family.suhlabs.com A
dig @10.100.0.X grafana.suh.family.suhlabs.com A
dig @10.100.0.X suh.family.suhlabs.com CAA

# Expected CAA output:
# suh.family.suhlabs.com. 86400 IN CAA 0 issue "letsencrypt.org"
```

### Step 3: Test Certificate Issuance (Staging)

```bash
make ansible-test-cert
```

This creates a test certificate using Let's Encrypt staging environment (untrusted, but validates workflow).

### Step 4: Update Domain Registrar (If Public)

If using a public domain, add NS records at your registrar:

```
suh.family.suhlabs.com.  IN  NS  ns1.suh.family.suhlabs.com.
```

And glue records:
```
ns1.suh.family.suhlabs.com.  IN  A  <your-dns-server-public-ip>
```

---

## DNS Configuration

### Domain Structure

```
suh.family.suhlabs.com
├── @                           → Apex (10.100.0.5 - ingress VIP)
├── mail                        → Email server (10.100.0.30)
├── grafana                     → Grafana dashboard (10.100.0.5)
├── vault                       → Vault UI (10.100.0.5)
├── portal                      → Family portal (10.100.0.5)
├── *                           → Wildcard (10.100.0.5)
└── *.k3s                       → K8s services wildcard (10.100.0.5)
```

### DNS Records (Configured in `ansible/vars/family-dns.yml`)

```yaml
dns_domain: suh.family.suhlabs.com
dns_records:
  # Email
  - { name: "mail", type: "A", value: "10.100.0.30" }
  - { name: "@", type: "MX", priority: 10, value: "mail" }

  # Kubernetes services (via ingress)
  - { name: "grafana", type: "A", value: "10.100.0.5" }
  - { name: "vault", type: "A", value: "10.100.0.5" }
  - { name: "portal", type: "A", value: "10.100.0.5" }

  # Wildcard for all services
  - { name: "*", type: "A", value: "10.100.0.5" }

  # CAA (Certificate Authority Authorization)
  - { name: "@", type: "CAA", value: "0 issue \"letsencrypt.org\"" }
  - { name: "@", type: "CAA", value: "0 issuewild \"letsencrypt.org\"" }

  # Email security
  - { name: "@", type: "TXT", value: "v=spf1 mx ~all" }
  - { name: "_dmarc", type: "TXT", value: "v=DMARC1; p=quarantine; ..." }
```

### Adding New DNS Records

1. Edit `ansible/vars/family-dns.yml`:
   ```yaml
   dns_records:
     - { name: "myapp", type: "A", value: "10.100.0.5" }
   ```

2. Re-deploy DNS:
   ```bash
   make ansible-deploy-dns
   ```

3. Verify:
   ```bash
   dig @10.100.0.X myapp.suh.family.suhlabs.com A
   ```

---

## Certificate Management

### ClusterIssuers Available

| Name | Purpose | Trust | Use Case |
|------|---------|-------|----------|
| `letsencrypt-prod` | Production certs | Public (browser-trusted) | Family-facing web services |
| `letsencrypt-staging` | Testing | Untrusted | Testing before production |
| `freeipa-ca` | Internal CA | Private (manual install) | Service-to-service TLS |

### Requesting a Certificate

#### Method 1: Via Ingress Annotation

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  namespace: monitoring
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
    - hosts:
        - grafana.suh.family.suhlabs.com
      secretName: grafana-tls  # cert-manager creates this
  rules:
    - host: grafana.suh.family.suhlabs.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: grafana
                port:
                  number: 3000
```

#### Method 2: Explicit Certificate Resource

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: vault-tls
  namespace: vault
spec:
  secretName: vault-tls-secret
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - vault.suh.family.suhlabs.com
  privateKey:
    algorithm: RSA
    size: 2048
```

### Certificate Lifecycle

1. **Request**: Create Ingress or Certificate resource
2. **Challenge**: cert-manager creates temporary HTTP endpoint
3. **Validation**: Let's Encrypt hits `http://yourapp.suh.family.suhlabs.com/.well-known/acme-challenge/<token>`
4. **Issuance**: Certificate issued and stored in Secret
5. **Renewal**: Auto-renewed 30 days before expiration

### Monitoring Certificates

```bash
# List all certificates
kubectl get certificates -A

# Check certificate status
kubectl describe certificate grafana-tls -n monitoring

# View certificate details
kubectl get secret grafana-tls -n monitoring -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text
```

### Certificate Troubleshooting

```bash
# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager -f

# Check ACME challenges
kubectl get challenges -A

# Describe a failing certificate
kubectl describe certificate <name> -n <namespace>

# Common issues:
# 1. DNS not resolving → verify dig @10.100.0.X yourapp.suh.family.suhlabs.com
# 2. Ingress not exposed → verify port 80 accessible
# 3. Rate limit hit → use letsencrypt-staging for testing
```

---

## Security Best Practices

### 1. CAA Records

CAA records prevent unauthorized certificate issuance:

```
suh.family.suhlabs.com. IN CAA 0 issue "letsencrypt.org"
```

Only Let's Encrypt can issue certificates for your domain.

### 2. Certificate Transparency Monitoring

Monitor for unauthorized certificates:

```bash
# Check CT logs
curl https://crt.sh/?q=%.suh.family.suhlabs.com&output=json
```

### 3. Let's Encrypt Rate Limits

- **50 certificates** per registered domain per week
- **5 duplicate certificates** per week
- Use `letsencrypt-staging` for testing

### 4. Backup ACME Account Keys

```bash
# Backup Let's Encrypt account key
kubectl get secret letsencrypt-prod-account-key -n cert-manager -o yaml > letsencrypt-prod-backup.yaml

# Store securely (Vault, encrypted backup)
```

### 5. Separate Trust Boundaries

- **Public services** → Let's Encrypt (grafana, vault UI)
- **Internal APIs** → FreeIPA CA (service mesh, backend services)

---

## Integration with Services

### Vault with Let's Encrypt

Update `cluster/core/vault/vault.yaml`:

```yaml
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: vault
  namespace: vault
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
    - hosts:
        - vault.suh.family.suhlabs.com
      secretName: vault-tls
  rules:
    - host: vault.suh.family.suhlabs.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: vault
                port:
                  number: 8200
```

### Grafana with Let's Encrypt

Update `cluster/monitoring/grafana/ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  namespace: monitoring
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
    - hosts:
        - grafana.suh.family.suhlabs.com
      secretName: grafana-tls
  rules:
    - host: grafana.suh.family.suhlabs.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: grafana
                port:
                  number: 3000
```

### Email Server with certbot

For the email server (VM-based, not Kubernetes), use certbot:

```bash
# Install certbot
ansible-playbook -i inventory ansible/roles/postfix/tasks/certbot.yml

# Or manually:
sudo certbot certonly --standalone -d mail.suh.family.suhlabs.com

# Configure Postfix/Dovecot to use certs:
# /etc/letsencrypt/live/mail.suh.family.suhlabs.com/fullchain.pem
# /etc/letsencrypt/live/mail.suh.family.suhlabs.com/privkey.pem
```

---

## Operational Procedures

### Renewing Certificates

Certificates auto-renew 30 days before expiration. To force renewal:

```bash
# Delete the certificate (cert-manager recreates it)
kubectl delete certificate grafana-tls -n monitoring

# Or use cmctl
cmctl renew grafana-tls -n monitoring
```

### Upgrading cert-manager

```bash
# Update version in ansible/roles/cert-manager/defaults/main.yml
cert_manager_version: "v1.14.0"

# Re-deploy
make ansible-deploy-dns-certs
```

### Changing Let's Encrypt Email

```bash
# Edit ansible/vars/family-dns.yml
letsencrypt_email: "newadmin@suh.family.suhlabs.com"

# Re-deploy ClusterIssuers
kubectl delete clusterissuer letsencrypt-prod
make ansible-deploy-dns-certs
```

---

## Maintenance

### Backup Strategy

1. **DNS zone files**: `/var/named/zones/master/`
2. **cert-manager secrets**: All secrets in `cert-manager` namespace
3. **ACME account keys**: `letsencrypt-prod-account-key` secret

```bash
# Backup all cert-manager resources
kubectl get secrets,clusterissuers,certificates -A -o yaml > cert-manager-backup.yaml
```

### Monitoring

Add alerts for:
- Certificate expiration < 30 days
- cert-manager pod crashes
- ACME challenge failures
- DNS server downtime

### Disaster Recovery

1. **Restore DNS**:
   ```bash
   make ansible-deploy-dns
   ```

2. **Restore cert-manager**:
   ```bash
   kubectl apply -f cert-manager-backup.yaml
   ```

3. **Reissue certificates** (if ACME keys lost):
   - Delete ClusterIssuer
   - Re-deploy (new ACME account)
   - Reissue all certificates

---

## Reference

### Files Created

```
ansible/
├── vars/family-dns.yml                          # DNS configuration
├── requirements.yml                             # Ansible collections
├── deploy-dns-and-certs.yml                     # Main playbook
└── roles/
    ├── bind-dns/                                # Existing DNS role
    │   └── templates/zone-forward.j2            # Updated with CAA support
    └── cert-manager/                            # New role
        ├── defaults/main.yml
        ├── tasks/main.yml
        ├── templates/
        │   ├── cluster-issuer-letsencrypt.yaml.j2
        │   └── cluster-issuer-freeipa.yaml.j2
        └── handlers/main.yml

cluster/core/cert-manager/
├── namespace.yaml
├── install.yaml
├── cluster-issuer-letsencrypt.yaml
└── cluster-issuer-freeipa.yaml

docs/
└── dns-and-certificate-management.md           # This file
```

### Makefile Targets

```bash
make ansible-install-collections  # Install Ansible dependencies
make ansible-deploy-dns-certs     # Full deployment
make ansible-test-cert            # Test certificate issuance
```

### Related Documentation

- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [BIND9 Documentation](https://www.isc.org/bind/)
- [FreeIPA Documentation](https://www.freeipa.org/page/Documentation)

---

**Last Updated**: 2025-11-06
**Maintainer**: Infrastructure Team
**Status**: Production-ready
