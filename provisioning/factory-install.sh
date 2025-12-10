#!/bin/bash
# ============================================================================
# Factory Provisioning: Master Installer
# Zero-Touch installation of the AI Ops Substrate.
# Destructive: Wipes existing clusters to ensure a clean slate.
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_FILE="${REPO_ROOT}/factory-install.log"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
log_step() { echo -e "\n${BLUE}[STEP]${NC} $1" | tee -a "$LOG_FILE"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }

check_prereqs() {
    log_step "Checking Prerequisites"
    local tools=("docker" "kind" "kubectl" "vault" "make")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "$tool not found"
            exit 1
        fi
    done
    log_info "All prerequisites met"
}

cleanup() {
    log_step "Cleaning up existing environment"
    make -C "$REPO_ROOT" kind-down || true
    # Also clean up any local Vault tokens/keys if we want a TRULY fresh start?
    # For now, we'll keep the .vault-keys.json if it exists to avoid locking ourselves out of a persistent vault,
    # but since kind-down wipes the cluster, the vault pod is gone.
    # The keys file corresponds to the OLD vault. We should probably move it.
    if [ -f "${REPO_ROOT}/cluster/foundation/vault/.vault-keys.json" ]; then
        mv "${REPO_ROOT}/cluster/foundation/vault/.vault-keys.json" "${REPO_ROOT}/cluster/foundation/vault/.vault-keys.json.bak.$(date +%s)"
        log_info "Backed up old Vault keys"
    fi
}

phase_1_infra() {
    log_step "Phase 1: Infrastructure (Kind Cluster)"
    make -C "$REPO_ROOT" kind-up
}

phase_2_foundation() {
    log_step "Phase 2: Foundation Services"
    
    # CoreDNS
    log_info "Deploying CoreDNS..."
    cd "${REPO_ROOT}/cluster/foundation/coredns" && ./deploy.sh
    
    # Vault
    log_info "Deploying Vault..."
    cd "${REPO_ROOT}/cluster/foundation/vault" && ./deploy.sh
    
    log_info "Waiting for Vault pod..."
    kubectl wait --for=condition=Ready pod/vault-0 -n vault --timeout=300s || true 
    # Note: Vault pod might not be 'Ready' until unsealed, but 'Running' is enough to exec.
    # The deploy script or bootstrap script usually handles the wait.
    
    # Vault Bootstrap (Init + Unseal)
    log_info "Bootstrapping Vault..."
    cd "${REPO_ROOT}/cluster/foundation/vault" && ./vault-bootstrap.sh auto
    
    # Export token for subsequent steps
    export VAULT_TOKEN=$(jq -r '.root_token' "${REPO_ROOT}/cluster/foundation/vault/.vault-keys.json")
    export VAULT_ADDR="http://localhost:8200"
    
    # Port forward Vault in background for local CLI access if needed, 
    # but the scripts usually use kubectl exec. 
    # However, bootstrap-secrets.sh might use local vault CLI.
    # Let's assume we run bootstrap-secrets.sh using kubectl exec or port-forward.
    # The simplest is to use `kubectl exec` inside the scripts, but `bootstrap-secrets.sh` uses `vault` CLI.
    # We need to set up port forwarding or run it inside the pod.
    # Let's set up a temporary port forward.
    kubectl port-forward svc/vault -n vault 8200:8200 > /dev/null 2>&1 &
    PF_PID=$!
    sleep 5
    trap "kill $PF_PID" EXIT
}

phase_3_secrets_pki() {
    log_step "Phase 3: Secrets & PKI"
    
    # Bootstrap Secrets
    log_info "Generating Secrets..."
    "${SCRIPT_DIR}/bootstrap-secrets.sh"
    
    # PKI Init
    log_info "Initializing PKI..."
    cd "${REPO_ROOT}/cluster/foundation/vault-pki" && ./init-vault-pki.sh
}

phase_4_cert_manager() {
    log_step "Phase 4: Cert Manager"
    cd "${REPO_ROOT}/cluster/foundation/cert-manager" && ./deploy.sh
}

phase_5_validation() {
    log_step "Phase 5: Validation"
    "${REPO_ROOT}/scripts/autonomous-validation.sh"
}

main() {
    echo "Starting Factory Install..." > "$LOG_FILE"
    
    check_prereqs
    cleanup
    phase_1_infra
    phase_2_foundation
    phase_3_secrets_pki
    phase_4_cert_manager
    
    # Note: AI Layer deployment is currently part of autonomous-validation.sh (Phase 8+),
    # but ideally should be moved here. For now, we'll let validation script handle it 
    # as per the current architecture, or we can extract it later.
    # The implementation plan said "Phase 4: AI Layer: Deploys Ollama...".
    # Since autonomous-validation.sh does it, we can rely on it for now to verify the "Zero-Touch" aspect.
    
    phase_5_validation
    
    log_info "Factory Install Complete! ✨"
}

main "$@"
