#!/bin/bash
# =============================================================================
# Create .vault-keys.json from existing Vault credentials
# Use this if you already have unseal keys and root token
# =============================================================================

set -euo pipefail

KEYS_FILE=".vault-keys.json"

echo "=== Create Vault Keys File ==="
echo ""
echo "This will create $KEYS_FILE from your existing Vault credentials."
echo "You'll need:"
echo "  - At least 3 unseal keys (out of 5)"
echo "  - Your root token"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

echo ""
echo "Enter your unseal keys (press Enter to skip after entering at least 3):"
echo ""

UNSEAL_KEYS=()
for i in {1..5}; do
    read -p "Unseal Key $i: " key
    if [ -z "$key" ]; then
        if [ ${#UNSEAL_KEYS[@]} -lt 3 ]; then
            echo "❌ You must enter at least 3 unseal keys"
            exit 1
        fi
        break
    fi
    UNSEAL_KEYS+=("$key")
done

echo ""
read -sp "Root Token: " ROOT_TOKEN
echo ""

if [ -z "$ROOT_TOKEN" ]; then
    echo "❌ Root token is required"
    exit 1
fi

echo ""
echo "Creating $KEYS_FILE..."

# Build JSON array of unseal keys
KEYS_JSON="["
for i in "${!UNSEAL_KEYS[@]}"; do
    KEYS_JSON+="\"${UNSEAL_KEYS[$i]}\""
    if [ $i -lt $((${#UNSEAL_KEYS[@]} - 1)) ]; then
        KEYS_JSON+=","
    fi
done
KEYS_JSON+="]"

# Create the JSON file
cat > "$KEYS_FILE" <<EOF
{
  "unseal_keys_b64": $KEYS_JSON,
  "unseal_keys_hex": [],
  "unseal_shares": ${#UNSEAL_KEYS[@]},
  "unseal_threshold": 3,
  "recovery_keys_b64": [],
  "recovery_keys_hex": [],
  "recovery_keys_shares": 0,
  "recovery_keys_threshold": 0,
  "root_token": "$ROOT_TOKEN"
}
EOF

chmod 600 "$KEYS_FILE"

echo "✅ $KEYS_FILE created successfully!"
echo ""
echo "Next steps:"
echo "  1. Save keys to Kubernetes: ./save-keys-to-k8s.sh $KEYS_FILE"
echo "  2. Setup automation: ./setup-auto-unseal.sh"
echo ""
echo "⚠️  Keep a secure backup of this file!"
