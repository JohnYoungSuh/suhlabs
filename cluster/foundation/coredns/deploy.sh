#!/bin/bash
# ============================================================================
# CoreDNS Deployment Script
# Deploys CoreDNS with custom corp.local zone
# ============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Deploying CoreDNS for K8s cluster DNS${NC}"

# Check if helm is available
if ! command -v helm &> /dev/null; then
    echo -e "${RED}Error: helm is not installed${NC}"
    exit 1
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi

# Add CoreDNS Helm repo
echo -e "${YELLOW}Adding CoreDNS Helm repository...${NC}"
helm repo add coredns https://coredns.github.io/helm
helm repo update

# Install CoreDNS
echo -e "${YELLOW}Installing CoreDNS...${NC}"
helm upgrade --install coredns coredns/coredns \
  --namespace kube-system \
  --values values.yaml \
  --wait \
  --timeout 5m

# Wait for CoreDNS pods to be ready
echo -e "${YELLOW}Waiting for CoreDNS pods...${NC}"
kubectl wait --for=condition=ready pod \
  -l k8s-app=coredns \
  -n kube-system \
  --timeout=120s

# Test DNS resolution
echo -e "${GREEN}Testing DNS resolution...${NC}"

echo "1. Testing cluster.local resolution:"
kubectl run dns-test-cluster --image=busybox:1.36 --rm -it --restart=Never -- \
  nslookup kubernetes.default.svc.cluster.local || true

echo ""
echo "2. Testing corp.local resolution:"
kubectl run dns-test-corp --image=busybox:1.36 --rm -it --restart=Never -- \
  nslookup ns1.corp.local || true

echo ""
echo -e "${GREEN}CoreDNS deployment complete!${NC}"
echo ""
echo "Verification commands:"
echo "  kubectl get pods -n kube-system -l k8s-app=coredns"
echo "  kubectl logs -n kube-system -l k8s-app=coredns"
echo "  kubectl run -it dns-test --image=busybox:1.36 --rm --restart=Never -- nslookup kubernetes.default"
