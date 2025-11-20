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

# Create secret from the keys file
kubectl create secret generic "$SECRET_NAME" \
    -n "$NAMESPACE" \
    --from-file=keys="$KEYS_FILE" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✓ Unseal keys saved to Kubernetes secret: $NAMESPACE/$SECRET_NAME"
echo ""
echo "⚠️  IMPORTANT: Keep a backup of $KEYS_FILE in a secure location!"
echo "   The secret is only stored in your local Kubernetes cluster."
echo ""
echo "To auto-unseal Vault, run: ./auto-unseal.sh"
