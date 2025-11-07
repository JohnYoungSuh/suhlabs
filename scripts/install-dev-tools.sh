#!/bin/bash
# =============================================================================
# Install Development Tools for AIOps Substrate
# Installs: kind, kubectl, helm, ansible
# Platform: Linux/WSL2
# =============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Installing development tools for AIOps Substrate...${NC}"
echo ""

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        ARCH="amd64"
        ;;
    aarch64|arm64)
        ARCH="arm64"
        ;;
    *)
        echo -e "${RED}Unsupported architecture: $ARCH${NC}"
        exit 1
        ;;
esac

echo "Detected architecture: $ARCH"
echo ""

# -----------------------------------------------------------------------------
# 1. Install kubectl
# -----------------------------------------------------------------------------
echo -e "${GREEN}[1/4] Installing kubectl...${NC}"
if command -v kubectl &> /dev/null; then
    echo "kubectl already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
else
    KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    echo "kubectl installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
fi
echo ""

# -----------------------------------------------------------------------------
# 2. Install kind
# -----------------------------------------------------------------------------
echo -e "${GREEN}[2/4] Installing kind...${NC}"
if command -v kind &> /dev/null; then
    echo "kind already installed: $(kind version)"
else
    KIND_VERSION="v0.20.0"
    curl -Lo ./kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${ARCH}"
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
    echo "kind installed: $(kind version)"
fi
echo ""

# -----------------------------------------------------------------------------
# 3. Install Helm
# -----------------------------------------------------------------------------
echo -e "${GREEN}[3/4] Installing Helm...${NC}"
if command -v helm &> /dev/null; then
    echo "helm already installed: $(helm version --short)"
else
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    echo "helm installed: $(helm version --short)"
fi
echo ""

# -----------------------------------------------------------------------------
# 4. Install Ansible
# -----------------------------------------------------------------------------
echo -e "${GREEN}[4/4] Installing Ansible...${NC}"
if command -v ansible &> /dev/null; then
    echo "ansible already installed: $(ansible --version | head -n1)"
else
    sudo apt update
    sudo apt install -y software-properties-common
    sudo add-apt-repository --yes --update ppa:ansible/ansible
    sudo apt install -y ansible
    echo "ansible installed: $(ansible --version | head -n1)"
fi
echo ""

# -----------------------------------------------------------------------------
# Verification
# -----------------------------------------------------------------------------
echo -e "${YELLOW}Verifying installations...${NC}"
echo ""

ERRORS=0

if command -v kubectl &> /dev/null; then
    echo -e "${GREEN}✓${NC} kubectl: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
else
    echo -e "${RED}✗${NC} kubectl: NOT FOUND"
    ((ERRORS++))
fi

if command -v kind &> /dev/null; then
    echo -e "${GREEN}✓${NC} kind: $(kind version)"
else
    echo -e "${RED}✗${NC} kind: NOT FOUND"
    ((ERRORS++))
fi

if command -v helm &> /dev/null; then
    echo -e "${GREEN}✓${NC} helm: $(helm version --short)"
else
    echo -e "${RED}✗${NC} helm: NOT FOUND"
    ((ERRORS++))
fi

if command -v ansible &> /dev/null; then
    echo -e "${GREEN}✓${NC} ansible: $(ansible --version | head -n1)"
else
    echo -e "${RED}✗${NC} ansible: NOT FOUND"
    ((ERRORS++))
fi

if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓${NC} docker: $(docker --version)"
else
    echo -e "${RED}✗${NC} docker: NOT FOUND (install Docker Desktop or Docker Engine)"
    ((ERRORS++))
fi

echo ""

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}All tools installed successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. make dev-up      # Start local services (Vault, Ollama, MinIO)"
    echo "  2. make kind-up     # Create Kubernetes cluster"
    echo "  3. kubectl get nodes"
    exit 0
else
    echo -e "${RED}Installation incomplete. $ERRORS tool(s) missing.${NC}"
    exit 1
fi
