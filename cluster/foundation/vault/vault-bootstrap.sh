#!/bin/bash
# ============================================================================
# Vault Bootstrap Script
# Handles Vault initialization, unsealing, and sealing operations
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="vault"
POD_NAME="vault-0"
KEYS_FILE="${SCRIPT_DIR}/.vault-keys.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

log_success() {
    echo -e "${CYAN}[SUCCESS]${NC} $1"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl not found. Please install kubectl first."
    exit 1
fi

# Check if Vault pod is running
check_vault_pod() {
    if ! kubectl get pod "$POD_NAME" -n "$NAMESPACE" &> /dev/null; then
        log_error "Vault pod '$POD_NAME' not found in namespace '$NAMESPACE'"
        log_info "Run './deploy.sh' first to deploy Vault"
        exit 1
    fi

    # Check if pod is running
    local pod_status=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
    if [[ "$pod_status" != "Running" ]]; then
        log_error "Vault pod is not running (status: $pod_status)"
        kubectl get pod "$POD_NAME" -n "$NAMESPACE"
        exit 1
    fi
}

# Check if Vault is initialized
is_vault_initialized() {
    local init_status=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- vault status -format=json 2>/dev/null | jq -r '.initialized' 2>/dev/null || echo "false")
    [[ "$init_status" == "true" ]]
}

# Check if Vault is sealed
is_vault_sealed() {
    local seal_status=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- vault status -format=json 2>/dev/null | jq -r '.sealed' 2>/dev/null || echo "true")
    [[ "$seal_status" == "true" ]]
}

# Initialize Vault
initialize_vault() {
    log_step "Initializing Vault..."

    if is_vault_initialized; then
        log_warn "Vault is already initialized!"

        if [[ -f "$KEYS_FILE" ]]; then
            log_info "Keys file exists at: $KEYS_FILE"
        else
            log_error "Vault is initialized but keys file not found!"
            log_error "You need the original unseal keys to unseal Vault."
            exit 1
        fi
        return 0
    fi

    log_info "Running vault operator init..."
    local init_output=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- vault operator init -format=json)

    # Save keys and token to file
    echo "$init_output" > "$KEYS_FILE"
    chmod 600 "$KEYS_FILE"

    log_success "✅ Vault initialized successfully!"
    echo ""
    log_warn "⚠️  IMPORTANT: Unseal keys and root token saved to:"
    echo "   $KEYS_FILE"
    echo ""
    log_warn "⚠️  SECURITY WARNING:"
    echo "   - This file contains sensitive data!"
    echo "   - Keep it secure and backed up"
    echo "   - For production, use a secrets manager or HSM"
    echo ""

    # Display keys and token
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}                  VAULT CREDENTIALS                        ${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
    echo ""

    echo "Unseal Keys:"
    for i in {0..4}; do
        local key=$(echo "$init_output" | jq -r ".unseal_keys_b64[$i]")
        echo "  Key $((i+1)): $key"
    done

    echo ""
    local root_token=$(echo "$init_output" | jq -r '.root_token')
    echo "Root Token: $root_token"

    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
    echo ""

    log_info "Vault requires 3 of 5 unseal keys to unseal"
    echo ""
}

# Unseal Vault
unseal_vault() {
    log_step "Unsealing Vault..."

    if ! is_vault_sealed; then
        log_success "✅ Vault is already unsealed!"
        return 0
    fi

    if [[ ! -f "$KEYS_FILE" ]]; then
        log_error "Keys file not found at: $KEYS_FILE"
        log_error "Cannot unseal without keys. Initialize Vault first."
        exit 1
    fi

    log_info "Reading unseal keys from: $KEYS_FILE"

    # Unseal with first 3 keys
    for i in {0..2}; do
        local key=$(jq -r ".unseal_keys_b64[$i]" "$KEYS_FILE")
        log_info "Using unseal key $((i+1))/3..."

        kubectl exec -n "$NAMESPACE" "$POD_NAME" -- vault operator unseal "$key" > /dev/null

        # Check progress
        local progress=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- vault status -format=json 2>/dev/null | jq -r '.unseal_progress' 2>/dev/null || echo "0")
        log_info "Unseal progress: $progress/3"
    done

    echo ""
    if ! is_vault_sealed; then
        log_success "✅ Vault unsealed successfully!"
    else
        log_error "Failed to unseal Vault"
        exit 1
    fi
}

