#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="${SCRIPT_DIR}/k8s"

echo "=========================================="
echo "IaC Security & Compliance Scanning"
echo "Target: ai-ops-agent Kubernetes manifests"
echo "=========================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track overall status
FAILED=0

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print section header
print_section() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
}

# Function to handle tool missing
tool_missing() {
    echo -e "${YELLOW}⚠ $1 not installed - skipping${NC}"
    echo "Install: $2"
}

# 1. Checkov - Security and compliance scanning
print_section "1. Checkov - Security & Compliance Scanning"
if command_exists checkov; then
    echo "Running checkov on Kubernetes manifests..."
    if checkov -d "${K8S_DIR}" --framework kubernetes --quiet --compact; then
        echo -e "${GREEN}✓ Checkov passed${NC}"
    else
        echo -e "${RED}✗ Checkov found issues${NC}"
        FAILED=1
    fi
else
    tool_missing "checkov" "pip3 install checkov"
fi

# 2. kubeval - Kubernetes YAML validation
print_section "2. kubeval - Kubernetes YAML Validation"
if command_exists kubeval; then
    echo "Validating Kubernetes manifests..."
    if kubeval --strict "${K8S_DIR}"/*.yaml; then
        echo -e "${GREEN}✓ kubeval passed${NC}"
    else
        echo -e "${RED}✗ kubeval found issues${NC}"
        FAILED=1
    fi
else
    tool_missing "kubeval" "https://github.com/instrumenta/kubeval/releases"
fi

# 3. kube-score - Kubernetes best practices
print_section "3. kube-score - Best Practices Analysis"
if command_exists kube-score; then
    echo "Analyzing Kubernetes best practices..."
    if kube-score score "${K8S_DIR}"/*.yaml --output-format ci; then
        echo -e "${GREEN}✓ kube-score passed${NC}"
    else
        echo -e "${RED}✗ kube-score found issues${NC}"
        FAILED=1
    fi
else
    tool_missing "kube-score" "https://github.com/zegl/kube-score#installation"
fi

# 4. kubesec - Security risk analysis
print_section "4. kubesec - Security Risk Analysis"
if command_exists kubesec; then
    echo "Scanning for security risks..."
    for file in "${K8S_DIR}"/*.yaml; do
        echo "Scanning $(basename "$file")..."
        if kubesec scan "$file" | jq -e '.[0].score >= 5' >/dev/null; then
            echo -e "${GREEN}✓ $(basename "$file") passed (score >= 5)${NC}"
        else
            echo -e "${RED}✗ $(basename "$file") failed (score < 5)${NC}"
            kubesec scan "$file" | jq '.[0] | {score, scoring}'
            FAILED=1
        fi
    done
else
    tool_missing "kubesec" "https://github.com/controlplaneio/kubesec#installation"
fi

# 5. Conftest - OPA policy validation
print_section "5. Conftest - OPA Policy Validation"
if command_exists conftest; then
    POLICY_DIR="${SCRIPT_DIR}/policies"
    if [ -d "$POLICY_DIR" ]; then
        echo "Running OPA policy validation..."
        if conftest test "${K8S_DIR}" --policy "${POLICY_DIR}"; then
            echo -e "${GREEN}✓ conftest passed${NC}"
        else
            echo -e "${RED}✗ conftest found policy violations${NC}"
            FAILED=1
        fi
    else
        echo -e "${YELLOW}⚠ Policy directory not found: ${POLICY_DIR}${NC}"
        echo "Create policies using: ./create-policies.sh"
    fi
else
    tool_missing "conftest" "https://www.conftest.dev/install/"
fi

# 6. YAML Lint - Syntax validation
print_section "6. yamllint - YAML Syntax Validation"
if command_exists yamllint; then
    echo "Validating YAML syntax..."
    if yamllint -d relaxed "${K8S_DIR}"/*.yaml; then
        echo -e "${GREEN}✓ yamllint passed${NC}"
    else
        echo -e "${RED}✗ yamllint found issues${NC}"
        FAILED=1
    fi
else
    tool_missing "yamllint" "pip3 install yamllint"
fi

# 7. Custom validation - Check for common issues
print_section "7. Custom Validation - Common Issues"
echo "Checking for common misconfigurations..."

# Check for missing resource limits
if grep -L "resources:" "${K8S_DIR}"/*.yaml | grep -v certificate | grep -v service; then
    echo -e "${YELLOW}⚠ Some files missing resource limits${NC}"
fi

# Check for privileged containers
if grep -r "privileged: true" "${K8S_DIR}"; then
    echo -e "${RED}✗ Privileged containers found${NC}"
    FAILED=1
fi

# Check for hostNetwork
if grep -r "hostNetwork: true" "${K8S_DIR}"; then
    echo -e "${YELLOW}⚠ hostNetwork enabled${NC}"
fi

# Check for latest tags
if grep -r "image:.*:latest" "${K8S_DIR}"; then
    echo -e "${YELLOW}⚠ Images using 'latest' tag found${NC}"
fi

# Check for hard-coded secrets
if grep -ri "password\|secret\|apikey" "${K8S_DIR}" | grep -v "secretName\|Secret\|# "; then
    echo -e "${RED}✗ Possible hard-coded secrets found${NC}"
    FAILED=1
fi

echo -e "${GREEN}✓ Custom validation complete${NC}"

# Summary
print_section "Scan Summary"
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All scans passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some scans failed - review output above${NC}"
    exit 1
fi
