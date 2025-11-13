#!/bin/bash
# =============================================================================
# Verify cert-manager Installation and Certificate Issuance
# Day 5: Automatic Certificate Issuance Verification
# =============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

PASS=0
FAIL=0

echo -e "${BLUE}=== Day 5: Verifying cert-manager Installation ===${NC}"
echo ""

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------
check_pass() {
    echo -e "${GREEN}✓ $1${NC}"
    ((PASS++))
}

check_fail() {
    echo -e "${RED}✗ $1${NC}"
    ((FAIL++))
}

# -----------------------------------------------------------------------------
# Test 1: cert-manager Namespace
# -----------------------------------------------------------------------------
echo -e "${YELLOW}Test 1: Checking cert-manager namespace...${NC}"
if kubectl get namespace cert-manager &>/dev/null; then
    check_pass "cert-manager namespace exists"
else
    check_fail "cert-manager namespace not found"
fi
echo ""

# -----------------------------------------------------------------------------
# Test 2: cert-manager Pods
# -----------------------------------------------------------------------------
echo -e "${YELLOW}Test 2: Checking cert-manager pods...${NC}"

PODS=(
    "cert-manager"
    "cert-manager-cainjector"
    "cert-manager-webhook"
)

for pod in "${PODS[@]}"; do
    if kubectl get pod -n cert-manager -l app.kubernetes.io/name=${pod} &>/dev/null; then
        POD_STATUS=$(kubectl get pod -n cert-manager -l app.kubernetes.io/name=${pod} -o jsonpath='{.items[0].status.phase}')
        if [ "$POD_STATUS" = "Running" ]; then
            check_pass "Pod ${pod} is running"
        else
            check_fail "Pod ${pod} is ${POD_STATUS}"
        fi
    else
        check_fail "Pod ${pod} not found"
    fi
done
echo ""

# -----------------------------------------------------------------------------
# Test 3: cert-manager CRDs
# -----------------------------------------------------------------------------
echo -e "${YELLOW}Test 3: Checking cert-manager CRDs...${NC}"

CRDS=(
    "certificates.cert-manager.io"
    "certificaterequests.cert-manager.io"
    "issuers.cert-manager.io"
    "clusterissuers.cert-manager.io"
)

for crd in "${CRDS[@]}"; do
    if kubectl get crd ${crd} &>/dev/null; then
        check_pass "CRD ${crd} exists"
    else
        check_fail "CRD ${crd} not found"
    fi
done
echo ""

# -----------------------------------------------------------------------------
# Test 4: Vault ClusterIssuers
# -----------------------------------------------------------------------------
echo -e "${YELLOW}Test 4: Checking Vault ClusterIssuers...${NC}"

ISSUERS=(
    "vault-issuer"
    "vault-issuer-ai-ops"
    "vault-issuer-k8s"
)

