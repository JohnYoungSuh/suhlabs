#!/bin/bash
# =============================================================================
# Vault Login Helper
# Unseals Vault and sets up environment for vault commands
# =============================================================================

set -euo pipefail

NAMESPACE="vault"
SECRET_NAME="vault-unseal-keys"
VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"

echo "=== Vault Login Helper ==="
echo ""

# Step 1: Check if Vault pod is running
echo "1. Checking Vault pod..."
if ! kubectl get pod -n "$NAMESPACE" -l app.kubernetes.io/name=vault &>/dev/null; then
    echo "✗ Vault pod not found. Deploy Vault first:"
    echo "  ./deploy.sh"
    exit 1
fi
echo "✓ Vault pod is running"
echo ""

# Step 2: Port-forward to Vault
echo "2. Setting up port-forward..."
if ! pgrep -f "port-forward.*vault.*8200" > /dev/null; then
    kubectl port-forward -n vault svc/vault 8200:8200 >/dev/null 2>&1 &
    PF_PID=$!
    sleep 3
    export VAULT_ADDR
    echo "✓ Port-forward active (PID: $PF_PID)"
else
    PF_PID=""
    export VAULT_ADDR
    echo "✓ Port-forward already running"
fi
echo ""

# Step 3: Check and unseal if needed
echo "3. Checking Vault seal status..."
if vault status 2>/dev/null | grep -q "Sealed.*true"; then
    echo "⚠ Vault is sealed. Unsealing..."

    if ! kubectl get secret -n "$NAMESPACE" "$SECRET_NAME" &>/dev/null; then
        echo "✗ Unseal keys not found in Kubernetes secret"
        echo "  Run: ./save-keys-to-k8s.sh .vault-keys.json"
        if [ -n "$PF_PID" ]; then
            kill $PF_PID 2>/dev/null || true
        fi
        exit 1
    fi

    # Get unseal keys from secret
    KEYS_JSON=$(kubectl get secret -n "$NAMESPACE" "$SECRET_NAME" -o jsonpath='{.data.keys}' | base64 -d)

    # Apply each unseal key
    echo "$KEYS_JSON" | jq -r '.unseal_keys_b64[]' 2>/dev/null | while read -r key; do
        vault operator unseal "$key" >/dev/null
    done

    echo "✓ Vault unsealed successfully"
else
    echo "✓ Vault is already unsealed"
fi
echo ""

# Step 4: Get and export root token
echo "4. Setting up authentication..."
if kubectl get secret -n "$NAMESPACE" "$SECRET_NAME" &>/dev/null; then
    VAULT_TOKEN=$(kubectl get secret -n "$NAMESPACE" "$SECRET_NAME" -o jsonpath='{.data.keys}' | base64 -d | jq -r '.root_token')

    if [ -n "$VAULT_TOKEN" ] && [ "$VAULT_TOKEN" != "null" ]; then
        export VAULT_TOKEN
        echo "✓ VAULT_TOKEN configured"
    else
        echo "⚠ Warning: Could not retrieve root token"
    fi
else
    echo "⚠ Warning: Keys secret not found"
fi
echo ""

# Step 5: Verify authentication
echo "5. Verifying Vault status..."
vault status
echo ""

# Final instructions
echo "=== Ready! ==="
echo ""
echo "Environment configured:"
echo "  VAULT_ADDR=$VAULT_ADDR"
echo "  VAULT_TOKEN=***${VAULT_TOKEN: -4}"
echo ""
echo "To use in your current shell, run:"
echo "  source <(./vault-login.sh)"
echo ""
echo "Or export these variables manually:"
echo "  export VAULT_ADDR=$VAULT_ADDR"
echo "  export VAULT_TOKEN=$VAULT_TOKEN"
echo ""
if [ -n "$PF_PID" ]; then
    echo "Note: Port-forward started in background (PID: $PF_PID)"
    echo "      Kill with: kill $PF_PID"
else
    echo "Note: Using existing port-forward"
fi
