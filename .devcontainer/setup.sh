#!/bin/bash
# =============================================================================
# Devcontainer Post-Create Setup Script
# Installs tools not available as devcontainer features
# =============================================================================

set -e

echo "🚀 Setting up AIOps Substrate devcontainer..."
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
esac

echo "Architecture: $ARCH"
echo ""

# -----------------------------------------------------------------------------
# Install Packer
# -----------------------------------------------------------------------------
echo -e "${YELLOW}Installing Packer...${NC}"
PACKER_VERSION="1.10.0"
curl -Lo packer.zip "https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_${ARCH}.zip"
sudo unzip -o packer.zip -d /usr/local/bin/
rm packer.zip
echo -e "${GREEN}✓ Packer $(packer version)${NC}"
echo ""

# -----------------------------------------------------------------------------
# Install kind
# -----------------------------------------------------------------------------
echo -e "${YELLOW}Installing kind...${NC}"
KIND_VERSION="v0.20.0"
curl -Lo ./kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${ARCH}"
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
echo -e "${GREEN}✓ kind $(kind version)${NC}"
echo ""

# -----------------------------------------------------------------------------
# Verify all tools
# -----------------------------------------------------------------------------
echo -e "${YELLOW}Verifying installations...${NC}"
echo ""

echo -e "${GREEN}✓${NC} docker: $(docker --version)"
echo -e "${GREEN}✓${NC} terraform: $(terraform version | head -n1)"
echo -e "${GREEN}✓${NC} packer: $(packer version)"
echo -e "${GREEN}✓${NC} kubectl: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
echo -e "${GREEN}✓${NC} kind: $(kind version)"
echo -e "${GREEN}✓${NC} helm: $(helm version --short)"
echo -e "${GREEN}✓${NC} ansible: $(ansible --version | head -n1)"
echo -e "${GREEN}✓${NC} gh: $(gh --version | head -n1)"

echo ""
echo -e "${GREEN}✅ Devcontainer setup complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. make dev-up      # Start Vault, Ollama, MinIO"
echo "  2. make kind-up     # Create Kubernetes cluster"
echo "  3. kubectl get nodes"
echo ""
