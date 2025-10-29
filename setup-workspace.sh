#!/bin/bash
# =============================================================================
# AIOps Substrate – VS Code Workspace Setup
# Creates folders + .code-workspace for WSL2 + Docker Desktop + Proxmox
# =============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}AIOps Substrate – Creating VS Code Workspace${NC}"

# Project root (current directory)
PROJECT_ROOT="$(pwd)"
WORKSPACE_FILE="${PROJECT_ROOT}/aiops-substrate.code-workspace"

# ----------------------------------------------------------------------
# 1. Create Directory Structure
# ----------------------------------------------------------------------
echo -e "${YELLOW}Creating folder structure...${NC}"

mkdir -p .devcontainer
mkdir -p .github/workflows
mkdir -p bootstrap
mkdir -p infra/local
mkdir -p infra/proxmox
mkdir -p infra/schemas
mkdir -p services/dns
mkdir -p services/samba
mkdir -p services/pki
mkdir -p cluster/k3s/local
mkdir -p cluster/k3s/prod
mkdir -p cluster/ai-ops-agent
mkdir -p docs
mkdir -p inventory
mkdir -p .vscode

# ----------------------------------------------------------------------
# 2. Create Dev Container (Optional but Recommended)
# ----------------------------------------------------------------------
cat > .devcontainer/devcontainer.json << 'EOF'
{
  "name": "AIOps Substrate (WSL2 + Docker)",
  "image": "mcr.microsoft.com/devcontainers/python:3.11",
  "features": {
    "ghcr.io/devcontainers/features/docker-in-docker:2": {},
    "ghcr.io/devcontainers/features/terraform:1": {},
    "ghcr.io/devcontainers/features/ansible:1": {},
    "ghcr.io/devcontainers/features/kubectl:1": {},
    "ghcr.io/devcontainers/features/github-cli:1": {}
  },
  "forwardPorts": [30080, 8200, 11434, 9000],
  "postCreateCommand": "make init-local || true",
  "remoteUser": "vscode",
  "mounts": [
    "source=/var/run/docker.sock,target=/var/run/docker.sock,type=bind"
  ],
  "customizations": {
    "vscode": {
      "extensions": [
        "hashicorp.terraform",
        "ms-python.python",
        "redhat.ansible",
        "ms-kubernetes-tools.vscode-kubernetes-tools",
        "tamasfe.even-better-toml",
        "github.vscode-pull-request-github",
        "ms-azuretools.vscode-docker",
        "eamodio.gitlens"
      ],
      "settings": {
        "terminal.integrated.defaultProfile.linux": "bash"
      }
    }
  }
}
EOF

# ----------------------------------------------------------------------
# 3. Create VS Code Settings
# ----------------------------------------------------------------------
cat > .vscode/settings.json << 'EOF'
{
  "terminal.integrated.profiles.windows": {
    "WSL Ubuntu": {
      "path": "wsl.exe",
      "args": ["-d", "Ubuntu-22.04"]
    }
  },
  "terminal.integrated.defaultProfile.windows": "WSL Ubuntu",
  "terraform.languageServer": {
    "enabled": true
  },
  "ansible.python.interpreterPath": "/usr/bin/python3"
}
EOF

# ----------------------------------------------------------------------
# 4. Create .gitignore
# ----------------------------------------------------------------------
cat > .gitignore << 'EOF'
# Terraform
*.tfstate
*.tfstate.*
*.tfplan
.terraform/
.terraform.lock.hcl

# Ansible
*.retry
inventory/*.ini

# Local Dev
bootstrap/*.log
.devcontainer/*.dev

# VS Code
.vscode/*.code-workspace
*.code-workspace

# General
__pycache__/
*.pyc
.env
EOF

# ----------------------------------------------------------------------
# 5. Create Multi-Root Workspace File
# ----------------------------------------------------------------------
cat > "${WORKSPACE_FILE}" << EOF
{
  "folders": [
    {
      "name": "Root",
      "path": "."
    },
    {
      "name": "Terraform: Local (kind)",
      "path": "./infra/local"
    },
    {
      "name": "Terraform: Proxmox",
      "path": "./infra/proxmox"
    },
    {
      "name": "Ansible: Services",
      "path": "./services"
    },
    {
      "name": "Kubernetes: k3s",
      "path": "./cluster/k3s"
    },
    {
      "name": "AI Ops Agent",
      "path": "./cluster/ai-ops-agent"
    },
    {
      "name": "Docs & Bootstrap",
      "path": "./docs"
    }
  ],
  "settings": {
    "terminal.integrated.defaultProfile.windows": "WSL Ubuntu",
    "files.exclude": {
      "**/.terraform": true,
      "**/*.tfstate*": true
    },
    "search.exclude": {
      "**/.terraform": true,
      "**/node_modules": true
    }
  },
  "extensions": {
    "recommendations": [
      "hashicorp.terraform",
      "ms-python.python",
      "redhat.ansible",
      "ms-kubernetes-tools.vscode-kubernetes-tools",
      "ms-azuretools.vscode-docker",
      "github.vscode-pull-request-github",
      "eamodio.gitlens"
    ]
  }
}
EOF

# ----------------------------------------------------------------------
# 6. Create Placeholder Files
# ----------------------------------------------------------------------
touch Makefile
touch bootstrap/docker-compose.yml
touch bootstrap/kind-cluster.yaml
touch infra/local/main.tf
touch infra/proxmox/main.tf
touch services/dns/playbook.yml
touch cluster/ai-ops-agent/Dockerfile
touch docs/architecture.md

# ----------------------------------------------------------------------
# 7. Final Output
# ----------------------------------------------------------------------
echo -e "${GREEN}Workspace created successfully!${NC}"
echo
echo -e "   ${YELLOW}File:${NC} $WORKSPACE_FILE"
echo -e "   ${YELLOW}Open in VS Code:${NC}"
echo
echo "   code \"$WORKSPACE_FILE\""
echo
echo -e "   ${BLUE}Next Steps:${NC}"
echo "   1. Run: code aiops-substrate.code-workspace"
echo "   2. Open terminal in VS Code → run: make dev-up"
echo "   3. Start coding!"

# ----------------------------------------------------------------------
# 8. Auto-open VS Code (optional)
# ----------------------------------------------------------------------
if command -v code >/dev/null 2>&1; then
  read -p "Open in VS Code now? (y/N): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    code "$WORKSPACE_FILE"
  fi
else
  echo -e "${YELLOW}VS Code not found. Install from: https://code.visualstudio.com${NC}"
fi

exit 0
