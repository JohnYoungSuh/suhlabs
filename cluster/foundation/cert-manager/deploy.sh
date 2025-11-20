#!/bin/bash
# =============================================================================
# Deploy cert-manager with Vault Integration
# Day 5: Automatic Certificate Issuance
# =============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

CERT_MANAGER_VERSION="v1.13.3"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}=== Day 5: Deploying cert-manager ===${NC}"

# -----------------------------------------------------------------------------
# Step 1: Install cert-manager
# -----------------------------------------------------------------------------
echo -e "${YELLOW}Step 1: Installing cert-manager ${CERT_MANAGER_VERSION}...${NC}"

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml

echo -e "${GREEN}✓ cert-manager installed${NC}"

# -----------------------------------------------------------------------------
# Step 2: Wait for cert-manager to be ready
# -----------------------------------------------------------------------------
echo -e "${YELLOW}Step 2: Waiting for cert-manager pods to be ready...${NC}"

kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/instance=cert-manager \
  -n cert-manager \
  --timeout=120s

echo -e "${GREEN}✓ cert-manager is ready${NC}"

# -----------------------------------------------------------------------------
# Step 3: Verify cert-manager
# -----------------------------------------------------------------------------
echo -e "${YELLOW}Step 3: Verifying cert-manager components...${NC}"

echo "Checking cert-manager pods:"
kubectl get pods -n cert-manager

echo ""
echo "Checking cert-manager CRDs:"
kubectl get crd | grep cert-manager | head -5

echo -e "${GREEN}✓ cert-manager verification complete${NC}"

# -----------------------------------------------------------------------------
# Step 4: Configure Vault for cert-manager
# -----------------------------------------------------------------------------
echo -e "${YELLOW}Step 4: Configuring Vault for cert-manager...${NC}"

# Check if Vault is accessible
if ! kubectl get pod -n vault -l app=vault &>/dev/null; then
    echo -e "${RED}✗ Vault pod not found. Please deploy Vault first.${NC}"
    echo "Run: cd cluster/foundation/softhsm && kubectl apply -f vault-deployment.yaml"
    exit 1
fi

# Port-forward to Vault (run in background)
echo "Setting up Vault port-forward..."
kubectl port-forward -n vault svc/vault 8200:8200 &
VAULT_PF_PID=$!
sleep 3

export VAULT_ADDR='http://localhost:8200'

# Note: User needs to set VAULT_TOKEN
if [ -z "${VAULT_TOKEN:-}" ]; then
    echo -e "${YELLOW}Please set VAULT_TOKEN environment variable:${NC}"
    echo "export VAULT_TOKEN=<your-root-token>"
    echo ""
    echo "You can find your root token from the Vault initialization output."
    echo "Then re-run this script."
    kill $VAULT_PF_PID 2>/dev/null || true
    exit 1
fi

# Enable Kubernetes auth if not already enabled
if ! vault auth list | grep -q kubernetes; then
    echo "Enabling Kubernetes auth..."
    vault auth enable kubernetes
fi

# Configure Kubernetes auth
echo "Configuring Kubernetes auth..."

# Extract Kubernetes CA cert and token from Vault pod
echo "Extracting Kubernetes credentials from Vault pod..."

# Wait for Vault pod to be ready
echo "Waiting for Vault pod to be ready..."
kubectl wait --for=condition=ready pod -l app=vault -n vault --timeout=120s || {
    echo -e "${RED}✗ Vault pod not ready${NC}"
    kubectl get pods -n vault
    exit 1
}

VAULT_POD=$(kubectl get pod -n vault -l app=vault -o jsonpath='{.items[0].metadata.name}')
if [ -z "$VAULT_POD" ]; then
    echo -e "${RED}✗ No Vault pod found with label app=vault${NC}"
    kubectl get pods -n vault --show-labels
    exit 1
fi
echo "Found Vault pod: $VAULT_POD"

# Get the service account token and CA cert from inside the Vault pod
K8S_CA_CERT=$(kubectl exec -n vault $VAULT_POD -- cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt)
K8S_TOKEN=$(kubectl exec -n vault $VAULT_POD -- cat /var/run/secrets/kubernetes.io/serviceaccount/token)

# Configure Vault Kubernetes auth with proper credentials
vault write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc:443" \
    kubernetes_ca_cert="$K8S_CA_CERT" \
    token_reviewer_jwt="$K8S_TOKEN"

# Create cert-manager policy
echo "Creating cert-manager policy..."
cat > /tmp/cert-manager-policy.hcl <<EOF
# Allow cert-manager to sign certificates using intermediate CA
path "pki_int/sign/ai-ops-agent" {
  capabilities = ["create", "update"]
}

path "pki_int/sign/kubernetes" {
  capabilities = ["create", "update"]
}

path "pki_int/sign/cert-manager" {
  capabilities = ["create", "update"]
}

# Allow cert-manager to issue certificates
path "pki_int/issue/ai-ops-agent" {
  capabilities = ["create", "update"]
}

path "pki_int/issue/kubernetes" {
  capabilities = ["create", "update"]
}

path "pki_int/issue/cert-manager" {
  capabilities = ["create", "update"]
}
EOF

vault policy write cert-manager /tmp/cert-manager-policy.hcl
rm /tmp/cert-manager-policy.hcl

# Create Kubernetes role for cert-manager
echo "Creating Kubernetes role for cert-manager..."
vault write auth/kubernetes/role/cert-manager \
    bound_service_account_names=cert-manager \
    bound_service_account_namespaces=cert-manager \
    policies=cert-manager \
    ttl=24h

# Kill port-forward
kill $VAULT_PF_PID 2>/dev/null || true

echo -e "${GREEN}✓ Vault configured for cert-manager${NC}"

# -----------------------------------------------------------------------------
# Step 5: Apply Vault ClusterIssuer
# -----------------------------------------------------------------------------
echo -e "${YELLOW}Step 5: Applying Vault ClusterIssuer...${NC}"

kubectl apply -f "${SCRIPT_DIR}/vault-issuer.yaml"

echo -e "${GREEN}✓ Vault ClusterIssuer created${NC}"

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
echo -e "${GREEN}=== cert-manager Deployment Complete ===${NC}"
echo ""
echo "Next steps:"
echo "1. Test certificate issuance: kubectl apply -f ${SCRIPT_DIR}/test-certificate.yaml"
echo "2. Verify certificate: kubectl get certificate -n default"
echo "3. Check certificate details: kubectl describe certificate test-cert -n default"
echo ""
echo "Run verification: ${SCRIPT_DIR}/verify-cert-manager.sh"
