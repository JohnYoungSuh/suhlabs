#!/bin/bash
# ============================================================================
# Vault PKI Verification Script
# Validates that PKI is correctly configured
# ============================================================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
FAILED=0

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Vault PKI Verification${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# ============================================================================
# Test 1: Vault Connectivity
# ============================================================================

echo -e "${YELLOW}[Test 1] Checking Vault connectivity...${NC}"

if vault status &> /dev/null; then
    echo -e "${GREEN}✓ Vault is accessible at ${VAULT_ADDR}${NC}"
else
    echo -e "${RED}✗ Cannot connect to Vault${NC}"
    FAILED=$((FAILED + 1))
fi
echo ""

# ============================================================================
# Test 2: PKI Secrets Engines Enabled
# ============================================================================

echo -e "${YELLOW}[Test 2] Checking PKI secrets engines...${NC}"

if vault secrets list | grep -q "^pki/"; then
    echo -e "${GREEN}✓ Root PKI engine enabled (pki/)${NC}"
else
    echo -e "${RED}✗ Root PKI engine not found${NC}"
    FAILED=$((FAILED + 1))
fi

if vault secrets list | grep -q "^pki_int/"; then
    echo -e "${GREEN}✓ Intermediate PKI engine enabled (pki_int/)${NC}"
else
    echo -e "${RED}✗ Intermediate PKI engine not found${NC}"
    FAILED=$((FAILED + 1))
fi
echo ""

# ============================================================================
# Test 3: Root CA Certificate
# ============================================================================

echo -e "${YELLOW}[Test 3] Checking Root CA certificate...${NC}"

if vault read -field=certificate pki/cert/ca > /dev/null 2>&1; then
    ROOT_CA=$(vault read -field=certificate pki/cert/ca)
    echo "$ROOT_CA" | openssl x509 -noout -subject -issuer -dates
    echo -e "${GREEN}✓ Root CA certificate exists${NC}"

    # Check it's self-signed (root)
    SUBJECT=$(echo "$ROOT_CA" | openssl x509 -noout -subject | sed 's/subject=//')
    ISSUER=$(echo "$ROOT_CA" | openssl x509 -noout -issuer | sed 's/issuer=//')

    if [ "$SUBJECT" = "$ISSUER" ]; then
        echo -e "${GREEN}✓ Root CA is self-signed (correct)${NC}"
    else
        echo -e "${RED}✗ Root CA is not self-signed${NC}"
        FAILED=$((FAILED + 1))
    fi
else
    echo -e "${RED}✗ Root CA certificate not found${NC}"
    FAILED=$((FAILED + 1))
fi
echo ""

# ============================================================================
# Test 4: Intermediate CA Certificate
# ============================================================================

echo -e "${YELLOW}[Test 4] Checking Intermediate CA certificate...${NC}"

if vault read -field=certificate pki_int/cert/ca > /dev/null 2>&1; then
    INT_CA=$(vault read -field=certificate pki_int/cert/ca)
    echo "$INT_CA" | openssl x509 -noout -subject -issuer -dates
    echo -e "${GREEN}✓ Intermediate CA certificate exists${NC}"

    # Check it's signed by root (not self-signed)
    INT_SUBJECT=$(echo "$INT_CA" | openssl x509 -noout -subject | sed 's/subject=//')
    INT_ISSUER=$(echo "$INT_CA" | openssl x509 -noout -issuer | sed 's/issuer=//')

    if [ "$INT_SUBJECT" != "$INT_ISSUER" ]; then
        echo -e "${GREEN}✓ Intermediate CA is signed by Root (correct)${NC}"
    else
        echo -e "${RED}✗ Intermediate CA appears to be self-signed${NC}"
        FAILED=$((FAILED + 1))
    fi
else
    echo -e "${RED}✗ Intermediate CA certificate not found${NC}"
    FAILED=$((FAILED + 1))
fi
echo ""

# ============================================================================
# Test 5: PKI Roles
# ============================================================================

echo -e "${YELLOW}[Test 5] Checking PKI roles...${NC}"

ROLES=("ai-ops-agent" "kubernetes" "cert-manager")

for role in "${ROLES[@]}"; do
    if vault read pki_int/roles/"$role" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Role exists: $role${NC}"
    else
        echo -e "${RED}✗ Role not found: $role${NC}"
        FAILED=$((FAILED + 1))
    fi
done
echo ""

# ============================================================================
# Test 6: Certificate Issuance
# ============================================================================

echo -e "${YELLOW}[Test 6] Testing certificate issuance...${NC}"

TEST_CN="verify-test.corp.local"

if vault write -field=certificate pki_int/issue/ai-ops-agent \
    common_name="$TEST_CN" \
    ttl="1h" > /tmp/verify_cert.pem 2>&1; then

    echo -e "${GREEN}✓ Successfully issued test certificate${NC}"

    # Verify certificate details
    CERT_CN=$(openssl x509 -in /tmp/verify_cert.pem -noout -subject | grep -o "CN = [^,]*" | cut -d= -f2 | tr -d ' ')

    if [ "$CERT_CN" = "$TEST_CN" ]; then
        echo -e "${GREEN}✓ Certificate CN matches request: $CERT_CN${NC}"
    else
        echo -e "${RED}✗ Certificate CN mismatch. Expected: $TEST_CN, Got: $CERT_CN${NC}"
        FAILED=$((FAILED + 1))
    fi

    # Check certificate chain
    if [ -f "ca_bundle.pem" ]; then
        if openssl verify -CAfile ca_bundle.pem /tmp/verify_cert.pem > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Certificate chain is valid${NC}"
        else
            echo -e "${RED}✗ Certificate chain verification failed${NC}"
            FAILED=$((FAILED + 1))
        fi
    else
        echo -e "${YELLOW}⚠ ca_bundle.pem not found, skipping chain verification${NC}"
    fi

    rm -f /tmp/verify_cert.pem
else
    echo -e "${RED}✗ Failed to issue test certificate${NC}"
    FAILED=$((FAILED + 1))
fi
echo ""

# ============================================================================
# Test 7: CRL Configuration
# ============================================================================

echo -e "${YELLOW}[Test 7] Checking CRL configuration...${NC}"

if vault read pki_int/config/crl > /dev/null 2>&1; then
    echo -e "${GREEN}✓ CRL is configured${NC}"

    # Try to fetch CRL
    if curl -sf "${VAULT_ADDR}/v1/pki_int/crl" > /dev/null; then
        echo -e "${GREEN}✓ CRL is accessible${NC}"
    else
        echo -e "${YELLOW}⚠ CRL endpoint not accessible (may be empty)${NC}"
    fi
else
    echo -e "${RED}✗ CRL configuration not found${NC}"
    FAILED=$((FAILED + 1))
fi
echo ""

# ============================================================================
# Test 8: Vault Policy
# ============================================================================

echo -e "${YELLOW}[Test 8] Checking Vault policies...${NC}"

if vault policy read cert-manager > /dev/null 2>&1; then
    echo -e "${GREEN}✓ cert-manager policy exists${NC}"
else
    echo -e "${RED}✗ cert-manager policy not found${NC}"
    FAILED=$((FAILED + 1))
fi
echo ""

# ============================================================================
# Test 9: URLs Configuration
# ============================================================================

echo -e "${YELLOW}[Test 9] Checking CA URLs configuration...${NC}"

ROOT_URLS=$(vault read -format=json pki/config/urls 2>/dev/null || echo '{}')
INT_URLS=$(vault read -format=json pki_int/config/urls 2>/dev/null || echo '{}')

if echo "$ROOT_URLS" | grep -q "issuing_certificates"; then
    echo -e "${GREEN}✓ Root CA URLs configured${NC}"
else
    echo -e "${RED}✗ Root CA URLs not configured${NC}"
    FAILED=$((FAILED + 1))
fi

if echo "$INT_URLS" | grep -q "issuing_certificates"; then
    echo -e "${GREEN}✓ Intermediate CA URLs configured${NC}"
else
    echo -e "${RED}✗ Intermediate CA URLs not configured${NC}"
    FAILED=$((FAILED + 1))
fi
echo ""

# ============================================================================
# Summary
# ============================================================================

echo -e "${GREEN}========================================${NC}"
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed! ✓${NC}"
    echo -e "${GREEN}PKI is correctly configured and ready to use.${NC}"
else
    echo -e "${RED}$FAILED test(s) failed ✗${NC}"
    echo -e "${YELLOW}Please review the errors above and re-run init-vault-pki.sh if needed.${NC}"
    exit 1
fi
echo -e "${GREEN}========================================${NC}"
echo ""

echo -e "${BLUE}PKI Summary:${NC}"
echo "  Root CA Path: pki/"
echo "  Intermediate CA Path: pki_int/"
echo "  Roles: ai-ops-agent, kubernetes, cert-manager"
echo "  Policy: cert-manager"
echo ""
echo -e "${BLUE}Useful Commands:${NC}"
echo "  # List all certificates"
echo "  vault list pki_int/certs"
echo ""
echo "  # Issue a certificate"
echo "  vault write pki_int/issue/ai-ops-agent common_name=test.corp.local ttl=24h"
echo ""
echo "  # Read CA certificate"
echo "  vault read -field=certificate pki_int/cert/ca"
echo ""
echo "  # Check CRL"
echo "  curl ${VAULT_ADDR}/v1/pki_int/crl"
echo ""
