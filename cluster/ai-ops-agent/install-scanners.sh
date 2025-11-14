#!/bin/bash
set -euo pipefail

echo "=========================================="
echo "Installing IaC Security Scanning Tools"
echo "=========================================="

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Cannot detect OS"
    exit 1
fi

echo ""
echo "Detected OS: $OS"
echo ""

# 1. Install checkov
echo "Installing checkov..."
if command -v pip3 >/dev/null 2>&1; then
    pip3 install --user checkov
    echo -e "${GREEN}✓ checkov installed${NC}"
else
    echo -e "${YELLOW}⚠ pip3 not found - install Python 3 first${NC}"
fi

# 2. Install yamllint
echo ""
echo "Installing yamllint..."
if command -v pip3 >/dev/null 2>&1; then
    pip3 install --user yamllint
    echo -e "${GREEN}✓ yamllint installed${NC}"
else
    echo -e "${YELLOW}⚠ pip3 not found - skipping yamllint${NC}"
fi

# 3. Install kubeval
echo ""
echo "Installing kubeval..."
KUBEVAL_VERSION="0.16.1"
wget -q "https://github.com/instrumenta/kubeval/releases/download/v${KUBEVAL_VERSION}/kubeval-linux-amd64.tar.gz"
tar xf kubeval-linux-amd64.tar.gz
sudo mv kubeval /usr/local/bin/
rm kubeval-linux-amd64.tar.gz
echo -e "${GREEN}✓ kubeval installed${NC}"

# 4. Install kube-score
echo ""
echo "Installing kube-score..."
KUBE_SCORE_VERSION="1.18.0"
wget -q "https://github.com/zegl/kube-score/releases/download/v${KUBE_SCORE_VERSION}/kube-score_${KUBE_SCORE_VERSION}_linux_amd64"
chmod +x "kube-score_${KUBE_SCORE_VERSION}_linux_amd64"
sudo mv "kube-score_${KUBE_SCORE_VERSION}_linux_amd64" /usr/local/bin/kube-score
echo -e "${GREEN}✓ kube-score installed${NC}"

# 5. Install kubesec
echo ""
echo "Installing kubesec..."
KUBESEC_VERSION="2.14.0"
wget -q "https://github.com/controlplaneio/kubesec/releases/download/v${KUBESEC_VERSION}/kubesec_linux_amd64.tar.gz"
tar xf kubesec_linux_amd64.tar.gz
sudo mv kubesec /usr/local/bin/
rm kubesec_linux_amd64.tar.gz
echo -e "${GREEN}✓ kubesec installed${NC}"

# 6. Install conftest
echo ""
echo "Installing conftest..."
CONFTEST_VERSION="0.49.1"
wget -q "https://github.com/open-policy-agent/conftest/releases/download/v${CONFTEST_VERSION}/conftest_${CONFTEST_VERSION}_Linux_x86_64.tar.gz"
tar xf "conftest_${CONFTEST_VERSION}_Linux_x86_64.tar.gz"
sudo mv conftest /usr/local/bin/
rm "conftest_${CONFTEST_VERSION}_Linux_x86_64.tar.gz"
echo -e "${GREEN}✓ conftest installed${NC}"

# 7. Install jq (required for kubesec output parsing)
echo ""
echo "Installing jq..."
if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    sudo apt-get update -qq
    sudo apt-get install -y -qq jq
elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ] || [ "$OS" = "fedora" ]; then
    sudo yum install -y jq
else
    echo -e "${YELLOW}⚠ Unsupported OS for jq auto-install${NC}"
fi
echo -e "${GREEN}✓ jq installed${NC}"

# Summary
echo ""
echo "=========================================="
echo "Installation Summary"
echo "=========================================="
echo ""

command -v checkov >/dev/null 2>&1 && echo -e "${GREEN}✓ checkov$(checkov --version 2>&1 | head -1)${NC}" || echo "✗ checkov"
command -v yamllint >/dev/null 2>&1 && echo -e "${GREEN}✓ yamllint $(yamllint --version)${NC}" || echo "✗ yamllint"
command -v kubeval >/dev/null 2>&1 && echo -e "${GREEN}✓ kubeval $(kubeval --version)${NC}" || echo "✗ kubeval"
command -v kube-score >/dev/null 2>&1 && echo -e "${GREEN}✓ kube-score $(kube-score version)${NC}" || echo "✗ kube-score"
command -v kubesec >/dev/null 2>&1 && echo -e "${GREEN}✓ kubesec $(kubesec version)${NC}" || echo "✗ kubesec"
command -v conftest >/dev/null 2>&1 && echo -e "${GREEN}✓ conftest $(conftest --version)${NC}" || echo "✗ conftest"
command -v jq >/dev/null 2>&1 && echo -e "${GREEN}✓ jq $(jq --version)${NC}" || echo "✗ jq"

echo ""
echo -e "${GREEN}All tools installed successfully!${NC}"
echo ""
echo "Next steps:"
echo "  cd cluster/ai-ops-agent"
echo "  ./scan.sh"
