#!/bin/bash
# ============================================================================
# Ansible Installation Script
# Installs Ansible and ansible-lint for automation
# ============================================================================
#
# Ansible is an automation tool that:
# - Configures systems declaratively (describe desired state, not steps)
# - Is idempotent (running twice doesn't break things)
# - Uses YAML for configuration (human-readable)
# - Doesn't require agents on target systems
#
# We use Ansible to:
# - Verify foundation services are running correctly
# - Automate deployment steps
# - Test idempotency (no changes on second run)
# - Document infrastructure as code
#
# Prerequisites:
# - Python 3.8+ (Ansible is written in Python)
# - pip (Python package manager)
# - Internet connectivity
#
# Usage:
#   ./install-ansible.sh
#
# ============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Ansible Installation${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# ============================================================================
# 1. Check Prerequisites
# ============================================================================

echo -e "${YELLOW}[1/5] Checking prerequisites...${NC}"

# Check Python version
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | awk '{print $2}')
    echo -e "${GREEN}✓ Python 3 installed: ${PYTHON_VERSION}${NC}"

    # Parse version (e.g., "3.11.2" -> "3.11")
    PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d. -f1)
    PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f2)

    if [ "$PYTHON_MAJOR" -lt 3 ] || { [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 8 ]; }; then
        echo -e "${RED}✗ Python 3.8+ required (found ${PYTHON_VERSION})${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Python 3 not found${NC}"
    echo "Install Python 3.8+ first:"
    echo "  Ubuntu/Debian: sudo apt install python3 python3-pip"
    echo "  macOS: brew install python3"
    echo "  RHEL/CentOS: sudo dnf install python3 python3-pip"
    exit 1
fi

# Check pip
if command -v pip3 &> /dev/null; then
    PIP_VERSION=$(pip3 --version | awk '{print $2}')
    echo -e "${GREEN}✓ pip3 installed: ${PIP_VERSION}${NC}"
else
    echo -e "${RED}✗ pip3 not found${NC}"
    echo "Install pip3:"
    echo "  Ubuntu/Debian: sudo apt install python3-pip"
    echo "  macOS: python3 -m ensurepip"
    echo "  RHEL/CentOS: sudo dnf install python3-pip"
    exit 1
fi

echo ""

# ============================================================================
# 2. Check if Ansible is Already Installed
# ============================================================================

echo -e "${YELLOW}[2/5] Checking existing Ansible installation...${NC}"

if command -v ansible &> /dev/null; then
    ANSIBLE_VERSION=$(ansible --version | head -1 | awk '{print $2}')
    echo -e "${YELLOW}⚠ Ansible already installed: ${ANSIBLE_VERSION}${NC}"

    read -p "Reinstall/upgrade Ansible? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping Ansible installation"
        SKIP_ANSIBLE=true
    else
        SKIP_ANSIBLE=false
    fi
else
    echo "Ansible not found, will install"
    SKIP_ANSIBLE=false
fi

echo ""

# ============================================================================
# 3. Install Ansible
# ============================================================================

if [ "$SKIP_ANSIBLE" = false ]; then
    echo -e "${YELLOW}[3/5] Installing Ansible...${NC}"

    # Detect if running in virtual environment
    if [ -n "$VIRTUAL_ENV" ]; then
        PIP_USER_FLAG=""
        echo "Virtual environment detected, installing to venv..."
    else
        PIP_USER_FLAG="--user"
        echo "Installing to user directory..."
    fi

    # Determine installation method
    if [ "$(uname)" = "Darwin" ]; then
        # macOS
        echo "Installing via Homebrew (recommended for macOS)..."
        if command -v brew &> /dev/null; then
            brew install ansible
        else
            echo -e "${YELLOW}Homebrew not found, using pip3...${NC}"
            pip3 install $PIP_USER_FLAG ansible
        fi
    else
        # Linux
        echo "Installing via pip3..."
        pip3 install $PIP_USER_FLAG ansible

        # Add to PATH if not already there (only for --user installs)
        if [ -z "$VIRTUAL_ENV" ] && ! grep -q "/.local/bin" ~/.bashrc 2>/dev/null; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
            echo -e "${YELLOW}Added ~/.local/bin to PATH in ~/.bashrc${NC}"
            echo -e "${YELLOW}Run: source ~/.bashrc${NC}"
        fi
    fi

    # Verify installation
    if command -v ansible &> /dev/null; then
        ANSIBLE_VERSION=$(ansible --version | head -1)
        echo -e "${GREEN}✓ Ansible installed successfully${NC}"
        echo "  Version: ${ANSIBLE_VERSION}"
    else
        echo -e "${RED}✗ Ansible installation failed${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}[3/5] Skipping Ansible installation${NC}"