# Seal Vault
seal_vault() {
    log_step "Sealing Vault..."

    if is_vault_sealed; then
        log_warn "Vault is already sealed"
        return 0
    fi

    if [[ ! -f "$KEYS_FILE" ]]; then
        log_error "Keys file not found. Cannot get root token."
        exit 1
    fi

    local root_token=$(jq -r '.root_token' "$KEYS_FILE")

    log_warn "⚠️  This will seal Vault and make it inaccessible until unsealed"
    read -p "Are you sure you want to seal Vault? (yes/no): " confirm

    if [[ "$confirm" != "yes" ]]; then
        log_info "Seal operation cancelled"
        return 0
    fi

    kubectl exec -n "$NAMESPACE" "$POD_NAME" -- env VAULT_TOKEN="$root_token" vault operator seal

    log_success "✅ Vault sealed successfully"
}

# Show Vault status
show_status() {
    log_step "Checking Vault status..."
    echo ""

    kubectl exec -n "$NAMESPACE" "$POD_NAME" -- vault status || true

    echo ""
    if is_vault_initialized; then
        log_info "Initialized: ✅ Yes"
    else
        log_warn "Initialized: ❌ No"
    fi

    if is_vault_sealed; then
        log_warn "Sealed: 🔒 Yes (Vault is locked)"
    else
        log_success "Sealed: 🔓 No (Vault is ready)"
    fi

    echo ""
    if [[ -f "$KEYS_FILE" ]]; then
        log_info "Keys file: ✅ Found at $KEYS_FILE"
        local root_token=$(jq -r '.root_token' "$KEYS_FILE" 2>/dev/null || echo "error")
        if [[ "$root_token" != "error" && "$root_token" != "null" ]]; then
            echo ""
            log_info "Root Token: $root_token"
            echo ""
            log_info "Export token for CLI use:"
            echo "   export VAULT_TOKEN=$root_token"
            echo "   export VAULT_ADDR=http://vault.vault.svc.cluster.local:8200"
        fi
    else
        log_warn "Keys file: ❌ Not found"
    fi
}

# Show root token
show_token() {
    if [[ ! -f "$KEYS_FILE" ]]; then
        log_error "Keys file not found at: $KEYS_FILE"
        exit 1
    fi

    local root_token=$(jq -r '.root_token' "$KEYS_FILE")
    echo ""
    echo "Root Token: $root_token"
    echo ""
    echo "Export for use:"
    echo "  export VAULT_TOKEN=$root_token"
    echo "  export VAULT_ADDR=http://vault.vault.svc.cluster.local:8200"
    echo ""
}

# Main menu
show_menu() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}              Vault Bootstrap Menu                         ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "1) Initialize Vault (first time setup)"
    echo "2) Unseal Vault (unlock after restart)"
    echo "3) Seal Vault (lock Vault)"
    echo "4) Show Vault status"
    echo "5) Show root token"
    echo "6) Auto: Initialize + Unseal"
    echo "7) Exit"
    echo ""
}

# Auto initialize and unseal
auto_init_unseal() {
    initialize_vault
    echo ""
    unseal_vault
    echo ""
    show_status
}

# Main script
main() {
    log_info "Vault Bootstrap Script"
    echo ""

    check_vault_pod

    # If no arguments, show interactive menu
    if [[ $# -eq 0 ]]; then
        while true; do
            show_menu
            read -p "Select an option (1-7): " choice

            case $choice in
                1)
                    initialize_vault
                    ;;
                2)
                    unseal_vault
                    echo ""
                    show_status
                    ;;
                3)
                    seal_vault
                    ;;
                4)
                    show_status
                    ;;
                5)
                    show_token
                    ;;
                6)
                    auto_init_unseal
                    ;;
                7)
                    log_info "Goodbye!"
                    exit 0
                    ;;
                *)
                    log_error "Invalid option"
                    ;;
            esac

            echo ""
            read -p "Press Enter to continue..."
        done
    fi

    # Command line arguments
    case "${1:-}" in
        init|initialize)
            initialize_vault
            ;;
        unseal)
            unseal_vault
            show_status
            ;;
        seal)
            seal_vault
            ;;
        status)
            show_status
            ;;
        token)
            show_token
            ;;
        auto)
            auto_init_unseal
            ;;
        *)
            log_error "Unknown command: ${1:-}"
            echo ""
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  init     - Initialize Vault (first time)"
            echo "  unseal   - Unseal Vault"
            echo "  seal     - Seal Vault"
            echo "  status   - Show Vault status"
            echo "  token    - Show root token"
            echo "  auto     - Initialize and unseal"
            echo ""
            echo "Run without arguments for interactive menu"
            exit 1
            ;;
    esac
}

main "$@"
