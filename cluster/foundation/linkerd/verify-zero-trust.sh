#!/bin/bash
# ============================================================================
# Zero-Trust Verification Script
# Validates mTLS status and Network Policy enforcement.
# ============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }

# 1. Check Linkerd Status
log_info "Checking Linkerd Control Plane..."
if linkerd check; then
    log_success "Linkerd Control Plane is healthy"
else
    log_error "Linkerd check failed"
    exit 1
fi

# 2. Verify Proxy Injection
log_info "Verifying Proxy Injection..."
# We'll check if the 'ollama' pod has the linkerd-proxy container
# Assuming ollama is deployed in default namespace
POD_NAME=$(kubectl get pod -l app=ollama -n default -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$POD_NAME" ]; then
    log_error "Ollama pod not found. Is it deployed?"
    # Optional: Deploy a test pod if Ollama isn't there
else
    if kubectl get pod "$POD_NAME" -n default -o jsonpath='{.spec.containers[*].name}' | grep -q "linkerd-proxy"; then
        log_success "Ollama pod has Linkerd proxy injected"
    else
        log_error "Ollama pod is MISSING Linkerd proxy. Did you inject it?"
        echo "Run: kubectl get deploy ollama -n default -o yaml | linkerd inject - | kubectl apply -f -"
        exit 1
    fi
fi

# 3. Test Network Policies
log_info "Testing Network Policies..."

# specific test: DNS (Should be ALLOWED)
log_info "Testing DNS Access (Should be ALLOWED)..."
if kubectl run policy-test --image=busybox:1.36 --restart=Never --rm -it -- nslookup kubernetes.default >/dev/null 2>&1; then
    log_success "DNS Access allowed"
else
    log_error "DNS Access BLOCKED (Unexpected)"
    exit 1
fi

# specific test: Internet Access (Should be BLOCKED by default-deny-all)
log_info "Testing Internet Access (Should be BLOCKED)..."
if ! kubectl run policy-test-egress --image=curlimages/curl --restart=Never --rm -it -- --connect-timeout 2 http://google.com >/dev/null 2>&1; then
    log_success "Internet Access blocked (Expected)"
else
    log_error "Internet Access ALLOWED (Policy Failure!)"
    exit 1
fi

log_info "Zero-Trust Verification Complete! 🔒"
