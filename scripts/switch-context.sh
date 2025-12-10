#!/bin/bash
# =============================================================================
# Ultimate Kubernetes Context Switcher - World's Best Edition
# Switches context, verifies health, auto-fixes common issues
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VAULT_BOOTSTRAP="$PROJECT_ROOT/cluster/foundation/vault/vault-bootstrap.sh"

# Logging
log_info() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_step() { echo -e "${BLUE}[→]${NC} $1"; }
log_success() { echo -e "${CYAN}${BOLD}[SUCCESS]${NC} $1"; }

# Banner
show_banner() {
    echo -e "${MAGENTA}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║       Ultimate K8s Context Switcher - World's Best Edition      ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Usage
usage() {
    cat << EOF
${BOLD}USAGE:${NC}
    $0 <environment> [namespace] [options]

${BOLD}ENVIRONMENTS:${NC}
    poc, dev          - Development/POC cluster (kind-aiops-dev)
    val, validation   - Validation cluster
    prod, production  - Production cluster (requires confirmation)

${BOLD}OPTIONS:${NC}
    -n, --namespace   - Target namespace (default: current or 'default')
    -s, --skip-check  - Skip health checks (faster)
    -u, --unseal      - Auto-unseal Vault if sealed
    -v, --verify      - Run full verification suite
    -h, --help        - Show this help

${BOLD}EXAMPLES:${NC}
    $0 poc                    # Switch to POC, default namespace
    $0 poc vault              # Switch to POC, vault namespace
    $0 poc -n vault -u        # Switch to POC/vault, unseal Vault
    $0 prod -n default        # Switch to PROD (requires confirmation)

${BOLD}WHAT THIS DOES:${NC}
    1. Switches K8s context
    2. Sets namespace
    3. Verifies cluster connectivity
    4. Checks for common issues (Vault sealed, pods not ready)
    5. Auto-fixes issues (optional: unseal Vault)
    6. Shows environment dashboard

EOF
    exit 0
}

# Parse arguments
ENV=""
NAMESPACE=""
SKIP_CHECK=false
AUTO_UNSEAL=false
VERIFY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) usage ;;
        -n|--namespace) NAMESPACE="$2"; shift 2 ;;
        -s|--skip-check) SKIP_CHECK=true; shift ;;
        -u|--unseal) AUTO_UNSEAL=true; shift ;;
        -v|--verify) VERIFY=true; shift ;;
        poc|dev) ENV="poc"; shift ;;
        val|validation) ENV="validation"; shift ;;
        prod|production) ENV="production"; shift ;;
        *)
            if [[ -z "$ENV" ]]; then
                ENV="$1"
            elif [[ -z "$NAMESPACE" ]]; then
                NAMESPACE="$1"
            else
                log_error "Unknown argument: $1"
                usage
            fi
            shift
            ;;
    esac
done

# Validate environment
if [[ -z "$ENV" ]]; then
    log_error "Environment required!"
    usage
fi

# Map environment to context
case "$ENV" in
    poc|dev)
        CONTEXT="kind-aiops-dev"
        ENV_EMOJI="🏗️"
        ENV_NAME="POC/Dev"
        ;;
    val|validation)
        CONTEXT="aiops-validation"
        ENV_EMOJI="🧪"
        ENV_NAME="Validation"
        ;;
    prod|production)
        CONTEXT="aiops-production"
        ENV_EMOJI="🚀"
        ENV_NAME="PRODUCTION"
        ;;
    *)
        log_error "Unknown environment: $ENV"
        usage
        ;;
esac

# Production safety check
if [[ "$ENV" == "prod" || "$ENV" == "production" ]]; then
    echo -e "${RED}${BOLD}⚠️  WARNING: SWITCHING TO PRODUCTION ⚠️${NC}"
    echo ""
    read -p "Type 'PRODUCTION' to confirm: " confirm
    if [[ "$confirm" != "PRODUCTION" ]]; then
        log_error "Production switch cancelled."
        exit 1
    fi
    echo ""
fi

# Main execution
show_banner

log_step "Switching to ${ENV_EMOJI} ${ENV_NAME} environment..."

# Check if context exists
if ! kubectl config get-contexts -o name | grep -q "^${CONTEXT}$"; then
    log_error "Context '${CONTEXT}' not found!"
    echo ""
    echo "Available contexts:"
    kubectl config get-contexts -o name
    exit 1
fi

# Switch context
kubectl config use-context "${CONTEXT}" > /dev/null 2>&1
log_info "Context switched to: ${BOLD}${CONTEXT}${NC}"

# Set namespace
if [[ -n "$NAMESPACE" ]]; then
    kubectl config set-context --current --namespace="${NAMESPACE}" > /dev/null 2>&1
    log_info "Namespace set to: ${BOLD}${NAMESPACE}${NC}"
