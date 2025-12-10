#!/bin/bash
# =============================================================================
# tmux Kubernetes Sessionizer - World's Best Edition
# Creates organized tmux sessions for different K8s environments
# =============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
PROJECT_ROOT="/home/suhlabs/projects/suhlabs/aiops-substrate"
SWITCH_SCRIPT="$PROJECT_ROOT/scripts/switch-context.sh"

# Usage
usage() {
    cat << EOF
${BOLD}USAGE:${NC}
    $0 <environment> [options]

${BOLD}ENVIRONMENTS:${NC}
    poc, dev          - Development/POC cluster session
    val, validation   - Validation cluster session
    prod, production  - Production cluster session

${BOLD}OPTIONS:${NC}
    -h, --help        - Show this help

${BOLD}WHAT THIS CREATES:${NC}
    Creates a tmux session with organized panes:
    - Window 1: Vault namespace (logs, shell)
    - Window 2: cert-manager namespace (logs, shell)
    - Window 3: default namespace (AI agent, shell)
    - Window 4: Watch pods across all namespaces

${BOLD}EXAMPLES:${NC}
    $0 poc            # Create POC tmux session
    $0 prod           # Create PROD tmux session

EOF
    exit 0
}

# Parse arguments
ENV=""
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) usage ;;
        poc|dev|val|validation|prod|production) ENV="$1"; shift ;;
        *) echo -e "${RED}Unknown argument: $1${NC}"; usage ;;
    esac
done

if [[ -z "$ENV" ]]; then
    echo -e "${YELLOW}Error: Environment required!${NC}"
    usage
fi

# Map environment to session name and emoji
case "$ENV" in
    poc|dev)
        SESSION="k8s-poc"
        ENV_SHORT="poc"
        ENV_EMOJI="🏗️"
        ENV_NAME="POC"
        ;;
    val|validation)
        SESSION="k8s-val"
        ENV_SHORT="val"
        ENV_EMOJI="🧪"
        ENV_NAME="VAL"
        ;;
    prod|production)
        SESSION="k8s-prod"
        ENV_SHORT="prod"
        ENV_EMOJI="🚀"
        ENV_NAME="PROD"
        ;;
esac

echo -e "${MAGENTA}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║          tmux K8s Sessionizer - Creating ${ENV_EMOJI} ${ENV_NAME} Session              ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if session already exists
if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo -e "${YELLOW}Session '$SESSION' already exists.${NC}"
    read -p "Attach to existing session? (y/n): " attach
    if [[ "$attach" == "y" ]]; then
        tmux attach-session -t "$SESSION"
        exit 0
    else
        echo "Exiting..."
        exit 0
    fi
fi

# Create new session (detached)
echo -e "${BLUE}Creating tmux session: $SESSION${NC}"
tmux new-session -d -s "$SESSION" -n "vault"

# Window 1: Vault namespace
tmux send-keys -t "$SESSION:1" "$SWITCH_SCRIPT $ENV_SHORT vault -u" C-m
sleep 2
tmux split-window -t "$SESSION:1" -v
tmux send-keys -t "$SESSION:1.2" "$SWITCH_SCRIPT $ENV_SHORT vault -s && kubectl logs -n vault vault-0 -f --tail=50" C-m
tmux select-pane -t "$SESSION:1.1"

# Window 2: cert-manager namespace
tmux new-window -t "$SESSION" -n "cert-manager"
tmux send-keys -t "$SESSION:2" "$SWITCH_SCRIPT $ENV_SHORT cert-manager -s" C-m
sleep 1
tmux split-window -t "$SESSION:2" -v
tmux send-keys -t "$SESSION:2.2" "kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager -f --tail=50" C-m
tmux select-pane -t "$SESSION:2.1"

# Window 3: default namespace (AI agent)
tmux new-window -t "$SESSION" -n "default"
tmux send-keys -t "$SESSION:3" "$SWITCH_SCRIPT $ENV_SHORT default -s" C-m
sleep 1
tmux split-window -t "$SESSION:3" -v
tmux send-keys -t "$SESSION:3.2" "kubectl get pods -w" C-m
tmux select-pane -t "$SESSION:3.1"

# Window 4: Watch all pods
tmux new-window -t "$SESSION" -n "watch"
tmux send-keys -t "$SESSION:4" "$SWITCH_SCRIPT $ENV_SHORT default -s" C-m
tmux send-keys -t "$SESSION:4" "watch -n 2 'kubectl get pods -A | grep -v Running || kubectl get pods -A'" C-m

# Window 5: Scratch workspace
tmux new-window -t "$SESSION" -n "scratch"
tmux send-keys -t "$SESSION:5" "cd $PROJECT_ROOT" C-m
tmux send-keys -t "$SESSION:5" "clear" C-m

# Select first window
tmux select-window -t "$SESSION:1"

echo -e "${GREEN}✓ tmux session created: ${BOLD}$SESSION${NC}"
echo ""
echo -e "${CYAN}Session layout:${NC}"
echo "  Window 1: vault namespace (shell + logs)"
echo "  Window 2: cert-manager namespace (shell + logs)"
echo "  Window 3: default namespace (shell + pod watch)"
echo "  Window 4: Watch all pods across namespaces"
echo "  Window 5: Scratch workspace"
echo ""
echo -e "${BOLD}Attach to session:${NC}"
echo "  tmux attach-session -t $SESSION"
echo ""
echo -e "${BOLD}tmux cheat sheet:${NC}"
echo "  Ctrl+a 1-5    - Switch between windows"
echo "  Ctrl+a |      - Split vertical"
echo "  Ctrl+a -      - Split horizontal"
echo "  Alt+arrows    - Navigate panes"
echo "  Ctrl+a d      - Detach session"
echo ""

# Auto-attach if not already in tmux
if [[ -z "$TMUX" ]]; then
    echo -e "${GREEN}Attaching to session...${NC}"
    sleep 1
    tmux attach-session -t "$SESSION"
else
    echo -e "${YELLOW}Already in tmux. Run: ${BOLD}tmux switch-client -t $SESSION${NC}"
fi
