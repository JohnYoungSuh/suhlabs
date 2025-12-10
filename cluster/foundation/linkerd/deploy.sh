#!/bin/bash
# ============================================================================
# Linkerd Service Mesh Deployment
# Automated installation with mTLS and Zero-Trust defaults.
# ============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check prerequisites
check_prereqs() {
    if ! command -v linkerd &> /dev/null; then
        log_info "Linkerd CLI not found. Installing..."
        curl --proto '=https' --tlsv1.2 -sSf L https://run.linkerd.io/install | sh
        export PATH=$PATH:$HOME/.linkerd2/bin
    fi
    
    if ! command -v step &> /dev/null; then
        log_warn "step CLI not found (recommended for cert generation)."
        # We'll use openssl as fallback if needed, or rely on linkerd install to generate self-signed
    fi
}

install_linkerd() {
    log_info "Checking Linkerd installation..."
    
    # Pre-check
    linkerd check --pre
    
    # Install CRDs
    log_info "Installing Linkerd CRDs..."
    linkerd install --crds | kubectl apply -f -
    
    # Install Control Plane
    log_info "Installing Linkerd Control Plane..."
    linkerd install | kubectl apply -f -
    
    # Wait for ready
    log_info "Waiting for Linkerd to be ready..."
    linkerd check
}

configure_network_policies() {
    log_info "Applying Default Deny Network Policies..."
    kubectl apply -f network-policies/default-deny.yaml
    
    log_info "Allowing DNS traffic..."
    kubectl apply -f network-policies/allow-dns.yaml
}

main() {
    check_prereqs
    install_linkerd
    configure_network_policies
    log_info "Linkerd Service Mesh deployed successfully! 🔒"
}

main "$@"
