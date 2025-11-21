#!/bin/bash
# =============================================================================
# Auto-unseal Vault from Kubernetes Secret
# Runs automatically after Vault pod restarts
# =============================================================================

set -euo pipefail

NAMESPACE="vault"
SECRET_NAME="vault-unseal-keys"
VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"

echo "Checking Vault status..."

# Port-forward to Vault
if ! pgrep -f "port-forward.*vault.*8200" > /dev/null; then
    kubectl port-forward -n vault svc/vault 8200:8200 &
    PF_PID=$!
    sleep 3
else
    echo "Port-forward already running"
    PF_PID=""
fi

export VAULT_ADDR

# Check if Vault is sealed
if vault status 2>/dev/null | grep -q "Sealed.*true"; then
    echo "Vault is sealed. Unsealing..."

    # Get unseal keys from Kubernetes secret
    UNSEAL_KEYS=$(kubectl get secret -n "$NAMESPACE" "$SECRET_NAME" -o jsonpath='{.data.keys}' | base64 -d)

    # Apply each unseal key
    echo "$UNSEAL_KEYS" | jq -r '.unseal_keys_b64[]' | while read -r key; do
        echo "Applying unseal key..."
        vault operator unseal "$key"
    done

    echo "✓ Vault unsealed successfully!"
else
    echo "✓ Vault is already unsealed"
fi

# Cleanup
if [ -n "$PF_PID" ]; then
    kill $PF_PID 2>/dev/null || true
fi

vault status
