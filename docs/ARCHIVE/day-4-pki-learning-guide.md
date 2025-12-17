# PKI Initialization - Learning Summary

## The 12 Steps of Setting Up a Certificate Authority

### STEP 0: Prerequisites Check (Lines 45-86)
**What it does:** Checks if vault CLI is installed, Vault is running, initialized, and unsealed
**Why:** Can't configure PKI if Vault isn't ready
**Key Command:** `vault status`

### STEP 1: Enable PKI Engine for Root CA (Lines 89-109)
**What it does:** Enables the PKI secrets engine at path `pki/`
**Why:** Vault needs this engine to act as a CA
**Key Command:** `vault secrets enable pki`
**Config:** Sets max lease TTL to 87600h (10 years)

### STEP 2: Generate Root CA Certificate (Lines 112-156)
**What it does:** Creates the Root CA certificate and private key
**Why:** Root CA is the trust anchor - everything chains back to this
**Key Command:** `vault write pki/root/generate/internal`
**Parameters:**
  - common_name: "corp.local Root CA"
  - ttl: 87600h (10 years)
  - key_bits: 4096 (strong encryption)

**IMPORTANT:** In production, this would be done offline in a secure facility

### STEP 3: Configure Root CA URLs (Lines 159-181)
**What it does:** Sets URLs for CRL and certificate downloads
**Why:** Clients need to know where to check if certificates are revoked
**Key Command:** `vault write pki/config/urls`
**URLs:**
  - Issuing certs: http://localhost:8200/v1/pki/ca
  - CRL: http://localhost:8200/v1/pki/crl

### STEP 4: Enable PKI Engine for Intermediate CA (Lines 184-205)
**What it does:** Enables a SECOND PKI engine at path `pki_int/`
**Why:** Intermediate CA issues actual service certs (Root stays offline)
**Key Command:** `vault secrets enable -path=pki_int pki`
**Config:** Max lease TTL 43800h (5 years)

### STEP 5: Generate Intermediate CA CSR (Lines 207-235)
**What it does:** Creates Certificate Signing Request for Intermediate CA
**Why:** CSR needs to be signed by Root CA
**Key Command:** `vault write pki_int/intermediate/generate/internal`
**Output:** intermediate.csr (saved to file)

### STEP 6: Sign Intermediate CA with Root CA (Lines 237-279)
**What it does:** Root CA signs the Intermediate CA's CSR
**Why:** This creates the certificate chain: Root → Intermediate
**Key Command:** `vault write pki/root/sign-intermediate`
**Parameters:**
  - csr: The CSR from Step 5
  - ttl: 43800h (5 years)
  - format: pem_bundle

### STEP 7: Import Signed Intermediate Certificate (Lines 281-295)
**What it does:** Imports the signed certificate back into pki_int/
**Why:** Intermediate CA can now issue certificates
**Key Command:** `vault write pki_int/intermediate/set-signed`

### STEP 8: Configure Intermediate CA URLs (Lines 297-308)
**What it does:** Sets URLs for Intermediate CA CRL and certs
**Why:** Same reason as Root CA - clients need revocation info
**Key Command:** `vault write pki_int/config/urls`

### STEP 9: Create PKI Roles (Lines 310-391)
**What it does:** Creates 3 roles for different use cases
**Why:** Each service gets appropriate permissions (least privilege)

**Roles Created:**
1. **ai-ops-agent** (30 day certs)
   - For AI Ops Agent service
   - Domain: *.corp.local
   - Max TTL: 720h (30 days)

2. **kubernetes** (90 day certs)
   - For Kubernetes services
   - Domain: *.cluster.local, *.corp.local
   - Max TTL: 2160h (90 days)

3. **cert-manager** (90 day certs)
   - For cert-manager automation
   - Domain: *.cluster.local, *.corp.local
   - Max TTL: 2160h (90 days)

**Key Point:** Short lifetimes force automation!

### STEP 10: Configure CRL (Lines 393-409)
**What it does:** Configures Certificate Revocation List
**Why:** When certs are compromised, we need to revoke them
**Key Command:** `vault write pki_int/config/crl`
**Config:**
  - expiry: 72h
  - disable: false

### STEP 11: Test Certificate Issuance (Lines 411-455)
**What it does:** Issues a test certificate to verify everything works
**Why:** Catch problems now, not in production!
**Key Command:** `vault write pki_int/issue/ai-ops-agent`
**Test:** Issues cert for "test.corp.local" with 24h TTL

### STEP 12: Create Vault Policy for Cert-Manager (Lines 457-end)
**What it does:** Creates policy allowing cert-manager to issue certs
**Why:** Least privilege - cert-manager only gets what it needs
**Key Command:** `vault policy write cert-manager`
**Permissions:**
  - Read PKI role configuration
  - Issue certificates via pki_int/issue/cert-manager

---

## Key Takeaways

1. **Two-Tier PKI:** Root (offline) → Intermediate (online)
2. **Short Lifetimes:** Forces automation, limits damage
3. **Least Privilege:** Each role has specific domains/TTLs
4. **CRL:** Revocation is part of design from day 1
5. **Testing:** Always test before production

## Next: How Certificates Flow

```
Application needs cert
    ↓
Cert-Manager detects (watches Kubernetes)
    ↓
Cert-Manager calls Vault API: pki_int/issue/cert-manager
    ↓
Vault checks role permissions
    ↓
Vault issues cert (30-90 days)
    ↓
Cert-Manager stores in Kubernetes Secret
    ↓
Application mounts secret as TLS cert
    ↓
(10 days before expiry)
    ↓
Cert-Manager repeats process automatically
```

## Commands to Practice

```bash
# Port forward to Vault
kubectl port-forward -n vault svc/vault 8200:8200

# Set environment
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=<your-root-token>

# Check PKI engines
vault secrets list

# Read Root CA
vault read pki/cert/ca

# Read Intermediate CA
vault read pki_int/cert/ca

# List roles
vault list pki_int/roles

# Read role details
vault read pki_int/roles/ai-ops-agent

# Issue test certificate
vault write pki_int/issue/ai-ops-agent \
  common_name="test.corp.local" \
  ttl="1h"
```
