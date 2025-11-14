#!/bin/bash
# ============================================================================
# Vault Deployment Script
# Deploys HashiCorp Vault for secrets management and PKI
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="vault"
RELEASE_NAME="vault"
CHART_REPO="hashicorp/vault"
CHART_VERSION=""  # Use latest by default

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl not found. Please install kubectl first."
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    log_error "helm not found. Please install helm first."
    exit 1
fi

log_info "Starting Vault deployment..."

# Create namespace if it doesn't exist
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    log_info "Creating namespace: $NAMESPACE"
    kubectl create namespace "$NAMESPACE"
else
    log_info "Namespace $NAMESPACE already exists"
fi

# Add HashiCorp Helm repository
log_info "Adding HashiCorp Helm repository..."
helm repo add hashicorp https://helm.releases.hashicorp.com 2>/dev/null || true
helm repo update

# Deploy Vault
log_info "Deploying Vault via Helm..."
helm upgrade --install "$RELEASE_NAME" "$CHART_REPO" \
    --namespace "$NAMESPACE" \
    --values "$SCRIPT_DIR/values.yaml" \
    --wait \
    --timeout 5m

# Wait for pods to be running (not necessarily ready, since Vault needs initialization)
log_info "Waiting for Vault pod to be running..."
kubectl wait --for=condition=Running \
    --timeout=300s \
    pod -l app.kubernetes.io/name=vault \
    -n "$NAMESPACE" || {
    log_warn "Vault pod is not running yet. Checking status..."
    kubectl get pods -n "$NAMESPACE"
}

# Check deployment status
log_info "Checking Vault deployment status..."
kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=vault

echo ""
log_info "✅ Vault deployed successfully!"
echo ""
log_warn "⚠️  IMPORTANT: Vault requires initialization and unsealing"
echo ""
echo "Next steps:"
echo ""
echo "1. Initialize Vault (run once):"
echo "   kubectl exec -n vault vault-0 -- vault operator init"
echo "   📝 SAVE THE UNSEAL KEYS AND ROOT TOKEN SECURELY!"
echo ""
echo "2. Unseal Vault (use 3 of 5 unseal keys):"
echo "   kubectl exec -n vault vault-0 -- vault operator unseal <key1>"
echo "   kubectl exec -n vault vault-0 -- vault operator unseal <key2>"
echo "   kubectl exec -n vault vault-0 -- vault operator unseal <key3>"
echo ""
echo "3. Check Vault status:"
echo "   kubectl exec -n vault vault-0 -- vault status"
echo ""
echo "4. Access Vault UI:"
echo "   kubectl port-forward -n vault svc/vault-ui 8200:8200"
echo "   Then open: http://localhost:8200"
echo ""
echo "5. After unsealing, run PKI initialization:"
echo "   cd $SCRIPT_DIR/../vault-pki"
echo "   ./init-vault-pki.sh"
echo ""
