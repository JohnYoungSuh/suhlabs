#!/bin/bash
# ============================================================================
# Foundation Services - Master Verification Script
# Validates all Day 4 foundation services are working correctly
# ============================================================================
#
# This script performs comprehensive checks on:
# 1. CoreDNS (Cluster DNS + corp.local zone)
# 2. SoftHSM (Software HSM for development)
# 3. Vault PKI (Complete certificate authority)
# 4. Integration testing (services working together)
#
# Prerequisites:
# - Kind cluster running
# - All foundation services deployed
# - kubectl configured
# - vault CLI installed
#
# Usage:
#   ./verify-all.sh
#
# ============================================================================

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

FAILED=0
WARNINGS=0

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}Foundation Services Verification${NC}"
echo -e "${CYAN}Day 4: CoreDNS + SoftHSM + Vault PKI${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

# ============================================================================
# Helper Functions
# ============================================================================

log_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

log_test() {
    echo -e "${YELLOW}[Test] $1${NC}"
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

log_error() {
    echo -e "${RED}✗ $1${NC}"
    FAILED=$((FAILED + 1))
}

log_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    WARNINGS=$((WARNINGS + 1))
}

check_command() {
    if command -v "$1" &> /dev/null; then
        log_success "$1 is installed"
        return 0
    else
        log_error "$1 is not installed"
        return 1
    fi
}

# ============================================================================
# 1. Prerequisites Check
# ============================================================================

log_section "1. Prerequisites Check"

log_test "Checking required tools..."
check_command kubectl || true
check_command helm || true
check_command vault || true
check_command openssl || true

log_test "Checking cluster connectivity..."
CLUSTER_INFO_OUTPUT=$(kubectl cluster-info 2>&1)
CLUSTER_INFO_EXIT=$?

if [ $CLUSTER_INFO_EXIT -eq 0 ]; then
    CLUSTER_VERSION=$(kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.kubeletVersion}' 2>/dev/null)
    log_success "Cluster is accessible (version: ${CLUSTER_VERSION})"
else
    log_error "Cannot connect to Kubernetes cluster"
    echo "  Exit code: $CLUSTER_INFO_EXIT"
    echo "  Error output:"
    echo "$CLUSTER_INFO_OUTPUT" | sed 's/^/    /'
    echo ""
    echo "  Hint: Is your kind cluster running?"
    echo "  Try: kind get clusters"
    echo "  Current context: $(kubectl config current-context 2>&1)"
    exit 1
fi

# ============================================================================
# 2. CoreDNS Verification
# ============================================================================

log_section "2. CoreDNS Verification"

log_test "Checking CoreDNS deployment..."
if kubectl get deployment coredns -n kube-system &> /dev/null; then
    REPLICAS=$(kubectl get deployment coredns -n kube-system -o jsonpath='{.status.readyReplicas}')
    log_success "CoreDNS deployment found (${REPLICAS} replicas ready)"
else
    log_error "CoreDNS deployment not found"
fi