else
    NAMESPACE=$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null || echo "default")
    log_info "Using namespace: ${BOLD}${NAMESPACE}${NC}"
fi

# Update terminal title
echo -ne "\033]0;${ENV_EMOJI} ${ENV_NAME}:${NAMESPACE}\007"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Skip checks if requested
if [[ "$SKIP_CHECK" == true ]]; then
    log_success "Context switched! (health checks skipped)"
    exit 0
fi

# Health checks
log_step "Running health checks..."

# 1. Cluster connectivity
if kubectl cluster-info > /dev/null 2>&1; then
    log_info "Cluster is reachable"
else
    log_error "Cannot connect to cluster!"
    exit 1
fi

# 2. Check nodes
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready " || echo 0)
if [[ $READY_NODES -eq $NODE_COUNT ]] && [[ $NODE_COUNT -gt 0 ]]; then
    log_info "Nodes: ${READY_NODES}/${NODE_COUNT} Ready"
else
    log_warn "Nodes: ${READY_NODES}/${NODE_COUNT} Ready (some nodes not ready)"
fi

# 3. Check Vault (if exists)
if kubectl get namespace vault > /dev/null 2>&1; then
    VAULT_STATUS=$(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null | jq -r '.sealed' 2>/dev/null || echo "error")

    if [[ "$VAULT_STATUS" == "false" ]]; then
        log_info "Vault: Unsealed ✓"
    elif [[ "$VAULT_STATUS" == "true" ]]; then
        log_warn "Vault: Sealed (needs unsealing)"

        # Auto-unseal if requested
        if [[ "$AUTO_UNSEAL" == true ]]; then
            log_step "Auto-unsealing Vault..."
            if [[ -x "$VAULT_BOOTSTRAP" ]]; then
                "$VAULT_BOOTSTRAP" unseal > /dev/null 2>&1 && log_info "Vault unsealed successfully!" || log_error "Failed to unseal Vault"
            else
                log_warn "Vault bootstrap script not found at: $VAULT_BOOTSTRAP"
            fi
        else
            echo -e "         ${YELLOW}Tip: Use -u flag to auto-unseal${NC}"
        fi
    else
        log_warn "Vault: Status unknown (pod may not be running)"
    fi
fi

# 4. Check cert-manager ClusterIssuers (if exists)
if kubectl get crd clusterissuers.cert-manager.io > /dev/null 2>&1; then
    ISSUER_COUNT=$(kubectl get clusterissuer --no-headers 2>/dev/null | wc -l)
    READY_ISSUERS=$(kubectl get clusterissuer --no-headers 2>/dev/null | grep -c "True" || echo 0)

    if [[ $READY_ISSUERS -eq $ISSUER_COUNT ]] && [[ $ISSUER_COUNT -gt 0 ]]; then
        log_info "ClusterIssuers: ${READY_ISSUERS}/${ISSUER_COUNT} Ready"
    elif [[ $ISSUER_COUNT -gt 0 ]]; then
        log_warn "ClusterIssuers: ${READY_ISSUERS}/${ISSUER_COUNT} Ready"
    fi
fi

# 5. Check pods in current namespace
POD_COUNT=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
if [[ $POD_COUNT -gt 0 ]]; then
    RUNNING_PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | grep -c "Running" || echo 0)
    log_info "Pods in '${NAMESPACE}': ${RUNNING_PODS}/${POD_COUNT} Running"

    # Show not-running pods
    NOT_RUNNING=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | grep -v "Running" || echo "")
    if [[ -n "$NOT_RUNNING" ]]; then
        echo -e "${YELLOW}         Pods not running:${NC}"
        echo "$NOT_RUNNING" | awk '{printf "         - %s (%s)\n", $1, $3}'
    fi
else
    log_info "No pods in namespace '${NAMESPACE}'"
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Environment Dashboard
echo -e "${BOLD}Environment Dashboard:${NC}"
echo -e "  Context:    ${ENV_EMOJI} ${BOLD}${CONTEXT}${NC}"
echo -e "  Namespace:  ${BOLD}${NAMESPACE}${NC}"
echo -e "  Nodes:      ${READY_NODES}/${NODE_COUNT} Ready"
if [[ -n "$VAULT_STATUS" ]]; then
    echo -e "  Vault:      $([ "$VAULT_STATUS" == "false" ] && echo "${GREEN}Unsealed${NC}" || echo "${YELLOW}Sealed${NC}")"
fi
echo ""

# Run full verification if requested
if [[ "$VERIFY" == true ]]; then
    log_step "Running full verification suite..."
    if [[ -x "$PROJECT_ROOT/cluster/foundation/verify-all.sh" ]]; then
        "$PROJECT_ROOT/cluster/foundation/verify-all.sh"
    else
        log_warn "Verification suite not found"
    fi
fi

log_success "Ready to work in ${ENV_EMOJI} ${ENV_NAME}:${NAMESPACE}!"
echo ""
