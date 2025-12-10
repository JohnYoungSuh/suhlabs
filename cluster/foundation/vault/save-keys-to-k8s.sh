#!/bin/bash
# =============================================================================
# Save Vault Unseal Keys to Kubernetes Secret (One-time setup)
# Run this once after initializing Vault
# =============================================================================

set -euo pipefail

NAMESPACE="vault"
SECRET_NAME="vault-unseal-keys"
KEYS_FILE="${1:-.vault-keys.json}"

if [ ! -f "$KEYS_FILE" ]; then
    echo "Error: Keys file not found: $KEYS_FILE"
    echo "Usage: $0 [path-to-vault-keys.json]"
    exit 1
fi

echo "Creating Kubernetes secret from $KEYS_FILE..."

# Parse keys using jq
KEY_0=$(jq -r '.unseal_keys_b64[0]' "$KEYS_FILE")
KEY_1=$(jq -r '.unseal_keys_b64[1]' "$KEYS_FILE")
KEY_2=$(jq -r '.unseal_keys_b64[2]' "$KEYS_FILE")
ROOT_TOKEN=$(jq -r '.root_token' "$KEYS_FILE")

# Create secret with individual keys
kubectl create secret generic "$SECRET_NAME" \
    -n "$NAMESPACE" \
    --from-literal=unseal_key_0="$KEY_0" \
    --from-literal=unseal_key_1="$KEY_1" \
    --from-literal=unseal_key_2="$KEY_2" \
    --from-literal=root_token="$ROOT_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✓ Unseal keys saved to Kubernetes secret: $NAMESPACE/$SECRET_NAME"
echo ""
echo "⚠️  IMPORTANT: Keep a backup of $KEYS_FILE in a secure location!"
echo "   The secret is only stored in your local Kubernetes cluster."
echo ""
echo "To auto-unseal Vault, run: ./auto-unseal.sh"
