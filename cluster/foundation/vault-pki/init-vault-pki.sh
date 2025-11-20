#!/bin/bash
# ============================================================================
# Vault PKI Engine Initialization Script
# Creates Root CA + Intermediate CA hierarchy for corp.local
# ============================================================================
#
# LEARNING MODE: Every command is heavily commented to explain WHY
#
# Architecture:
#   Root CA (Offline in production, online in dev)
#     └─ Intermediate CA (Always online)
#         └─ Service Certificates (30-day TTL, auto-renewed)
#
# Security Notes:
#   - Root CA should be offline (we keep online for dev convenience)
#   - Intermediate CA runs 24/7 in Vault
#   - Service certs have short lifetimes (30 days)
#   - Cert-manager handles automatic renewal
#
# ============================================================================

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
ROOT_CA_NAME="corp.local Root CA"
INTERMEDIATE_CA_NAME="kubernetes.corp.local Intermediate CA"
# DOMAIN="corp.local"  # Reserved for future use

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Vault PKI Initialization${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Target Vault: ${VAULT_ADDR}${NC}"
echo ""

# ============================================================================
# STEP 0: Prerequisites Check
# ============================================================================

echo -e "${YELLOW}[Step 0] Checking prerequisites...${NC}"

# Check if vault CLI is available
if ! command -v vault &> /dev/null; then
    echo -e "${RED}Error: vault CLI not found${NC}"
    echo "Install: brew install vault"
    exit 1
fi

# Check if Vault is accessible
if ! vault status &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Vault at ${VAULT_ADDR}${NC}"
    echo "Make sure Vault is running and VAULT_TOKEN is set"
    echo ""
    echo "If running in Kubernetes:"
    echo "  kubectl port-forward -n vault svc/vault 8200:8200"
    echo "  export VAULT_ADDR=http://localhost:8200"
    echo "  export VAULT_TOKEN=<your-root-token>"
    exit 1
fi

# Check if Vault is initialized
if ! vault status | grep -q "Initialized.*true"; then
    echo -e "${RED}Error: Vault is not initialized${NC}"
    echo "Initialize Vault first:"
    echo "  vault operator init"
    exit 1
fi

# Check if Vault is unsealed
if vault status | grep -q "Sealed.*true"; then
    echo -e "${RED}Error: Vault is sealed${NC}"
    echo "Unseal Vault first (if not using auto-unseal):"
    echo "  vault operator unseal"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites check passed${NC}"
echo ""

# ============================================================================
# STEP 1: Enable PKI Secrets Engine (Root CA)
# ============================================================================

echo -e "${YELLOW}[Step 1] Enabling PKI secrets engine for Root CA...${NC}"

# Why: PKI secrets engine provides CA functionality in Vault
# Path: pki (this will be our root CA)
# This enables the PKI secrets engine at the default path
if vault secrets list | grep -q "^pki/"; then
    echo -e "${BLUE}ℹ PKI engine already enabled at pki/${NC}"
else
    vault secrets enable pki
    echo -e "${GREEN}✓ Enabled PKI engine at pki/${NC}"
fi

# Configure max lease TTL for root CA
# Why: Root CA should have long lifetime (10 years)
# This sets the maximum TTL for any certificate issued by this CA
vault secrets tune -max-lease-ttl=87600h pki
echo -e "${GREEN}✓ Configured max lease TTL: 87600h (10 years)${NC}"
echo ""

# ============================================================================
# STEP 2: Generate Root CA Certificate
# ============================================================================

echo -e "${YELLOW}[Step 2] Generating Root CA certificate...${NC}"

# Why: Root CA is the trust anchor for our entire PKI
# This generates the root certificate and private key
# The private key NEVER leaves Vault (or HSM in production)
#
# In Production: This would be done in an offline ceremony
#   1. Generate CSR
#   2. Transfer to air-gapped machine with YubiHSM
#   3. Sign with HSM
#   4. Transfer signed cert back
#   5. Disconnect HSM
#
# Parameters:
#   - common_name: CN in certificate
#   - ttl: Certificate lifetime (10 years for root)
#   - key_bits: RSA key size (4096 for root CA security)
#   - exclude_cn_from_sans: Don't add CN to SAN (cleaner cert)

echo -e "${BLUE}Generating root certificate (this may take a moment)...${NC}"

vault write -field=certificate pki/root/generate/internal \
    common_name="${ROOT_CA_NAME}" \
    ttl=87600h \
    key_bits=4096 \
    exclude_cn_from_sans=true \
    > root_ca.crt

# The root certificate is now stored in Vault AND saved to root_ca.crt
# We save it to a file so we can:
#   1. Import it into trust stores (browsers, OS)
#   2. Use it to verify the chain
#   3. Sign the intermediate CA

echo -e "${GREEN}✓ Root CA certificate generated${NC}"
echo -e "${BLUE}  Saved to: root_ca.crt${NC}"

# Display certificate details
echo ""
echo -e "${BLUE}Root CA Certificate Details:${NC}"
openssl x509 -in root_ca.crt -noout -subject -issuer -dates
echo ""

# ============================================================================
# STEP 3: Configure Root CA URLs
# ============================================================================

echo -e "${YELLOW}[Step 3] Configuring Root CA URLs...${NC}"

# Why: These URLs tell clients where to find CA info
# CRL: Certificate Revocation List (which certs are revoked)
# Issuing Certs: Where to download the CA certificate
# OCSP: Online Certificate Status Protocol (real-time revocation check)
#
# In production, these would be public URLs:
#   - http://crl.corp.local/v1/pki/crl
#   - http://ca.corp.local/v1/pki/ca
#   - http://ocsp.corp.local

vault write pki/config/urls \
    issuing_certificates="${VAULT_ADDR}/v1/pki/ca" \
    crl_distribution_points="${VAULT_ADDR}/v1/pki/crl"

echo -e "${GREEN}✓ Configured CA URLs${NC}"
echo -e "${BLUE}  Issuing: ${VAULT_ADDR}/v1/pki/ca${NC}"
echo -e "${BLUE}  CRL: ${VAULT_ADDR}/v1/pki/crl${NC}"
echo ""

# ============================================================================
# STEP 4: Enable PKI Secrets Engine (Intermediate CA)
# ============================================================================

echo -e "${YELLOW}[Step 4] Enabling PKI secrets engine for Intermediate CA...${NC}"

# Why: Intermediate CA is what actually issues service certificates
# Path: pki_int (separate from root)
# This allows us to revoke intermediate without affecting root

if vault secrets list | grep -q "^pki_int/"; then
    echo -e "${BLUE}ℹ PKI engine already enabled at pki_int/${NC}"
else
    vault secrets enable -path=pki_int pki
    echo -e "${GREEN}✓ Enabled PKI engine at pki_int/${NC}"
fi

# Configure max lease TTL for intermediate CA
# Why: Intermediate has shorter lifetime than root (5 years)
vault secrets tune -max-lease-ttl=43800h pki_int
echo -e "${GREEN}✓ Configured max lease TTL: 43800h (5 years)${NC}"
echo ""

# ============================================================================
# STEP 5: Generate Intermediate CA CSR
# ============================================================================

echo -e "${YELLOW}[Step 5] Generating Intermediate CA CSR...${NC}"

# Why: We generate a Certificate Signing Request (CSR) that will be signed by root
# The intermediate CA's private key is generated and stays in Vault
# Only the CSR (public key + metadata) is exported for signing
#
# In Production:
#   - This CSR would be transferred to the offline root CA
#   - Signed in the secure ceremony
#   - Signed certificate transferred back

vault write -field=csr pki_int/intermediate/generate/internal \
    common_name="${INTERMEDIATE_CA_NAME}" \
    key_bits=4096 \
    exclude_cn_from_sans=true \
    > pki_intermediate.csr

echo -e "${GREEN}✓ Intermediate CA CSR generated${NC}"
echo -e "${BLUE}  Saved to: pki_intermediate.csr${NC}"
echo ""

# Display CSR details
echo -e "${BLUE}Intermediate CA CSR Details:${NC}"
openssl req -in pki_intermediate.csr -noout -subject
echo ""

# ============================================================================
# STEP 6: Sign Intermediate CA with Root CA
# ============================================================================

echo -e "${YELLOW}[Step 6] Signing Intermediate CA with Root CA...${NC}"

# Why: This creates the trust chain: Root CA → Intermediate CA
# The root CA's signature on the intermediate proves the intermediate is trusted
#
# PRODUCTION CEREMONY WOULD BE:
# ┌────────────────────────────────────────────────────────┐
# │ OFFLINE ROOT CA CEREMONY                               │
# ├────────────────────────────────────────────────────────┤
# │ 1. Copy pki_intermediate.csr to USB drive             │
# │ 2. Enter secure room with 2 people (dual control)     │
# │ 3. Boot air-gapped computer                           │
# │ 4. Connect YubiHSM with root CA key                   │
# │ 5. Insert USB with CSR                                │
# │ 6. Run: vault write pki/root/sign-intermediate        │
# │         csr=@pki_intermediate.csr                     │
# │ 7. Copy signed cert to USB                            │
# │ 8. Disconnect YubiHSM                                 │
# │ 9. Lock HSM in safe                                   │
# │ 10. Return USB to ops team                            │
# │ 11. Log all actions                                   │
# └────────────────────────────────────────────────────────┘
#
# FOR DEV: We do it immediately since root is online

vault write -field=certificate pki/root/sign-intermediate \
    csr=@pki_intermediate.csr \
    format=pem_bundle \
    ttl=43800h \
    > intermediate.cert.pem

echo -e "${GREEN}✓ Intermediate CA signed by Root CA${NC}"
echo -e "${BLUE}  Saved to: intermediate.cert.pem${NC}"
echo ""

# Display signed certificate
echo -e "${BLUE}Intermediate CA Certificate Details:${NC}"
openssl x509 -in intermediate.cert.pem -noout -subject -issuer -dates
echo ""

# ============================================================================
# STEP 7: Import Signed Intermediate Certificate
# ============================================================================

echo -e "${YELLOW}[Step 7] Importing signed intermediate certificate...${NC}"

# Why: We import the signed certificate back into Vault
# Now the intermediate CA can issue certificates signed by itself
# But those certificates chain up to the root CA

vault write pki_int/intermediate/set-signed \
    certificate=@intermediate.cert.pem

echo -e "${GREEN}✓ Intermediate certificate imported${NC}"
echo ""

# ============================================================================
# STEP 8: Configure Intermediate CA URLs
# ============================================================================

echo -e "${YELLOW}[Step 8] Configuring Intermediate CA URLs...${NC}"

vault write pki_int/config/urls \
    issuing_certificates="${VAULT_ADDR}/v1/pki_int/ca" \
    crl_distribution_points="${VAULT_ADDR}/v1/pki_int/crl"

echo -e "${GREEN}✓ Configured Intermediate CA URLs${NC}"
echo ""

# ============================================================================
# STEP 9: Create PKI Roles for Certificate Issuance
# ============================================================================

echo -e "${YELLOW}[Step 9] Creating PKI roles...${NC}"

# Why: Roles define WHO can request WHAT certificates
# Each role has:
#   - Allowed domains (what CNs/SANs are permitted)
#   - TTL limits (how long certs can live)
#   - Key usage (what the cert can be used for)
#   - etc.

# Role 1: AI Ops Agent
# Purpose: Service certificates for AI Ops components
# Allowed: *.corp.local, *.cluster.local
# TTL: 30 days (short = more secure, auto-renewed by cert-manager)

echo -e "${BLUE}Creating role: ai-ops-agent${NC}"

vault write pki_int/roles/ai-ops-agent \
    allowed_domains="corp.local,cluster.local" \
    allow_subdomains=true \
    allow_glob_domains=false \
    allow_bare_domains=false \
    allow_localhost=false \
    max_ttl="720h" \
    key_bits=2048 \
    key_usage="DigitalSignature,KeyEncipherment" \
    ext_key_usage="ServerAuth,ClientAuth" \
    require_cn=true

echo -e "${GREEN}✓ Created role: ai-ops-agent${NC}"
echo -e "${BLUE}  Allowed domains: *.corp.local, *.cluster.local${NC}"
echo -e "${BLUE}  Max TTL: 720h (30 days)${NC}"
echo ""

# Role 2: Kubernetes Services (General)
# Purpose: Any Kubernetes service
# Allowed: *.svc.cluster.local
# TTL: 90 days

echo -e "${BLUE}Creating role: kubernetes${NC}"

vault write pki_int/roles/kubernetes \
    allowed_domains="svc.cluster.local" \
    allow_subdomains=true \
    allow_glob_domains=false \
    max_ttl="2160h" \
    key_bits=2048 \
    key_usage="DigitalSignature,KeyEncipherment" \
    ext_key_usage="ServerAuth,ClientAuth" \
    require_cn=true

echo -e "${GREEN}✓ Created role: kubernetes${NC}"
echo -e "${BLUE}  Allowed domains: *.svc.cluster.local${NC}"
echo -e "${BLUE}  Max TTL: 2160h (90 days)${NC}"
echo ""

# Role 3: Cert-Manager
# Purpose: Cert-manager to issue certs for any cluster service
# Allowed: *.cluster.local (broadest permissions)
# TTL: 90 days

echo -e "${BLUE}Creating role: cert-manager${NC}"

vault write pki_int/roles/cert-manager \
    allowed_domains="cluster.local,corp.local" \
    allow_subdomains=true \
    allow_glob_domains=true \
    max_ttl="2160h" \
    key_bits=2048 \
    key_usage="DigitalSignature,KeyEncipherment" \
    ext_key_usage="ServerAuth,ClientAuth" \
    allow_any_name=false \
    enforce_hostnames=true \
    require_cn=true

echo -e "${GREEN}✓ Created role: cert-manager${NC}"
echo -e "${BLUE}  Allowed domains: *.cluster.local, *.corp.local${NC}"
echo -e "${BLUE}  Max TTL: 2160h (90 days)${NC}"
echo ""

# ============================================================================
# STEP 10: Configure CRL
# ============================================================================

echo -e "${YELLOW}[Step 10] Configuring Certificate Revocation List (CRL)...${NC}"

# Why: CRL is how we tell clients which certificates have been revoked
# Expiry: How long a CRL is valid before needing refresh
# Disable: false = CRL is enabled and published

vault write pki_int/config/crl \
    expiry=72h \
    disable=false

echo -e "${GREEN}✓ CRL configured${NC}"
echo -e "${BLUE}  Expiry: 72h${NC}"
echo ""

# ============================================================================
# STEP 11: Test Certificate Issuance
# ============================================================================

echo -e "${YELLOW}[Step 11] Testing certificate issuance...${NC}"

# Why: Verify the entire chain works
# We'll issue a test certificate and validate it

echo -e "${BLUE}Issuing test certificate for test.corp.local...${NC}"

vault write -field=certificate pki_int/issue/ai-ops-agent \
    common_name="test.corp.local" \
    ttl="24h" \
    > test_cert.pem

vault write -field=private_key pki_int/issue/ai-ops-agent \
    common_name="test.corp.local" \
    ttl="24h" \
    > test_cert.key

echo -e "${GREEN}✓ Test certificate issued${NC}"
echo ""

# Verify certificate
echo -e "${BLUE}Test Certificate Details:${NC}"
openssl x509 -in test_cert.pem -noout -text | grep -A 2 "Subject:"
openssl x509 -in test_cert.pem -noout -text | grep -A 2 "Issuer:"
openssl x509 -in test_cert.pem -noout -text | grep -A 3 "Validity"
echo ""

# Verify certificate chain
echo -e "${BLUE}Verifying certificate chain...${NC}"

# Create CA bundle (intermediate + root)
cat intermediate.cert.pem root_ca.crt > ca_bundle.pem

# Verify chain
if openssl verify -CAfile ca_bundle.pem test_cert.pem; then
    echo -e "${GREEN}✓ Certificate chain is valid!${NC}"
else
    echo -e "${RED}✗ Certificate chain verification failed${NC}"
fi

echo ""

# ============================================================================
# STEP 12: Create Vault Policy for Cert-Manager
# ============================================================================

echo -e "${YELLOW}[Step 12] Creating Vault policy for cert-manager...${NC}"

# Why: Cert-manager needs permission to request certificates
# This policy allows cert-manager to:
#   - Issue certificates from pki_int/issue/cert-manager
#   - Read CA certificate
#   - Nothing else (least privilege)

cat > cert-manager-policy.hcl <<'EOF'
# Policy for cert-manager to issue certificates

# Allow cert-manager to request certificates
path "pki_int/issue/cert-manager" {
  capabilities = ["create", "update"]
}

# Allow cert-manager to request certificates for ai-ops-agent role
path "pki_int/issue/ai-ops-agent" {
  capabilities = ["create", "update"]
}

# Allow cert-manager to request certificates for kubernetes role
path "pki_int/issue/kubernetes" {
  capabilities = ["create", "update"]
}

# Allow cert-manager to read CA certificate
path "pki_int/ca" {
  capabilities = ["read"]
}

# Allow cert-manager to read CRL
path "pki_int/crl" {
  capabilities = ["read"]
}

# Allow cert-manager to sign CSRs
path "pki_int/sign/cert-manager" {
  capabilities = ["create", "update"]
}

path "pki_int/sign/ai-ops-agent" {
  capabilities = ["create", "update"]
}

path "pki_int/sign/kubernetes" {
  capabilities = ["create", "update"]
}
EOF

# Write policy to Vault
vault policy write cert-manager cert-manager-policy.hcl

echo -e "${GREEN}✓ Cert-manager policy created${NC}"
echo ""

# ============================================================================
# SUMMARY
# ============================================================================

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}PKI Initialization Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Certificate Hierarchy:${NC}"
echo "  Root CA: ${ROOT_CA_NAME}"
echo "    └─ Intermediate CA: ${INTERMEDIATE_CA_NAME}"
echo "         └─ Service Certificates (issued via roles)"
echo ""
echo -e "${BLUE}Files Created:${NC}"
echo "  - root_ca.crt              # Root CA certificate (import to trust stores)"
echo "  - intermediate.cert.pem    # Intermediate CA certificate"
echo "  - ca_bundle.pem            # Full chain (intermediate + root)"
echo "  - test_cert.pem            # Test certificate"
echo "  - cert-manager-policy.hcl  # Vault policy for cert-manager"
echo ""
echo -e "${BLUE}Vault PKI Roles Created:${NC}"
echo "  - ai-ops-agent   (*.corp.local, *.cluster.local, 30 days)"
echo "  - kubernetes     (*.svc.cluster.local, 90 days)"
echo "  - cert-manager   (*.cluster.local, *.corp.local, 90 days)"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Import root_ca.crt to your OS trust store (for local testing)"
echo "  2. Deploy cert-manager (Day 5)"
echo "  3. Configure cert-manager to use Vault PKI"
echo "  4. Services will automatically get certificates!"
echo ""
echo -e "${YELLOW}Security Reminder:${NC}"
echo "  In production:"
echo "  - Root CA should be OFFLINE (YubiHSM in a safe)"
echo "  - Intermediate CA signing happens in secure ceremony"
echo "  - Root CA key NEVER online except during ceremony"
echo ""
echo -e "${GREEN}PKI is ready for Day 5 (Cert-Manager integration)!${NC}"
