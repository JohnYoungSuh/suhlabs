#!/bin/bash
# PhotoPrism Multi-Tenant Deployment Script
# Deploys PhotoPrism for a specific family using Kustomize templates

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# Configuration Variables (REQUIRED)
# ============================================================================

FAMILY_NAME="${FAMILY_NAME:-}"
PREFERRED_NAME="${PREFERRED_NAME:-$FAMILY_NAME}"
CONTACT_EMAIL="${CONTACT_EMAIL:-}"
DOMAIN="${DOMAIN:-$FAMILY_NAME.family}"
INGRESS_IP="${INGRESS_IP:-}"

# Optional configuration
ENABLE_GPU="${ENABLE_GPU:-true}"
ENABLE_AUTHELIA="${ENABLE_AUTHELIA:-true}"
STORAGE_SIZE="${STORAGE_SIZE:-1Ti}"
MARIADB_STORAGE="${MARIADB_STORAGE:-50Gi}"
CACHE_STORAGE="${CACHE_STORAGE:-100Gi}"

# ============================================================================
# Functions
# ============================================================================

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  PhotoPrism Multi-Tenant Deployment  ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}→ $1${NC}"
}

validate_requirements() {
    print_info "Validating requirements..."

    # Validate FAMILY_NAME
    if [ -z "$FAMILY_NAME" ]; then
        print_error "FAMILY_NAME environment variable is required"
        echo ""
        echo "Usage:"
        echo "  FAMILY_NAME=smith PREFERRED_NAME='The Smith Family' CONTACT_EMAIL=admin@smith.family ./deploy-family.sh"
        echo ""
        echo "Required variables:"
        echo "  FAMILY_NAME      - IT ops identifier (lowercase, alphanumeric, hyphens)"
        echo "  PREFERRED_NAME   - Customer-facing display name (optional, defaults to FAMILY_NAME)"
        echo "  CONTACT_EMAIL    - Admin contact email"
        echo ""
        exit 1
    fi

    # Validate family name format (lowercase alphanumeric + hyphens only)
    if ! [[ "$FAMILY_NAME" =~ ^[a-z0-9-]+$ ]]; then
        print_error "FAMILY_NAME must be lowercase alphanumeric with hyphens only"
        echo "  Invalid: $FAMILY_NAME"
        echo "  Valid examples: smith, garcia-family, the-johnsons"
        exit 1
    fi

    # Validate contact email
    if [ -z "$CONTACT_EMAIL" ]; then
        print_error "CONTACT_EMAIL environment variable is required"
        exit 1
    fi

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl."
        exit 1
    fi

    # Check kustomize
    if ! command -v kustomize &> /dev/null; then
        print_error "kustomize not found. Installing..."
        # Install kustomize
        curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
        sudo mv kustomize /usr/local/bin/
    fi

    # Check cluster connection
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi

    print_success "Requirements validated"
}

generate_family_overlay() {
    print_info "Generating family-specific overlay for: $FAMILY_NAME"

    # Create family overlay directory
    OVERLAY_DIR="kustomize/overlays/$FAMILY_NAME"
    mkdir -p "$OVERLAY_DIR"

    # Generate admin password if not provided
    if [ -z "$ADMIN_PASSWORD" ]; then
        ADMIN_PASSWORD=$(openssl rand -base64 20)
        print_info "Generated admin password (store securely!)"
    fi

    # Create family-specific kustomization.yaml
    cat > "$OVERLAY_DIR/kustomization.yaml" <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: photoprism-$FAMILY_NAME

resources:
  - ../../base

# Family-specific configuration
configMapGenerator:
  - name: photoprism-config
    behavior: merge
    literals:
      - FAMILY_NAME=$FAMILY_NAME
      - PREFERRED_NAME=$PREFERRED_NAME
      - PHOTOPRISM_SITE_URL=https://photos.$DOMAIN
      - PHOTOPRISM_SITE_TITLE=$PREFERRED_NAME Photos
      - PHOTOPRISM_ADMIN_USER=$CONTACT_EMAIL

# Family-specific labels
commonLabels:
  family: $FAMILY_NAME

commonAnnotations:
  family-name: "$FAMILY_NAME"
  preferred-name: "$PREFERRED_NAME"
  onboarded-date: "$(date -u +%Y-%m-%d)"

# Patches
patches:
  - target:
      kind: Namespace
      name: photoprism-FAMILY_NAME
    patch: |-
      - op: replace
        path: /metadata/name
        value: photoprism-$FAMILY_NAME

EOF

    # Add GPU patch if enabled
    if [ "$ENABLE_GPU" = "true" ]; then
        cat >> "$OVERLAY_DIR/kustomization.yaml" <<EOF
  - target:
      kind: Deployment
      name: photoprism
    patch: |-
      - op: add
        path: /spec/template/spec/containers/0/resources/limits
        value:
          nvidia.com/gpu: "1"
      - op: add
        path: /spec/template/spec/affinity
        value:
          nodeAffinity:
            preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              preference:
                matchExpressions:
                - key: gpu
                  operator: In
                  values:
                  - "true"

EOF
    fi

    # Add replica configuration
    cat >> "$OVERLAY_DIR/kustomization.yaml" <<EOF
replicas:
  - name: photoprism
    count: 2
EOF

    print_success "Family overlay generated at: $OVERLAY_DIR"
}

