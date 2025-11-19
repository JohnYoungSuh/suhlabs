#!/bin/bash
# Deploy Kubernetes manifests with secrets from Vault
# This script replaces placeholder variables in .yaml.template files with actual secrets from Vault
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VAULT_ADDR="${VAULT_ADDR:-https://vault.suhlabs.internal:8200}"
VAULT_NAMESPACE="${VAULT_NAMESPACE:-}"
TEMP_DIR=$(mktemp -d)
trap "rm -rf ${TEMP_DIR}" EXIT

# Functions
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

check_prerequisites() {
    print_header "Checking Prerequisites"

    # Check vault CLI
    if ! command -v vault &> /dev/null; then
        print_error "vault CLI not found. Please install Vault CLI."
        echo "Install: https://www.vaultproject.io/downloads"
        exit 1
    fi
    print_success "Vault CLI installed"

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    print_success "kubectl installed"

    # Check envsubst
    if ! command -v envsubst &> /dev/null; then
        print_error "envsubst not found. Please install gettext package."
        echo "Install: sudo apt-get install gettext (Debian/Ubuntu)"
        exit 1
    fi
    print_success "envsubst installed"

    # Check Vault authentication
    if ! vault token lookup &> /dev/null; then
        print_error "Not authenticated to Vault. Please login first:"
        echo "  export VAULT_ADDR=${VAULT_ADDR}"
        echo "  vault login"
        exit 1
    fi
    print_success "Vault authentication valid"

    # Check Kubernetes connection
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster."
        exit 1
    fi
    print_success "Kubernetes connection valid"

    echo ""
}

fetch_vault_secret() {
    local path=$1
    local key=$2
    local value

    value=$(vault kv get -field="${key}" "${path}" 2>/dev/null)
    if [ $? -ne 0 ]; then
        print_error "Failed to fetch ${key} from ${path}"
        return 1
    fi
    echo "${value}"
}

initialize_vault_secrets() {
    print_header "Initializing Vault Secrets"

    local create_secrets=false

    # Check if secrets exist
    if ! vault kv get secret/photoprism/minio &> /dev/null; then
        print_warning "PhotoPrism secrets not found in Vault."
        read -p "Do you want to create them now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            create_secrets=true
        else
            print_error "Cannot proceed without secrets. Exiting."
            exit 1
        fi
    fi

    if [ "$create_secrets" = true ]; then
        echo ""
        echo "Creating secrets in Vault..."
        echo "You will be prompted to enter secure passwords."
        echo ""

        # Generate strong random passwords
        print_warning "Generating secure random passwords..."

        # MinIO
        vault kv put secret/photoprism/minio \
            rootUser="minioadmin" \
            rootPassword="$(openssl rand -base64 32)"
        print_success "MinIO credentials created"

        # MariaDB
        vault kv put secret/photoprism/mariadb \
            rootPassword="$(openssl rand -base64 32)" \
            password="$(openssl rand -base64 32)"
        print_success "MariaDB credentials created"

        # PhotoPrism
        echo ""
        echo -n "Enter PhotoPrism admin password (or press Enter for random): "
        read -s admin_password
        echo
        if [ -z "$admin_password" ]; then
            admin_password=$(openssl rand -base64 24)
            print_warning "Generated random admin password"
        fi

        vault kv put secret/photoprism/app \
            adminPassword="${admin_password}" \
            databasePassword="$(vault kv get -field=password secret/photoprism/mariadb)" \
            s3AccessKey="minioadmin" \
            s3SecretKey="$(vault kv get -field=rootPassword secret/photoprism/minio)"
        print_success "PhotoPrism credentials created"

        # Authelia (optional)
        vault kv put secret/photoprism/authelia \
            jwtSecret="$(openssl rand -base64 32)" \
            sessionSecret="$(openssl rand -base64 32)" \
            encryptionKey="$(openssl rand -base64 32)" \
            smtpPassword="" \
            adminPasswordHash='$argon2id$v=19$m=65536,t=3,p=4$'"$(openssl rand -base64 16 | tr -d '=+/')"'$'"$(openssl rand -base64 32 | tr -d '=+/')"
        print_success "Authelia credentials created"

        echo ""
        print_success "All secrets created in Vault!"
        print_warning "IMPORTANT: Save your admin password: ${admin_password}"
        echo ""
    else
        print_success "Using existing Vault secrets"
    fi
}

