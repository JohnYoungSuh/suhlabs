#!/bin/bash
# ============================================================================
# AI Ops Agent Deployment Script
# Deploys AI Ops Agent with automatic TLS certificate from Vault PKI
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="default"
IMAGE_NAME="ai-ops-agent"
IMAGE_TAG="0.1.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

echo ""
log_info "Starting AI Ops Agent deployment..."
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl not found. Please install kubectl first."
    exit 1
fi

# Check if docker is available
if ! command -v docker &> /dev/null; then
    log_error "docker not found. Please install docker first."
    exit 1
fi

# -----------------------------------------------------------------------------
# Step 1: Build Docker image
# -----------------------------------------------------------------------------
log_step "Building Docker image..."

cd "$SCRIPT_DIR"

docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" .
docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${IMAGE_NAME}:latest"

log_info "✓ Docker image built: ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""

# -----------------------------------------------------------------------------
# Step 2: Load image into cluster (for local development)
# -----------------------------------------------------------------------------
log_step "Loading image into cluster..."

# Try kind first (most common for local dev)
if command -v kind &> /dev/null && kind get clusters 2>/dev/null | grep -q .; then
    CLUSTER=$(kind get clusters | head -1)
    log_info "Detected kind cluster: $CLUSTER"
    kind load docker-image "${IMAGE_NAME}:${IMAGE_TAG}" --name "$CLUSTER"
    log_info "✓ Image loaded into kind cluster"

# Try k3d (another common local dev tool)
elif command -v k3d &> /dev/null && k3d cluster list 2>/dev/null | grep -q .; then
    CLUSTER=$(k3d cluster list -o json | jq -r '.[0].name' 2>/dev/null || echo "k3s-default")
    log_info "Detected k3d cluster: $CLUSTER"
    k3d image import "${IMAGE_NAME}:${IMAGE_TAG}" -c "$CLUSTER"
    log_info "✓ Image loaded into k3d cluster"

# Try minikube
elif command -v minikube &> /dev/null && minikube status &> /dev/null; then
    log_info "Detected minikube cluster"
    minikube image load "${IMAGE_NAME}:${IMAGE_TAG}"
    log_info "✓ Image loaded into minikube"

else
    log_warn "No local cluster detected (kind/k3d/minikube)"
    log_warn "Assuming remote cluster or image will be pushed to registry"
fi

echo ""

# -----------------------------------------------------------------------------
# Step 3: Check prerequisites
# -----------------------------------------------------------------------------
log_step "Checking prerequisites..."

# Check if cert-manager is installed
if ! kubectl get clusterissuer vault-issuer-ai-ops &>/dev/null; then
    log_error "ClusterIssuer 'vault-issuer-ai-ops' not found"
    log_error "Please deploy cert-manager first:"
    echo "  cd cluster/foundation/cert-manager && ./deploy.sh"
    exit 1
fi

log_info "✓ cert-manager ClusterIssuer found"
echo ""

# -----------------------------------------------------------------------------
# Step 4: Apply Certificate and wait for it to be issued
# -----------------------------------------------------------------------------
log_step "Applying Certificate resource..."

kubectl apply -f "${SCRIPT_DIR}/k8s/certificate.yaml"

log_info "✓ Certificate resource created"
echo ""

# -----------------------------------------------------------------------------
# Step 5: Wait for certificate to be issued
# -----------------------------------------------------------------------------
log_step "Waiting for certificate to be issued by cert-manager..."
log_info "This prevents race condition where deployment tries to mount secret before it exists"

timeout=120
elapsed=0
while [ $elapsed -lt $timeout ]; do
    if kubectl get certificate ai-ops-agent-cert -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q "True"; then
        log_info "✓ Certificate issued successfully by Vault PKI"
        break
    fi
    sleep 2
    elapsed=$((elapsed + 2))
    if [ $((elapsed % 10)) -eq 0 ]; then
        echo -n "."
    fi
done
echo ""

if [ $elapsed -ge $timeout ]; then
    log_error "Certificate not ready after ${timeout}s"
    log_error "Check certificate status:"
    echo "  kubectl describe certificate ai-ops-agent-cert -n $NAMESPACE"
    echo "  kubectl get certificaterequest -n $NAMESPACE"
    exit 1
fi

# Verify secret exists
if ! kubectl get secret ai-ops-agent-tls -n "$NAMESPACE" &>/dev/null; then
    log_error "Certificate shows Ready but secret not found!"
    exit 1
fi

log_info "✓ Secret ai-ops-agent-tls exists and is ready to mount"
echo ""

# -----------------------------------------------------------------------------
# Step 6: Apply Service and Deployment
# -----------------------------------------------------------------------------
log_step "Applying Service and Deployment manifests..."

kubectl apply -f "${SCRIPT_DIR}/k8s/service.yaml"
kubectl apply -f "${SCRIPT_DIR}/k8s/deployment.yaml"

log_info "✓ Manifests applied"
echo ""

# -----------------------------------------------------------------------------
# Step 7: Wait for deployment to be ready
# -----------------------------------------------------------------------------
log_step "Waiting for deployment to be ready..."

kubectl wait --for=condition=available \
    --timeout=120s \
    deployment/ai-ops-agent \
    -n "$NAMESPACE" || {
    log_warn "Deployment not ready after 120s"
    log_warn "Check pod status:"
    echo "  kubectl get pods -n $NAMESPACE -l app=ai-ops-agent"
    echo "  kubectl logs -n $NAMESPACE -l app=ai-ops-agent"
}

log_info "✓ Deployment ready"
echo ""

# -----------------------------------------------------------------------------
# Step 7: Display status
# -----------------------------------------------------------------------------
log_step "Deployment status:"
echo ""

echo "Pods:"
kubectl get pods -n "$NAMESPACE" -l app=ai-ops-agent

echo ""
echo "Service:"
kubectl get svc -n "$NAMESPACE" ai-ops-agent

echo ""
echo "Certificate:"
kubectl get certificate -n "$NAMESPACE" ai-ops-agent-cert

echo ""
log_info "✅ AI Ops Agent deployed successfully!"
echo ""

# -----------------------------------------------------------------------------
# Usage instructions
# -----------------------------------------------------------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Test the deployment:"
echo ""
echo "  # Port forward to access locally"
echo "  kubectl port-forward -n $NAMESPACE svc/ai-ops-agent 8000:8000"
echo ""
echo "  # Then in another terminal:"
echo "  curl http://localhost:8000"
echo "  curl http://localhost:8000/health"
echo ""
echo "View logs:"
echo "  kubectl logs -n $NAMESPACE -l app=ai-ops-agent -f"
echo ""
echo "Check certificate details:"
echo "  kubectl get secret ai-ops-agent-tls -n $NAMESPACE -o jsonpath='{.data.tls\\.crt}' | base64 -d | openssl x509 -text -noout"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