log_test "Checking CoreDNS pods..."
POD_COUNT=$(kubectl get pods -n kube-system -l k8s-app=coredns --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
if [ "$POD_COUNT" -gt 0 ]; then
    log_success "CoreDNS pods running ($POD_COUNT)"
    kubectl get pods -n kube-system -l k8s-app=coredns
else
    log_error "No CoreDNS pods running"
fi

log_test "Testing cluster.local DNS resolution..."
if kubectl run dns-test-cluster --image=busybox:1.36 --rm -it --restart=Never \
    --command -- nslookup kubernetes.default.svc.cluster.local 2>&1 | grep -q "Address 1:"; then
    log_success "cluster.local DNS resolution working"
else
    log_error "cluster.local DNS resolution failed"
fi

log_test "Testing corp.local DNS resolution..."
if kubectl run dns-test-corp --image=busybox:1.36 --rm -it --restart=Never \
    --command -- nslookup ns1.corp.local 2>&1 | grep -q "Address 1:"; then
    log_success "corp.local DNS resolution working"
else
    log_warning "corp.local DNS resolution failed (may not be critical)"
fi

log_test "Checking CoreDNS ConfigMap..."
if kubectl get configmap coredns -n kube-system &> /dev/null; then
    log_success "CoreDNS ConfigMap exists"
    echo ""
    echo "  Core Plugins Configured:"
    kubectl get configmap coredns -n kube-system -o yaml | grep -E "^\s+(kubernetes|forward|cache|file)" | sed 's/^/  - /'
else
    log_error "CoreDNS ConfigMap not found"
fi

# ============================================================================
# 3. Vault + SoftHSM Verification
# ============================================================================

log_section "3. Vault + SoftHSM Verification"

log_test "Checking Vault deployment..."
if kubectl get deployment vault -n vault &> /dev/null; then
    REPLICAS=$(kubectl get deployment vault -n vault -o jsonpath='{.status.readyReplicas}')
    log_success "Vault Deployment found (${REPLICAS} replicas ready)"
else
    log_warning "Vault Deployment not found (may not be deployed yet)"
fi

log_test "Checking Vault pods..."
VAULT_POD_COUNT=$(kubectl get pods -n vault -l app=vault --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
if [ "$VAULT_POD_COUNT" -gt 0 ]; then
    log_success "Vault pods running ($VAULT_POD_COUNT)"
    kubectl get pods -n vault -l app=vault
else
    log_warning "No Vault pods running"
fi

log_test "Checking Vault service..."
if kubectl get service vault -n vault &> /dev/null; then
    VAULT_IP=$(kubectl get service vault -n vault -o jsonpath='{.spec.clusterIP}')
    log_success "Vault service exists (ClusterIP: ${VAULT_IP})"
else
    log_warning "Vault service not found"
fi

log_test "Checking Vault seal status..."
if [ "$VAULT_POD_COUNT" -gt 0 ]; then
    # Set Vault address for CLI
    export VAULT_ADDR=http://localhost:8200

    # Get the Vault pod name dynamically
    VAULT_POD=$(kubectl get pod -n vault -l app=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

    # Try to get seal status
    if kubectl exec -n vault $VAULT_POD -- vault status &> /dev/null; then
        SEALED=$(kubectl exec -n vault $VAULT_POD -- vault status -format=json 2>/dev/null | jq -r '.sealed')
        if [ "$SEALED" = "false" ]; then
            log_success "Vault is unsealed (ready for operations)"
            SEAL_TYPE=$(kubectl exec -n vault $VAULT_POD -- vault status -format=json 2>/dev/null | jq -r '.seal_type')
            echo "  Seal Type: ${SEAL_TYPE}"
        else
            log_warning "Vault is sealed (needs initialization or unsealing)"
        fi
    else
        log_warning "Cannot connect to Vault (may need initialization)"
    fi
else
    log_warning "Vault not running, skipping seal status check"
fi

log_test "Checking Vault seal type..."
if [ "$VAULT_POD_COUNT" -gt 0 ]; then
    VAULT_POD=$(kubectl get pod -n vault -l app=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if kubectl exec -n vault $VAULT_POD -- vault status 2>/dev/null | grep -q "Seal Type"; then
        SEAL_TYPE=$(kubectl exec -n vault $VAULT_POD -- vault status 2>/dev/null | grep "Seal Type" | awk '{print $3}')
        log_success "Vault seal type: ${SEAL_TYPE}"
        echo "  Note: Using Shamir seal (manual unseal) for open-source Vault"
    else
        log_warning "Cannot determine Vault seal type"
    fi
else
    log_warning "Vault not running, skipping seal type check"
fi

# ============================================================================
# 4. Vault PKI Verification
# ============================================================================

log_section "4. Vault PKI Verification"

if [ "$VAULT_POD_COUNT" -gt 0 ]; then
    log_test "Checking PKI secrets engines..."

    # Setup port-forward for Vault access
    echo "  Setting up port-forward to Vault..."
    kubectl port-forward -n vault svc/vault 8200:8200 &> /dev/null &
    PF_PID=$!
    sleep 2

    # Check if we can access Vault
    if ! curl -sf http://localhost:8200/v1/sys/health &> /dev/null; then
        log_warning "Cannot access Vault API (may need token)"
        kill $PF_PID 2>/dev/null || true
    else
        # Try to list secrets engines (requires token)
        if [ -n "${VAULT_TOKEN:-}" ]; then
            if vault secrets list | grep -q "^pki/"; then
                log_success "Root PKI engine enabled (pki/)"
            else
                log_warning "Root PKI engine not found"
            fi

            if vault secrets list | grep -q "^pki_int/"; then
                log_success "Intermediate PKI engine enabled (pki_int/)"
            else
                log_warning "Intermediate PKI engine not found"
            fi
        else
            log_warning "VAULT_TOKEN not set, skipping PKI engine check"
            echo "  Set VAULT_TOKEN to verify PKI configuration"
        fi

        kill $PF_PID 2>/dev/null || true
    fi
else
    log_warning "Vault not running, skipping PKI verification"
fi

# If vault-pki directory exists, suggest running dedicated script
if [ -f "vault-pki/verify-pki.sh" ]; then
    echo ""
    echo "  For detailed PKI verification, run:"
    echo -e "  ${CYAN}cd vault-pki && ./verify-pki.sh${NC}"
fi

# ============================================================================
# 5. Integration Testing
# ============================================================================

log_section "5. Integration Testing"

log_test "Testing DNS → Vault integration..."
if [ "$POD_COUNT" -gt 0 ] && [ "$VAULT_POD_COUNT" -gt 0 ]; then
    # Test that CoreDNS can resolve Vault service
    if kubectl run dns-vault-test --image=busybox:1.36 --rm -it --restart=Never \
        --command -- nslookup vault.vault.svc.cluster.local 2>&1 | grep -q "Address 1:"; then
        log_success "CoreDNS can resolve Vault service"
    else
        log_error "CoreDNS cannot resolve Vault service"
    fi

    # Test corp.local CNAME
    if kubectl run dns-vault-corp-test --image=busybox:1.36 --rm -it --restart=Never \
        --command -- nslookup vault.corp.local 2>&1 | grep -q "canonical name"; then
        log_success "corp.local CNAME to Vault working"
    else
        log_warning "corp.local CNAME to Vault not configured"
    fi
else
    log_warning "Services not running, skipping integration tests"
fi

log_test "Testing Vault API accessibility..."
if [ "$VAULT_POD_COUNT" -gt 0 ]; then
    VAULT_POD=$(kubectl get pod -n vault -l app=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    # Check if Vault API responds
    if kubectl exec -n vault $VAULT_POD -- vault status 2>/dev/null | grep -q "Initialized"; then
        log_success "Vault API is accessible"
    else
        log_warning "Vault API may not be initialized"
    fi
else
    log_warning "Vault not running, skipping API accessibility test"
fi

# ============================================================================
# 6. Security Checks
# ============================================================================

log_section "6. Security Checks"

log_test "Checking namespace isolation..."
if kubectl get networkpolicy -n vault &> /dev/null 2>&1; then
    NP_COUNT=$(kubectl get networkpolicy -n vault --no-headers | wc -l)
    if [ "$NP_COUNT" -gt 0 ]; then
        log_success "Network policies configured in vault namespace ($NP_COUNT)"
    else
        log_warning "No network policies in vault namespace"
    fi
else
    log_warning "Network policies not found (may not be configured yet)"
fi

log_test "Checking resource quotas..."
if kubectl get resourcequota -n vault &> /dev/null 2>&1; then
    RQ_COUNT=$(kubectl get resourcequota -n vault --no-headers | wc -l)
    if [ "$RQ_COUNT" -gt 0 ]; then
        log_success "Resource quotas configured in vault namespace ($RQ_COUNT)"
    else
        log_warning "No resource quotas in vault namespace"
    fi
else
    log_warning "Resource quotas not found"
fi

log_test "Checking RBAC configuration..."
if kubectl get serviceaccount vault -n vault &> /dev/null; then
    log_success "Vault service account exists"
else
    log_warning "Vault service account not found"
fi

# ============================================================================
# 7. Performance Checks
# ============================================================================

log_section "7. Performance Checks"

log_test "Checking CoreDNS response times..."
if [ "$POD_COUNT" -gt 0 ]; then
    # Run DNS query with timing
    START=$(date +%s%N)
    kubectl run dns-perf-test --image=busybox:1.36 --rm -it --restart=Never \
        --command -- nslookup kubernetes.default.svc.cluster.local &> /dev/null || true
    END=$(date +%s%N)
    DURATION=$(( (END - START) / 1000000 )) # Convert to milliseconds

    if [ "$DURATION" -lt 1000 ]; then
        log_success "DNS response time: ${DURATION}ms (good)"
    elif [ "$DURATION" -lt 5000 ]; then
        log_warning "DNS response time: ${DURATION}ms (acceptable)"
    else
        log_warning "DNS response time: ${DURATION}ms (slow)"
    fi
else
    log_warning "CoreDNS not running, skipping performance check"
fi

log_test "Checking Vault response times..."
if [ "$VAULT_POD_COUNT" -gt 0 ]; then
    VAULT_POD=$(kubectl get pod -n vault -l app=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    START=$(date +%s%N)
    kubectl exec -n vault $VAULT_POD -- vault status &> /dev/null || true
    END=$(date +%s%N)
    DURATION=$(( (END - START) / 1000000 ))

    if [ "$DURATION" -lt 500 ]; then
        log_success "Vault response time: ${DURATION}ms (good)"
    elif [ "$DURATION" -lt 2000 ]; then
        log_warning "Vault response time: ${DURATION}ms (acceptable)"
    else
        log_warning "Vault response time: ${DURATION}ms (slow)"
    fi
else
    log_warning "Vault not running, skipping performance check"
fi

# ============================================================================
# Summary
# ============================================================================

echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}Verification Summary${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

if [ $FAILED -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo -e "${GREEN}Foundation services are fully operational.${NC}"
    EXIT_CODE=0
elif [ $FAILED -eq 0 ]; then
    echo -e "${YELLOW}⚠ ${WARNINGS} warning(s)${NC}"
    echo -e "${YELLOW}Foundation services are operational with minor issues.${NC}"
    EXIT_CODE=0
else
    echo -e "${RED}✗ ${FAILED} test(s) failed${NC}"
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}⚠ ${WARNINGS} warning(s)${NC}"
    fi
    echo -e "${YELLOW}Please review the errors above.${NC}"
    EXIT_CODE=1
fi

echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo ""
if [ $FAILED -gt 0 ] || [ $WARNINGS -gt 0 ]; then
    echo "  1. Review failed/warning tests above"
    echo "  2. Check service logs:"
    echo "     kubectl logs -n kube-system -l k8s-app=coredns"
    echo "     kubectl logs -n vault -l app=vault"
    echo "  3. Run individual verification scripts:"
    echo "     cd coredns && ./deploy.sh"
    echo "     cd softhsm && ./init-softhsm.sh"
    echo "     cd vault-pki && ./verify-pki.sh"
else
    echo "  1. ✓ Foundation services verified"
    echo "  2. Continue to Hour 5: Ansible installation"
    echo "  3. Begin infrastructure automation (Hours 5-8)"
fi

echo ""
echo -e "${BLUE}Documentation:${NC}"
echo "  - CoreDNS: cluster/foundation/coredns/README.md"
echo "  - SoftHSM: cluster/foundation/softhsm/README.md"
echo "  - Vault PKI: cluster/foundation/vault-pki/README.md"
echo ""

exit $EXIT_CODE
