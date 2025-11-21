#!/bin/bash
# =============================================================================
# Set Vault Environment Variables
# Source this script to automatically set VAULT_ADDR and VAULT_TOKEN
# Usage: source ./vault-env.sh
# =============================================================================

NAMESPACE="vault"
SECRET_NAME="vault-unseal-keys"

# Set Vault address
export VAULT_ADDR="http://localhost:8200"

# Get root token from Kubernetes secret
if kubectl get secret -n "$NAMESPACE" "$SECRET_NAME" &>/dev/null; then
    VAULT_TOKEN=""
    # shellcheck disable=SC2155
    VAULT_TOKEN=$(kubectl get secret -n "$NAMESPACE" "$SECRET_NAME" -o jsonpath='{.data.keys}' | base64 -d | jq -r '.root_token')
    export VAULT_TOKEN

    if [ -n "$VAULT_TOKEN" ] && [ "$VAULT_TOKEN" != "null" ]; then
        echo "✓ Vault environment configured:"
        echo "  VAULT_ADDR=$VAULT_ADDR"
        echo "  VAULT_TOKEN=***${VAULT_TOKEN: -4}"
    else
        echo "⚠ Warning: Could not retrieve VAULT_TOKEN from secret"
        echo "  Run: ./save-keys-to-k8s.sh .vault-keys.json"
    fi
else
    echo "⚠ Warning: Kubernetes secret '$SECRET_NAME' not found"
    echo "  Run: ./save-keys-to-k8s.sh .vault-keys.json"
fi
