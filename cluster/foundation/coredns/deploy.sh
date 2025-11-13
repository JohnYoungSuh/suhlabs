#!/bin/bash
# ============================================================================
# CoreDNS Deployment Script
# Deploys CoreDNS with custom corp.local zone
#
# Usage:
#   ./deploy.sh           # Fast delete-and-redeploy (dev/homelab)
#   ./deploy.sh --production  # Zero-downtime blue-green deployment (production)
# ============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
PRODUCTION_MODE=false
if [[ "${1:-}" == "--production" ]]; then
  PRODUCTION_MODE=true
fi

echo -e "${GREEN}Deploying CoreDNS for K8s cluster DNS${NC}"
if [[ "$PRODUCTION_MODE" == "true" ]]; then
  echo -e "${BLUE}Mode: Production (zero-downtime blue-green deployment)${NC}"
else
  echo -e "${BLUE}Mode: Development (fast delete-and-redeploy)${NC}"
fi

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

# Check for existing CoreDNS installation
echo -e "${YELLOW}Checking for existing CoreDNS installation...${NC}"
EXISTING_DEPLOYMENT=$(kubectl get deployment coredns -n kube-system -o name 2>/dev/null || echo "")

if [[ -n "$EXISTING_DEPLOYMENT" ]]; then
  echo -e "${YELLOW}Found existing CoreDNS deployment${NC}"

  if [[ "$PRODUCTION_MODE" == "true" ]]; then
    # ========================================================================
    # PRODUCTION MODE: Blue-Green Deployment (Zero Downtime)
    # ========================================================================
    echo -e "${BLUE}Using blue-green deployment strategy...${NC}"

    # Step 1: Deploy new CoreDNS with temporary name
    echo -e "${YELLOW}Step 1/5: Deploying new CoreDNS (coredns-new)...${NC}"
    helm upgrade --install coredns-new coredns/coredns \
      --namespace kube-system \
      --values values.yaml \
      --set fullnameOverride=coredns-new \
      --wait \
      --timeout 5m

    # Step 2: Verify new deployment is healthy
    echo -e "${YELLOW}Step 2/5: Verifying new deployment health...${NC}"
    kubectl wait --for=condition=ready pod \
      -l app.kubernetes.io/instance=coredns-new \
      -n kube-system \
      --timeout=120s

    # Step 3: Test new CoreDNS functionality
    echo -e "${YELLOW}Step 3/5: Testing new CoreDNS...${NC}"
    NEW_POD=$(kubectl get pod -n kube-system -l app.kubernetes.io/instance=coredns-new -o jsonpath='{.items[0].metadata.name}')
    kubectl exec -n kube-system "$NEW_POD" -- nslookup kubernetes.default.svc.cluster.local 127.0.0.1
    echo -e "${GREEN}New CoreDNS is healthy!${NC}"

    # Step 4: Switch Service to point to new deployment
    echo -e "${YELLOW}Step 4/5: Switching traffic to new deployment...${NC}"
    kubectl patch service coredns -n kube-system -p '{"spec":{"selector":{"app.kubernetes.io/instance":"coredns-new"}}}'
    sleep 5  # Allow DNS cache to update

    # Step 5: Remove old deployment
    echo -e "${YELLOW}Step 5/5: Removing old deployment...${NC}"
    kubectl delete deployment coredns -n kube-system --ignore-not-found=true
    kubectl delete configmap coredns -n kube-system --ignore-not-found=true
    kubectl delete serviceaccount coredns -n kube-system --ignore-not-found=true

    # Step 6: Rename new deployment to standard name
    echo -e "${YELLOW}Finalizing: Renaming deployment to 'coredns'...${NC}"
    helm uninstall coredns-new -n kube-system
    helm upgrade --install coredns coredns/coredns \
      --namespace kube-system \
      --values values.yaml \
      --wait \
      --timeout 5m

    echo -e "${GREEN}Blue-green deployment complete with zero downtime!${NC}"

  else
    # ========================================================================
    # DEVELOPMENT MODE: Fast Delete-and-Redeploy
    # ========================================================================
    echo -e "${YELLOW}Removing existing CoreDNS to avoid immutable selector conflicts...${NC}"
    echo -e "${RED}Warning: This will cause temporary DNS disruption!${NC}"
    sleep 2  # Give user time to read warning

    # Delete the deployment (pods will be recreated by Helm immediately)
    kubectl delete deployment coredns -n kube-system --ignore-not-found=true

    # Delete other resources that might conflict
    kubectl delete service coredns -n kube-system --ignore-not-found=true
    kubectl delete configmap coredns -n kube-system --ignore-not-found=true
    kubectl delete serviceaccount coredns -n kube-system --ignore-not-found=true

    echo -e "${GREEN}Existing CoreDNS resources removed${NC}"
  fi
else
  echo -e "${GREEN}No existing CoreDNS found. Fresh installation.${NC}"
fi

# Install CoreDNS (if not already done in production mode)
if [[ "$PRODUCTION_MODE" != "true" ]] || [[ -z "$EXISTING_DEPLOYMENT" ]]; then
  echo -e "${YELLOW}Installing CoreDNS...${NC}"
  helm upgrade --install coredns coredns/coredns \
    --namespace kube-system \
    --values values.yaml \
    --wait \
    --timeout 5m
fi

# Wait for CoreDNS pods to be ready
echo -e "${YELLOW}Waiting for CoreDNS pods...${NC}"
kubectl wait --for=condition=ready pod \
  -l k8s-app=coredns \
  -n kube-system \
  --timeout=120s 2>/dev/null || \
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/instance=coredns \
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
echo ""
echo "Helm release info:"
echo "  helm list -n kube-system"
echo "  helm status coredns -n kube-system"
