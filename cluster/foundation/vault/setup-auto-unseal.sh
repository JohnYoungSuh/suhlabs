#!/bin/bash
# =============================================================================
# Setup Automatic Vault Unsealing on Machine Restart
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_FILE="vault-auto-unseal.service"
SERVICE_NAME="vault-auto-unseal"

echo "=== Vault Auto-Unseal Setup ==="
echo ""

# Check prerequisites
echo "1. Checking prerequisites..."

if [ ! -f "$SCRIPT_DIR/.vault-keys.json" ]; then
    echo "✗ .vault-keys.json not found"
    echo "  Run ./vault-bootstrap.sh first to initialize Vault"
    exit 1
fi

if ! kubectl get secret -n vault vault-unseal-keys &>/dev/null; then
    echo "✗ Kubernetes secret not found"
    echo "  Run: ./save-keys-to-k8s.sh .vault-keys.json"
    exit 1
fi

echo "✓ Prerequisites met"
echo ""

# Setup systemd user service
echo "2. Setting up systemd user service..."

# Create systemd user directory if it doesn't exist
mkdir -p ~/.config/systemd/user

# Update service file with correct path
sed "s|%h/projects/suhlabs/aiops-substrate/cluster/foundation/vault|$SCRIPT_DIR|g" \
    "$SCRIPT_DIR/$SERVICE_FILE" > ~/.config/systemd/user/$SERVICE_NAME.service

# Reload systemd
systemctl --user daemon-reload

# Enable and start service
systemctl --user enable $SERVICE_NAME.service

echo "✓ Systemd service installed"
echo ""

# Setup shell profile integration
echo "3. Setting up shell profile integration..."

SHELL_SNIPPET="
# Auto-load Vault credentials (added by vault setup-auto-unseal.sh)
if [ -f \"$SCRIPT_DIR/vault-env.sh\" ]; then
    source \"$SCRIPT_DIR/vault-env.sh\" 2>/dev/null || true
fi
"

# Detect user's shell
SHELL_RC=""
if [ -n "${BASH_VERSION:-}" ] || [ -f ~/.bashrc ]; then
    SHELL_RC=~/.bashrc
elif [ -n "${ZSH_VERSION:-}" ] || [ -f ~/.zshrc ]; then
    SHELL_RC=~/.zshrc
else
    echo "⚠ Could not detect shell type. Supported: bash, zsh"
    SHELL_RC=""
fi

if [ -n "$SHELL_RC" ]; then
    # Check if already added
    if grep -q "Auto-load Vault credentials" "$SHELL_RC" 2>/dev/null; then
        echo "✓ Shell profile already configured"
    else
        echo "$SHELL_SNIPPET" >> "$SHELL_RC"
        echo "✓ Added to $SHELL_RC"
    fi
else
    echo "⚠ Skipping shell profile setup"
    echo "  Manually add to your shell profile:"
    echo "$SHELL_SNIPPET"
fi

echo ""

# Summary
echo "=== Setup Complete! ==="
echo ""
echo "What happens now:"
echo ""
echo "1. On machine restart:"
echo "   → Systemd auto-runs vault-login.sh"
echo "   → Vault is unsealed automatically"
echo "   → Takes ~30s after boot"
echo ""
echo "2. On new terminal:"
echo "   → Shell auto-sources vault-env.sh"
echo "   → VAULT_TOKEN and VAULT_ADDR are set"
echo "   → Ready to use vault commands immediately"
echo ""
echo "Manual controls:"
echo "  Check status:  systemctl --user status $SERVICE_NAME"
echo "  View logs:     journalctl --user -u $SERVICE_NAME"
echo "  Disable:       systemctl --user disable $SERVICE_NAME"
echo "  Manual unseal: ./vault-login.sh"
echo ""
echo "Test it now:"
echo "  1. Restart your terminal (or run: source $SHELL_RC)"
echo "  2. Run: vault status"
echo ""
