#!/bin/bash
# PhotoPrism Deployment Script for K3s
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}PhotoPrism Deployment Script${NC}"
echo "==============================="
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl not found. Please install kubectl.${NC}"
    exit 1
fi

# Check cluster connection
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites check passed${NC}"
echo ""

# Deploy in order
echo -e "${YELLOW}Deploying PhotoPrism stack...${NC}"

# 1. Namespace
echo "1. Creating namespace..."
kubectl apply -f kubernetes/00-namespace.yaml

# 2. Storage
echo "2. Creating persistent volumes..."
kubectl apply -f kubernetes/01-storage.yaml

# 3. MinIO
echo "3. Deploying MinIO (S3-compatible storage)..."
kubectl apply -f kubernetes/02-minio.yaml

# Wait for MinIO to be ready
echo "   Waiting for MinIO to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/minio -n photoprism

# Initialize MinIO bucket
kubectl apply -f kubernetes/02-minio.yaml
kubectl wait --for=condition=complete --timeout=120s job/minio-init -n photoprism

# 4. MariaDB
echo "4. Deploying MariaDB..."
kubectl apply -f kubernetes/03-mariadb.yaml

# Wait for MariaDB to be ready
echo "   Waiting for MariaDB to be ready..."
kubectl wait --for=condition=ready --timeout=300s pod -l app=mariadb -n photoprism

# 5. PhotoPrism
echo "5. Deploying PhotoPrism..."
kubectl apply -f kubernetes/04-photoprism.yaml

# Wait for PhotoPrism to be ready
echo "   Waiting for PhotoPrism to be ready..."
kubectl wait --for=condition=available --timeout=600s deployment/photoprism -n photoprism

# 6. Ingress
echo "6. Creating Ingress (TLS)..."
kubectl apply -f kubernetes/05-ingress.yaml

# Optional: Authelia
read -p "Do you want to deploy Authelia for SSO/LDAP authentication? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "7. Deploying Authelia (SSO)..."
    kubectl apply -f kubernetes/06-authelia.yaml

    echo "   Waiting for Authelia to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/authelia -n authelia
fi

echo ""
echo -e "${GREEN}✓ PhotoPrism deployment complete!${NC}"
echo ""

# Get service information
echo "==============================="
echo -e "${YELLOW}Service Information:${NC}"
echo ""

PHOTOPRISM_URL=$(kubectl get ingress photoprism -n photoprism -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "photos.familyname.family")

echo "PhotoPrism URL: https://$PHOTOPRISM_URL"
echo ""
echo "Default admin credentials:"
echo "  Username: admin"
echo "  Password: (stored in secret/photoprism/admin)"
echo ""
echo -e "${RED}IMPORTANT: Change the admin password immediately!${NC}"
echo ""

# Get pod status
echo "Pod Status:"
kubectl get pods -n photoprism

echo ""
echo "==============================="
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Update DNS to point $PHOTOPRISM_URL to your ingress IP"
echo "2. Access PhotoPrism at https://$PHOTOPRISM_URL"
echo "3. Log in with admin credentials"
echo "4. Change admin password in Settings"
echo "5. Configure sharing and invite family members"
echo ""
echo "For more information:"
echo "  - Documentation: services/photoprism/docs/"
echo "  - Logs: kubectl logs -f deployment/photoprism -n photoprism"
echo "  - Status: kubectl get all -n photoprism"
echo ""
echo -e "${GREEN}Happy photo managing! 📸${NC}"