process_template() {
    local template_file=$1
    local output_file="${template_file%.template}"

    echo "Processing: $(basename ${template_file})"

    # Export all Vault secrets as environment variables
    export VAULT_MINIO_ROOT_USER=$(fetch_vault_secret secret/photoprism/minio rootUser)
    export VAULT_MINIO_ROOT_PASSWORD=$(fetch_vault_secret secret/photoprism/minio rootPassword)

    export VAULT_MARIADB_ROOT_PASSWORD=$(fetch_vault_secret secret/photoprism/mariadb rootPassword)
    export VAULT_MARIADB_PASSWORD=$(fetch_vault_secret secret/photoprism/mariadb password)

    export VAULT_PHOTOPRISM_ADMIN_PASSWORD=$(fetch_vault_secret secret/photoprism/app adminPassword)
    export VAULT_PHOTOPRISM_DATABASE_PASSWORD=$(fetch_vault_secret secret/photoprism/app databasePassword)
    export VAULT_PHOTOPRISM_S3_ACCESS_KEY=$(fetch_vault_secret secret/photoprism/app s3AccessKey)
    export VAULT_PHOTOPRISM_S3_SECRET_KEY=$(fetch_vault_secret secret/photoprism/app s3SecretKey)

    # Authelia secrets (optional)
    export VAULT_AUTHELIA_JWT_SECRET=$(fetch_vault_secret secret/photoprism/authelia jwtSecret 2>/dev/null || echo "")
    export VAULT_AUTHELIA_SESSION_SECRET=$(fetch_vault_secret secret/photoprism/authelia sessionSecret 2>/dev/null || echo "")
    export VAULT_AUTHELIA_ENCRYPTION_KEY=$(fetch_vault_secret secret/photoprism/authelia encryptionKey 2>/dev/null || echo "")
    export VAULT_AUTHELIA_SMTP_PASSWORD=$(fetch_vault_secret secret/photoprism/authelia smtpPassword 2>/dev/null || echo "")
    export VAULT_AUTHELIA_ADMIN_PASSWORD_HASH=$(fetch_vault_secret secret/photoprism/authelia adminPasswordHash 2>/dev/null || echo "")

    # Process template
    envsubst < "${template_file}" > "${TEMP_DIR}/$(basename ${output_file})"

    print_success "Processed: $(basename ${output_file})"
}

deploy_manifests() {
    local service_path=$1
    local dry_run=${2:-false}

    print_header "Deploying ${service_path}"

    # Find all template files
    local templates=$(find "${service_path}" -name "*.yaml.template" -type f | sort)

    if [ -z "$templates" ]; then
        print_warning "No template files found in ${service_path}"
        return
    fi

    # Process each template
    for template in $templates; do
        process_template "${template}"
    done

    # Apply to Kubernetes
    echo ""
    if [ "$dry_run" = true ]; then
        print_warning "DRY RUN MODE - Not applying to cluster"
        echo "Generated files are in: ${TEMP_DIR}"
        ls -la "${TEMP_DIR}"
    else
        print_header "Applying to Kubernetes"

        # Apply non-secret manifests first (namespace, configmaps, etc)
        for manifest in "${service_path}"/*.yaml; do
            if [[ -f "$manifest" ]] && [[ ! "$manifest" =~ \.template$ ]]; then
                echo "Applying: $(basename ${manifest})"
                kubectl apply -f "${manifest}"
            fi
        done

        # Apply processed templates
        kubectl apply -f "${TEMP_DIR}/"

        print_success "Deployment complete!"
    fi
}

show_usage() {
    echo "Usage: $0 [OPTIONS] <service-path>"
    echo ""
    echo "Deploy Kubernetes manifests with secrets from Vault"
    echo ""
    echo "Options:"
    echo "  -d, --dry-run          Process templates but don't apply to cluster"
    echo "  -i, --init             Initialize Vault secrets interactively"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  VAULT_ADDR             Vault server address (default: https://vault.suhlabs.internal:8200)"
    echo "  VAULT_TOKEN            Vault authentication token"
    echo ""
    echo "Examples:"
    echo "  $0 services/photoprism/kubernetes"
    echo "  $0 --dry-run services/photoprism/kubernetes"
    echo "  $0 --init services/photoprism/kubernetes"
    echo ""
}

# Main
main() {
    local dry_run=false
    local init_secrets=false
    local service_path=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--dry-run)
                dry_run=true
                shift
                ;;
            -i|--init)
                init_secrets=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                service_path="$1"
                shift
                ;;
        esac
    done

    if [ -z "$service_path" ]; then
        print_error "Service path required"
        show_usage
        exit 1
    fi

    if [ ! -d "$service_path" ]; then
        print_error "Directory not found: ${service_path}"
        exit 1
    fi

    print_header "PhotoPrism Vault Deployment"
    echo "Service: ${service_path}"
    echo "Vault: ${VAULT_ADDR}"
    echo ""

    check_prerequisites

    if [ "$init_secrets" = true ]; then
        initialize_vault_secrets
    fi

    deploy_manifests "${service_path}" "${dry_run}"

    echo ""
    print_header "Deployment Summary"

    if [ "$dry_run" = false ]; then
        kubectl get pods -n photoprism
        echo ""
        print_success "PhotoPrism deployment complete!"
        echo ""
        echo "Next steps:"
        echo "1. Check pod status: kubectl get pods -n photoprism"
        echo "2. View logs: kubectl logs -f deployment/photoprism -n photoprism"
        echo "3. Access PhotoPrism at: https://photos.familyname.family"
    fi
}

main "$@"