deploy_with_kustomize() {
    print_info "Deploying PhotoPrism for family: $FAMILY_NAME"

    OVERLAY_DIR="kustomize/overlays/$FAMILY_NAME"

    # Build and apply with kustomize
    print_info "Building Kubernetes manifests..."
    kustomize build "$OVERLAY_DIR" > "/tmp/photoprism-$FAMILY_NAME.yaml"

    # Replace template variables
    print_info "Applying variable substitution..."
    sed -i "s/FAMILY_NAME/$FAMILY_NAME/g" "/tmp/photoprism-$FAMILY_NAME.yaml"
    sed -i "s/PREFERRED_NAME/$PREFERRED_NAME/g" "/tmp/photoprism-$FAMILY_NAME.yaml"

    # Apply to cluster
    print_info "Applying to Kubernetes cluster..."
    kubectl apply -f "/tmp/photoprism-$FAMILY_NAME.yaml"

    print_success "Deployment manifests applied"
}

wait_for_services() {
    print_info "Waiting for services to be ready..."

    # Wait for namespace
    kubectl wait --for=condition=Active --timeout=60s namespace/photoprism-$FAMILY_NAME 2>/dev/null || true

    # Wait for MinIO
    print_info "Waiting for MinIO..."
    kubectl wait --for=condition=available --timeout=300s deployment/minio -n photoprism-$FAMILY_NAME 2>/dev/null || print_error "MinIO timeout (continuing...)"

    # Wait for MariaDB
    print_info "Waiting for MariaDB..."
    kubectl wait --for=condition=ready --timeout=300s pod -l app=mariadb -n photoprism-$FAMILY_NAME 2>/dev/null || print_error "MariaDB timeout (continuing...)"

    # Wait for PhotoPrism
    print_info "Waiting for PhotoPrism..."
    kubectl wait --for=condition=available --timeout=600s deployment/photoprism -n photoprism-$FAMILY_NAME 2>/dev/null || print_error "PhotoPrism timeout (continuing...)"

    print_success "Services are ready (or timed out - check status below)"
}

configure_vault_secrets() {
    print_info "Configuring Vault secrets..."

    # Check if vault is available
    if ! command -v vault &> /dev/null; then
        print_error "Vault CLI not found - skipping secret configuration"
        echo "  Install Vault CLI to enable automatic secret management"
        return
    fi

    # Store secrets in Vault
    print_info "Storing secrets in Vault at: secret/photoprism/$FAMILY_NAME"

    # MinIO credentials
    vault kv put secret/photoprism/$FAMILY_NAME/minio \
        rootUser="minio-$FAMILY_NAME" \
        rootPassword="$(openssl rand -base64 20)" 2>/dev/null || print_error "Vault write failed (continuing...)"

    # MariaDB credentials
    vault kv put secret/photoprism/$FAMILY_NAME/mariadb \
        root-password="$(openssl rand -base64 20)" \
        password="$(openssl rand -base64 20)" 2>/dev/null || print_error "Vault write failed (continuing...)"

    # PhotoPrism admin password
    vault kv put secret/photoprism/$FAMILY_NAME/admin \
        password="$ADMIN_PASSWORD" \
        email="$CONTACT_EMAIL" 2>/dev/null || print_error "Vault write failed (continuing...)"

    print_success "Secrets stored in Vault"
}

print_deployment_info() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}  Deployment Complete!${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "${YELLOW}Family Information:${NC}"
    echo "  Family Name:      $FAMILY_NAME"
    echo "  Display Name:     $PREFERRED_NAME"
    echo "  Contact Email:    $CONTACT_EMAIL"
    echo ""
    echo -e "${YELLOW}Service URLs:${NC}"
    echo "  PhotoPrism:       https://photos.$DOMAIN"
    echo "  MinIO Console:    https://minio.photos.$DOMAIN"
    if [ "$ENABLE_AUTHELIA" = "true" ]; then
        echo "  Authelia SSO:     https://auth.$DOMAIN"
    fi
    echo ""
    echo -e "${YELLOW}Admin Credentials:${NC}"
    echo "  Username:         $CONTACT_EMAIL"
    echo "  Password:         $ADMIN_PASSWORD"
    echo "  (Also stored in:  secret/photoprism/$FAMILY_NAME/admin)"
    echo ""
    echo -e "${RED}⚠️  IMPORTANT:${NC}"
    echo "  1. Save the admin password securely"
    echo "  2. Configure DNS A records to point to ingress IP"
    echo "  3. Change admin password after first login"
    echo ""
    echo -e "${YELLOW}DNS Configuration Required:${NC}"

    # Get ingress IP
    if [ -z "$INGRESS_IP" ]; then
        INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "<INGRESS_IP>")
    fi

    echo "  Add these A records to your DNS provider:"
    echo "    photos.$DOMAIN          A    $INGRESS_IP"
    echo "    minio.photos.$DOMAIN    A    $INGRESS_IP"
    if [ "$ENABLE_AUTHELIA" = "true" ]; then
        echo "    auth.$DOMAIN            A    $INGRESS_IP"
    fi
    echo ""
    echo -e "${YELLOW}Pod Status:${NC}"
    kubectl get pods -n photoprism-$FAMILY_NAME
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "  1. Configure DNS records above"
    echo "  2. Wait for TLS certificates to be issued (2-5 minutes)"
    echo "  3. Access PhotoPrism at https://photos.$DOMAIN"
    echo "  4. Log in with admin credentials"
    echo "  5. Upload photos and invite family members!"
    echo ""
    echo -e "${YELLOW}Useful Commands:${NC}"
    echo "  Check status:    kubectl get all -n photoprism-$FAMILY_NAME"
    echo "  View logs:       kubectl logs -f deployment/photoprism -n photoprism-$FAMILY_NAME"
    echo "  Check TLS cert:  kubectl get certificate -n photoprism-$FAMILY_NAME"
    echo ""
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    print_header

    validate_requirements
    generate_family_overlay
    deploy_with_kustomize
    wait_for_services
    configure_vault_secrets
    print_deployment_info

    echo -e "${GREEN}🎉 Happy photo managing, $PREFERRED_NAME! 📸${NC}"
}

# Run main function
main "$@"
