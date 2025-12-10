#!/bin/bash
# ============================================================================
# Factory Provisioning: Bootstrap Secrets
# Generates and stores initial secrets in Vault for a factory install.
# This script is non-interactive and designed for the "Zero-Touch" workflow.
# ============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
FORCE="${FORCE:-false}"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_vault() {
    if ! command -v vault &> /dev/null; then
        log_error "vault CLI not found"
        exit 1
    fi

    if ! vault status &> /dev/null; then
        # Check exit code: 0=unsealed, 2=sealed, 1=error
        local status=$?
        if [ $status -eq 2 ]; then
            log_error "Vault is sealed. Please unseal it first."
            exit 1
        elif [ $status -eq 1 ]; then
            log_error "Could not connect to Vault at ${VAULT_ADDR}"
            exit 1
        fi
    fi
    log_info "Vault connection verified"
}

generate_secrets() {
    log_info "Generating initial secrets..."

    # Check if secrets exist
    if vault kv get secret/photoprism/minio &> /dev/null && [ "$FORCE" != "true" ]; then
        log_warn "Secrets already exist. Skipping generation (use FORCE=true to overwrite)."
        return 0
    fi

    # MinIO
    log_info "Creating MinIO secrets..."
    vault kv put secret/photoprism/minio \
        rootUser="minioadmin" \
        rootPassword="$(openssl rand -base64 32)"

    # MariaDB
    log_info "Creating MariaDB secrets..."
    vault kv put secret/photoprism/mariadb \
        rootPassword="$(openssl rand -base64 32)" \
        password="$(openssl rand -base64 32)"

    # PhotoPrism
    log_info "Creating PhotoPrism secrets..."
    local admin_password=$(openssl rand -base64 24)
    vault kv put secret/photoprism/app \
        adminPassword="${admin_password}" \
        databasePassword="$(vault kv get -field=password secret/photoprism/mariadb)" \
        s3AccessKey="minioadmin" \
        s3SecretKey="$(vault kv get -field=rootPassword secret/photoprism/minio)"

    # Authelia
    log_info "Creating Authelia secrets..."
    vault kv put secret/photoprism/authelia \
        jwtSecret="$(openssl rand -base64 32)" \
        sessionSecret="$(openssl rand -base64 32)" \
        encryptionKey="$(openssl rand -base64 32)" \
        smtpPassword="" \
        adminPasswordHash='$argon2id$v=19$m=65536,t=3,p=4$'"$(openssl rand -base64 16 | tr -d '=+/')"'$'"$(openssl rand -base64 32 | tr -d '=+/')"

    log_info "✅ Secrets generated successfully"
    log_warn "PhotoPrism Admin Password: ${admin_password}"
}

main() {
    log_info "Starting Bootstrap Secrets..."
    check_vault
    generate_secrets
}

main "$@"