for issuer in "${ISSUERS[@]}"; do
    if kubectl get clusterissuer ${issuer} &>/dev/null; then
        ISSUER_READY=$(kubectl get clusterissuer ${issuer} -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
        if [ "$ISSUER_READY" = "True" ]; then
            check_pass "ClusterIssuer ${issuer} is ready"
        else
            check_fail "ClusterIssuer ${issuer} is not ready (status: ${ISSUER_READY})"
        fi
    else
        check_fail "ClusterIssuer ${issuer} not found"
    fi
done
echo ""

# -----------------------------------------------------------------------------
# Test 5: Test Certificates
# -----------------------------------------------------------------------------
echo -e "${YELLOW}Test 5: Checking test certificates...${NC}"

TEST_CERTS=(
    "test-cert"
    "ai-ops-agent-cert"
    "kubernetes-service-cert"
)

for cert in "${TEST_CERTS[@]}"; do
    if kubectl get certificate ${cert} -n default &>/dev/null; then
        CERT_READY=$(kubectl get certificate ${cert} -n default -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
        if [ "$CERT_READY" = "True" ]; then
            check_pass "Certificate ${cert} is ready"
        else
            CERT_REASON=$(kubectl get certificate ${cert} -n default -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null || echo "Unknown reason")
            check_fail "Certificate ${cert} is not ready: ${CERT_REASON}"
        fi
    else
        echo -e "${YELLOW}  ℹ Certificate ${cert} not found (not applied yet)${NC}"
    fi
done
echo ""

# -----------------------------------------------------------------------------
# Test 6: Certificate Secrets
# -----------------------------------------------------------------------------
echo -e "${YELLOW}Test 6: Checking certificate secrets...${NC}"

SECRETS=(
    "test-cert-tls"
    "ai-ops-agent-tls"
    "kubernetes-service-tls"
)

for secret in "${SECRETS[@]}"; do
    if kubectl get secret ${secret} -n default &>/dev/null; then
        # Check if secret contains tls.crt and tls.key
        HAS_CRT=$(kubectl get secret ${secret} -n default -o jsonpath='{.data.tls\.crt}' 2>/dev/null | wc -c)
        HAS_KEY=$(kubectl get secret ${secret} -n default -o jsonpath='{.data.tls\.key}' 2>/dev/null | wc -c)

        if [ "$HAS_CRT" -gt 0 ] && [ "$HAS_KEY" -gt 0 ]; then
            check_pass "Secret ${secret} contains valid certificate"
        else
            check_fail "Secret ${secret} is missing certificate data"
        fi
    else
        echo -e "${YELLOW}  ℹ Secret ${secret} not found (certificate not issued yet)${NC}"
    fi
done
echo ""

# -----------------------------------------------------------------------------
# Test 7: Certificate Chain Validation
# -----------------------------------------------------------------------------
echo -e "${YELLOW}Test 7: Validating certificate chain...${NC}"

if kubectl get secret test-cert-tls -n default &>/dev/null; then
    # Extract certificate
    kubectl get secret test-cert-tls -n default -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/test-cert.crt 2>/dev/null || true

    if [ -f /tmp/test-cert.crt ]; then
        # Check certificate details
        CERT_CN=$(openssl x509 -in /tmp/test-cert.crt -noout -subject 2>/dev/null | sed 's/.*CN = //')
        CERT_ISSUER=$(openssl x509 -in /tmp/test-cert.crt -noout -issuer 2>/dev/null | sed 's/.*CN = //')
        CERT_EXPIRY=$(openssl x509 -in /tmp/test-cert.crt -noout -enddate 2>/dev/null | sed 's/notAfter=//')

        echo -e "  Certificate CN: ${CERT_CN}"
        echo -e "  Issued by: ${CERT_ISSUER}"
        echo -e "  Expires: ${CERT_EXPIRY}"

        if [ "$CERT_ISSUER" = "AIOps Substrate Intermediate CA" ]; then
            check_pass "Certificate issued by correct CA"
        else
            check_fail "Certificate not issued by expected CA (got: ${CERT_ISSUER})"
        fi

        rm -f /tmp/test-cert.crt
    else
        check_fail "Could not extract certificate for validation"
    fi
else
    echo -e "${YELLOW}  ℹ Test certificate not issued yet${NC}"
fi
echo ""

# -----------------------------------------------------------------------------
# Test 8: Vault Integration
# -----------------------------------------------------------------------------
echo -e "${YELLOW}Test 8: Checking Vault integration...${NC}"

# Check if cert-manager can authenticate with Vault
if kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager --tail=50 2>/dev/null | grep -q "vault"; then
    if kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager --tail=50 2>/dev/null | grep -i "error.*vault" &>/dev/null; then
        check_fail "cert-manager has Vault errors (check logs)"
    else
        check_pass "cert-manager is communicating with Vault"
    fi
else
    echo -e "${YELLOW}  ℹ No Vault-related logs found${NC}"
fi
echo ""

# -----------------------------------------------------------------------------
# Test 9: Certificate Renewal Configuration
# -----------------------------------------------------------------------------
echo -e "${YELLOW}Test 9: Checking certificate renewal configuration...${NC}"

if kubectl get certificate test-cert -n default &>/dev/null; then
    DURATION=$(kubectl get certificate test-cert -n default -o jsonpath='{.spec.duration}')
    RENEW_BEFORE=$(kubectl get certificate test-cert -n default -o jsonpath='{.spec.renewBefore}')

    echo -e "  Certificate duration: ${DURATION}"
    echo -e "  Renew before: ${RENEW_BEFORE}"

    if [ "$DURATION" = "720h" ] && [ "$RENEW_BEFORE" = "240h" ]; then
        check_pass "Certificate renewal configured correctly (30d cert, renew at 20d)"
    else
        check_fail "Certificate renewal misconfigured"
    fi
else
    echo -e "${YELLOW}  ℹ Test certificate not created yet${NC}"
fi
echo ""

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo -e "${BLUE}=== Verification Summary ===${NC}"
echo -e "Passed: ${GREEN}${PASS}${NC}"
echo -e "Failed: ${RED}${FAIL}${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed! cert-manager is working correctly.${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Check the output above for details.${NC}"
    echo ""
    echo "Common issues:"
    echo "1. If ClusterIssuers are not ready:"
    echo "   - Check Vault is accessible: kubectl get svc -n vault"
    echo "   - Check cert-manager logs: kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager"
    echo ""
    echo "2. If certificates are not issuing:"
    echo "   - Check certificate status: kubectl describe certificate <name> -n default"
    echo "   - Check certificate request: kubectl get certificaterequest -n default"
    echo ""
    echo "3. If Vault auth fails:"
    echo "   - Verify Kubernetes auth is enabled in Vault"
    echo "   - Verify cert-manager role exists in Vault"
    echo ""
    exit 1
fi