fi

echo ""

# ============================================================================
# 4. Install ansible-lint
# ============================================================================

echo -e "${YELLOW}[4/5] Installing ansible-lint...${NC}"

# Detect if running in virtual environment
if [ -n "$VIRTUAL_ENV" ]; then
    PIP_USER_FLAG=""
else
    PIP_USER_FLAG="--user"
fi

if command -v ansible-lint &> /dev/null; then
    LINT_VERSION=$(ansible-lint --version | head -1)
    echo -e "${YELLOW}⚠ ansible-lint already installed: ${LINT_VERSION}${NC}"
else
    echo "Installing ansible-lint..."
    pip3 install $PIP_USER_FLAG ansible-lint

    if command -v ansible-lint &> /dev/null; then
        LINT_VERSION=$(ansible-lint --version | head -1)
        echo -e "${GREEN}✓ ansible-lint installed successfully${NC}"
        echo "  Version: ${LINT_VERSION}"
    else
        echo -e "${YELLOW}⚠ ansible-lint installation failed (non-critical)${NC}"
    fi
fi

echo ""

# ============================================================================
# 5. Verify Installation
# ============================================================================

echo -e "${YELLOW}[5/5] Verifying installation...${NC}"

# Test Ansible
echo "Testing ansible command..."
if ansible --version &> /dev/null; then
    echo -e "${GREEN}✓ ansible command works${NC}"
else
    echo -e "${RED}✗ ansible command failed${NC}"
    exit 1
fi

# Test ansible-playbook
echo "Testing ansible-playbook command..."
if ansible-playbook --version &> /dev/null; then
    echo -e "${GREEN}✓ ansible-playbook command works${NC}"
else
    echo -e "${RED}✗ ansible-playbook command failed${NC}"
    exit 1
fi

# Test ansible-galaxy
echo "Testing ansible-galaxy command..."
if ansible-galaxy --version &> /dev/null; then
    echo -e "${GREEN}✓ ansible-galaxy command works${NC}"
else
    echo -e "${YELLOW}⚠ ansible-galaxy command failed (non-critical)${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Display versions
echo -e "${BLUE}Installed Versions:${NC}"
ansible --version | head -5
echo ""

echo -e "${BLUE}Useful Commands:${NC}"
echo "  # Check Ansible version"
echo "  ansible --version"
echo ""
echo "  # Test connection to localhost"
echo "  ansible localhost -m ping"
echo ""
echo "  # Run ad-hoc command"
echo "  ansible localhost -m shell -a 'uptime'"
echo ""
echo "  # Run playbook"
echo "  ansible-playbook playbooks/verify-foundation.yml"
echo ""
echo "  # Lint playbooks"
echo "  ansible-lint playbooks/*.yml"
echo ""

echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Create inventory: cd ansible && vim inventory/local.yml"
echo "  2. Test connection: ansible -i inventory/local.yml localhost -m ping"
echo "  3. Create playbooks: cd playbooks"
echo ""

echo -e "${BLUE}Documentation:${NC}"
echo "  - Getting Started: https://docs.ansible.com/ansible/latest/getting_started/"
echo "  - Best Practices: https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html"
echo "  - Module Index: https://docs.ansible.com/ansible/latest/modules/modules_by_category.html"
echo ""
