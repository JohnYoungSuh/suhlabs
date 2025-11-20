#!/bin/bash
# ============================================================================
# SoftHSM Initialization Script
# Sets up software-based HSM for Vault PKI development
# ============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Initializing SoftHSM for Vault PKI${NC}"

# Configuration
SOFTHSM_TOKEN_LABEL="vault-hsm"
SOFTHSM_PIN="1234"
SOFTHSM_SO_PIN="5678"
SOFTHSM_CONF_DIR="/etc/softhsm"
SOFTHSM_TOKEN_DIR="/var/lib/softhsm/tokens"

# Check if SoftHSM is installed
if ! command -v softhsm2-util &> /dev/null; then
    echo -e "${YELLOW}SoftHSM not installed. Installing...${NC}"

    # Detect OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &> /dev/null; then
            sudo apt-get update
            sudo apt-get install -y softhsm2
        elif command -v yum &> /dev/null; then
            sudo yum install -y softhsm
        else
            echo -e "${RED}Unsupported package manager${NC}"
            exit 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install softhsm
    else
        echo -e "${RED}Unsupported OS: $OSTYPE${NC}"
        exit 1
    fi
fi

# Create directories
echo -e "${YELLOW}Creating SoftHSM directories...${NC}"
sudo mkdir -p "$SOFTHSM_CONF_DIR"
sudo mkdir -p "$SOFTHSM_TOKEN_DIR"

# Create SoftHSM config
echo -e "${YELLOW}Creating SoftHSM configuration...${NC}"
cat <<EOF | sudo tee "$SOFTHSM_CONF_DIR/softhsm2.conf" > /dev/null
# SoftHSM v2 configuration file

directories.tokendir = $SOFTHSM_TOKEN_DIR
objectstore.backend = file

# Logging
log.level = INFO

# Slots
# Default slot 0
slots.removable = false
EOF

# Set environment variable
export SOFTHSM2_CONF="$SOFTHSM_CONF_DIR/softhsm2.conf"

# Initialize token in slot 0
echo -e "${YELLOW}Initializing HSM token: $SOFTHSM_TOKEN_LABEL${NC}"

# Check if token already exists
if softhsm2-util --show-slots | grep -q "$SOFTHSM_TOKEN_LABEL"; then
    echo -e "${YELLOW}Token already exists. Deleting...${NC}"
    # SLOT_ID=$(softhsm2-util --show-slots | grep "Slot " | head -1 | awk '{print $2}')
    softhsm2-util --delete-token --token "$SOFTHSM_TOKEN_LABEL" || true
fi

# Initialize new token
softhsm2-util --init-token \
    --slot 0 \
    --label "$SOFTHSM_TOKEN_LABEL" \
    --so-pin "$SOFTHSM_SO_PIN" \
    --pin "$SOFTHSM_PIN"

# Show slots
echo -e "${GREEN}SoftHSM initialized successfully!${NC}"
echo ""
softhsm2-util --show-slots

# Save configuration for Vault
echo -e "${YELLOW}Creating Vault HSM configuration...${NC}"
cat <<EOF > vault-hsm-config.hcl
# Vault HSM Configuration for SoftHSM

seal "pkcs11" {
  lib            = "$(softhsm2-util --show-slots 2>&1 | grep 'libsofthsm2.so' | awk '{print $NF}')"
  slot           = "0"
  pin            = "$SOFTHSM_PIN"
  key_label      = "vault-root-key"
  hmac_key_label = "vault-hmac-key"
  generate_key   = "true"
}

storage "file" {
  path = "/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = true  # Will enable after cert-manager on Day 5
}

api_addr = "http://127.0.0.1:8200"
cluster_addr = "https://127.0.0.1:8201"
ui = true
EOF

echo ""
echo -e "${GREEN}Configuration saved to: vault-hsm-config.hcl${NC}"
echo ""
echo "Environment variables to set:"
echo "  export SOFTHSM2_CONF=$SOFTHSM_CONF_DIR/softhsm2.conf"
echo ""
echo "Next steps:"
echo "  1. Deploy Vault with this configuration"
echo "  2. Initialize Vault (it will generate keys in HSM)"
echo "  3. Unseal Vault (using HSM-protected keys)"
echo ""
echo "Security Note:"
echo "  SoftHSM stores keys on disk, encrypted with PIN"
echo "  For production, upgrade to YubiHSM 2 (hardware HSM)"
