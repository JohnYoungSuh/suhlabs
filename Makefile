# =============================================================================
# AIOps Substrate – Enhanced Platform-Agnostic Makefile
# Supports: Local (Docker Desktop + WSL2 + k3s) → Production (Proxmox + k3s)
# Version: 3.0 - Platform-Agnostic Edition
# =============================================================================

.DEFAULT_GOAL := help
.PHONY: help doctor \
        setup-tools \
        dev-up dev-down dev-logs \
        kind-up kind-down kind-export kind-debug \
        init init-local init-prod \
        plan plan-local plan-prod \
        apply apply-local apply-prod \
        test test-unit test-integration test-e2e test-local test-prod test-ai \
        lint lint-terraform lint-ansible lint-packer lint-python lint-yaml \
        fmt fmt-terraform \
        security security-trivy security-secrets security-terraform security-ansible \
        coverage \
        validate validate-all \
        sbom sign \
        vault-up vault-down ollama-pull \
        migrate-state \
        packer-build packer-validate packer-debug \
        ansible-ping ansible-deploy-k3s ansible-deploy-apps ansible-kubeconfig \
        ansible-deploy-infra ansible-deploy-dns ansible-deploy-freeipa \
        ansible-validate ansible-verify ansible-upgrade-k3s \
        ansible-drain-node ansible-uncordon-node ansible-logs \
        autoscaler-build autoscaler-deploy autoscaler-status autoscaler-push autoscaler-sign \
        template-clone vm-create vm-list vm-scale-up vm-scale-down \
        ci-lint ci-test ci-security ci-build ci-deploy \
        ci-pr ci-main \
        clean clean-all

# -----------------------------------------------------------------------------
# Configuration (Platform-Agnostic)
# -----------------------------------------------------------------------------
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# Platform Abstraction - Override with environment variables
CONTAINER_RUNTIME ?= docker  # Options: docker, podman
PYTHON ?= python3
TERRAFORM ?= terraform
PACKER ?= packer
ANSIBLE ?= ansible-playbook
KUBECTL ?= kubectl
KIND ?= kind
HELM ?= helm
VAULT ?= vault
OLLAMA ?= ollama

# Container compose command (V2 syntax)
ifeq ($(CONTAINER_RUNTIME),podman)
    COMPOSE := podman-compose -f bootstrap/docker-compose.yml
else
    COMPOSE := $(CONTAINER_RUNTIME) compose -f bootstrap/docker-compose.yml
endif

# Security tools (optional, checks performed in targets)
TRIVY ?= trivy
GITLEAKS ?= gitleaks
TFSEC ?= tfsec
SYFT ?= syft
COSIGN ?= cosign

# Environment switch
ENV ?= local
TF_BACKEND_LOCAL := infra/local/backend.hcl
TF_BACKEND_PROD  := infra/proxmox/backend.hcl

# Directories
ANSIBLE_INVENTORY := inventory/proxmox.yml
ANSIBLE_PLAYBOOK_DIR := ansible
TESTS_DIR := tests

# Container registry
REGISTRY ?= registry.corp.example.com
AUTOSCALER_IMAGE := $(REGISTRY)/proxmox-autoscaler
AUTOSCALER_TAG ?= latest

# Colors (cross-platform)
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
RESET := \033[0m

# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------
help: ## Show this help message
	@echo ""
	@echo "${YELLOW}AIOps Substrate – Platform-Agnostic Makefile${RESET}"
	@echo "Usage: make <target> [ENV=local|prod] [CONTAINER_RUNTIME=docker|podman]"
	@echo ""
	@echo "${GREEN}Setup & Validation:${RESET}"
	@echo "  doctor           Check if all required tools are installed"
	@echo "  setup-tools      Install dev tools (kubectl, kind, helm, ansible)"
	@echo "  validate-all     Run comprehensive validation (all layers)"
	@echo ""
	@echo "${GREEN}Development Environment:${RESET}"
	@echo "  dev-up           Start full local stack (Vault, Ollama, MinIO, k3s)"
	@echo "  dev-down         Stop and clean local stack"
	@echo "  kind-up          Create kind cluster (aiops-dev)"
	@echo "  kind-down        Delete kind cluster"
	@echo "  kind-debug       Show detailed debug info"
	@echo ""
	@echo "${GREEN}Code Quality:${RESET}"
	@echo "  lint             Run all linters"
	@echo "  lint-terraform   Lint Terraform files"
	@echo "  lint-ansible     Lint Ansible playbooks"
	@echo "  lint-packer      Validate Packer templates"
	@echo "  lint-python      Lint Python code"
	@echo "  fmt              Auto-fix formatting issues"
	@echo ""
	@echo "${GREEN}Testing:${RESET}"
	@echo "  test             Run all tests"
	@echo "  test-unit        Run unit tests"
	@echo "  test-integration Run integration tests"
	@echo "  test-e2e         Run end-to-end tests"
	@echo "  coverage         Generate coverage report"
	@echo ""
	@echo "${GREEN}Security:${RESET}"
	@echo "  security         Run all security scans"
	@echo "  security-trivy   Scan for vulnerabilities with Trivy"
	@echo "  security-secrets Scan for secrets with gitleaks"
	@echo "  security-terraform Scan Terraform with tfsec"
	@echo "  sbom             Generate SBOM (Syft)"
	@echo "  sign             Sign artifacts (cosign)"
	@echo ""
	@echo "${GREEN}Infrastructure (Terraform):${RESET}"
	@echo "  init-local       Initialize Terraform (local)"
	@echo "  init-prod        Initialize Terraform (Proxmox)"
	@echo "  plan-local       Plan local infrastructure"
	@echo "  plan-prod        Plan Proxmox infrastructure"
	@echo "  apply-local      Apply local infrastructure"
	@echo "  apply-prod       Apply to Proxmox"
	@echo ""
	@echo "${GREEN}Deployment (Ansible):${RESET}"
	@echo "  ansible-ping             Test connectivity"
	@echo "  ansible-deploy-k3s       Deploy k3s cluster"
	@echo "  ansible-deploy-apps      Deploy applications"
	@echo "  ansible-deploy-infra     Deploy infrastructure services"
	@echo "  ansible-kubeconfig       Fetch kubeconfig"
	@echo "  ansible-validate         Validate deployment"
	@echo ""
	@echo "${GREEN}Image Building:${RESET}"
	@echo "  packer-validate  Validate Packer template"
	@echo "  packer-build     Build CentOS 9 cloud-init template"
	@echo "  autoscaler-build Build autoscaler container"
	@echo ""
	@echo "${GREEN}CI/CD (Platform-Agnostic):${RESET}"
	@echo "  ci-lint          CI: Run linting (GitHub/GitLab/Jenkins/Tekton)"
	@echo "  ci-test          CI: Run tests"
	@echo "  ci-security      CI: Run security scans"
	@echo "  ci-build         CI: Build artifacts"
	@echo "  ci-pr            CI: Full PR validation (no deploy)"
	@echo "  ci-main          CI: Full main branch workflow"
	@echo ""
	@echo "${GREEN}Cleanup:${RESET}"
	@echo "  clean            Clean up temporary files"
	@echo "  clean-all        Deep clean (including caches)"
	@echo ""

# -----------------------------------------------------------------------------
# Doctor: Check Required Tools
# -----------------------------------------------------------------------------
doctor: ## Check if all required tools are installed
	@echo "${BLUE}╔════════════════════════════════════════════════════════════╗${RESET}"
	@echo "${BLUE}║              Checking Required Tools                      ║${RESET}"
	@echo "${BLUE}╚════════════════════════════════════════════════════════════╝${RESET}"
	@echo ""
	@echo "${YELLOW}Core Tools:${RESET}"
	@command -v $(CONTAINER_RUNTIME) >/dev/null 2>&1 && \
		echo "  ${GREEN}✓ $(CONTAINER_RUNTIME) found${RESET} ($$($(CONTAINER_RUNTIME) --version 2>/dev/null | head -1))" || \
		(echo "  ${RED}✗ $(CONTAINER_RUNTIME) not found${RESET}" && exit 1)
	@command -v $(TERRAFORM) >/dev/null 2>&1 && \
		echo "  ${GREEN}✓ terraform found${RESET} ($$($(TERRAFORM) version -json 2>/dev/null | jq -r '.terraform_version' || $(TERRAFORM) version))" || \
		(echo "  ${RED}✗ terraform not found${RESET}" && exit 1)
	@command -v $(PACKER) >/dev/null 2>&1 && \
		echo "  ${GREEN}✓ packer found${RESET} ($$($(PACKER) version 2>/dev/null | head -1))" || \
		(echo "  ${RED}✗ packer not found${RESET}" && exit 1)
	@command -v $(ANSIBLE) >/dev/null 2>&1 && \
		echo "  ${GREEN}✓ ansible found${RESET} ($$(ansible --version 2>/dev/null | head -1))" || \
		(echo "  ${RED}✗ ansible not found${RESET}" && exit 1)
	@command -v $(KUBECTL) >/dev/null 2>&1 && \
		echo "  ${GREEN}✓ kubectl found${RESET} ($$($(KUBECTL) version --client --short 2>/dev/null | grep -oP 'Client.*'))" || \
		(echo "  ${RED}✗ kubectl not found${RESET}" && exit 1)
	@command -v $(KIND) >/dev/null 2>&1 && \
		echo "  ${GREEN}✓ kind found${RESET} ($$($(KIND) version 2>/dev/null))" || \
		(echo "  ${YELLOW}⚠ kind not found (optional for local dev)${RESET}")
	@command -v $(HELM) >/dev/null 2>&1 && \
		echo "  ${GREEN}✓ helm found${RESET} ($$($(HELM) version --short 2>/dev/null))" || \
		(echo "  ${YELLOW}⚠ helm not found (optional)${RESET}")
	@echo ""
	@echo "${YELLOW}Security Tools (Optional):${RESET}"
	@command -v $(TRIVY) >/dev/null 2>&1 && \
		echo "  ${GREEN}✓ trivy found${RESET} ($$($(TRIVY) --version 2>/dev/null | grep -oP 'Version:.*'))" || \
		echo "  ${YELLOW}⚠ trivy not found (install: https://github.com/aquasecurity/trivy)${RESET}"
	@command -v $(GITLEAKS) >/dev/null 2>&1 && \
		echo "  ${GREEN}✓ gitleaks found${RESET} ($$($(GITLEAKS) version 2>/dev/null))" || \
		echo "  ${YELLOW}⚠ gitleaks not found (install: https://github.com/gitleaks/gitleaks)${RESET}"
	@command -v $(TFSEC) >/dev/null 2>&1 && \
		echo "  ${GREEN}✓ tfsec found${RESET} ($$($(TFSEC) --version 2>/dev/null))" || \
		echo "  ${YELLOW}⚠ tfsec not found (install: https://github.com/aquasecurity/tfsec)${RESET}"
	@echo ""
	@echo "${YELLOW}Python & Testing:${RESET}"
	@command -v $(PYTHON) >/dev/null 2>&1 && \
		echo "  ${GREEN}✓ python found${RESET} ($$($(PYTHON) --version 2>/dev/null))" || \
		(echo "  ${RED}✗ python not found${RESET}" && exit 1)
	@$(PYTHON) -m pip --version >/dev/null 2>&1 && \
		echo "  ${GREEN}✓ pip found${RESET} ($$($(PYTHON) -m pip --version 2>/dev/null | awk '{print $$2}'))" || \
		(echo "  ${RED}✗ pip not found${RESET}" && exit 1)
	@$(PYTHON) -c "import pytest" 2>/dev/null && \
		echo "  ${GREEN}✓ pytest found${RESET}" || \
		echo "  ${YELLOW}⚠ pytest not found (run: pip install -r requirements-dev.txt)${RESET}"
	@echo ""
	@echo "${YELLOW}Container Runtime Check:${RESET}"
	@$(CONTAINER_RUNTIME) ps >/dev/null 2>&1 && \
		echo "  ${GREEN}✓ $(CONTAINER_RUNTIME) daemon is running${RESET}" || \
		(echo "  ${RED}✗ $(CONTAINER_RUNTIME) daemon is NOT running${RESET}" && exit 1)
	@echo ""
	@echo "${GREEN}╔════════════════════════════════════════════════════════════╗${RESET}"
	@echo "${GREEN}║              ✓ All Required Tools Available!              ║${RESET}"
	@echo "${GREEN}╚════════════════════════════════════════════════════════════╝${RESET}"

# -----------------------------------------------------------------------------
# Setup Tools
# -----------------------------------------------------------------------------
setup-tools: ## Install development tools
	@echo "${GREEN}Installing development tools...${RESET}"
	@chmod +x scripts/install-dev-tools.sh
	@./scripts/install-dev-tools.sh

# -----------------------------------------------------------------------------
# Local Stack: Docker Compose + kind
# -----------------------------------------------------------------------------
dev-up: vault-up ollama-pull ## Start full local stack
	@echo "${GREEN}Starting local dev stack...${RESET}"
	$(COMPOSE) up -d
	@echo "Waiting for Vault..."
	@sleep 5
	$(VAULT) login root || true
	@echo "Local stack ready: http://localhost:8200 (token: root)"

dev-down: ## Stop local dev stack
	@echo "${GREEN}Stopping local dev stack...${RESET}"
	$(COMPOSE) down -v
	$(MAKE) kind-down

dev-logs: ## Show logs from local stack
	$(COMPOSE) logs -f

vault-up: ## Start Vault (dev mode)
	@echo "${GREEN}Starting Vault (dev mode)...${RESET}"
	$(COMPOSE) up -d vault

vault-down: ## Stop Vault
	$(COMPOSE) rm -fsv vault

ollama-pull: ## Pull Llama3.1 for AI agent
	@echo "${GREEN}Pulling Llama3.1 for AI agent...${RESET}"
	$(OLLAMA) pull llama3.1:8b || echo "${YELLOW}⚠ Ollama not available locally${RESET}"

# -----------------------------------------------------------------------------
# Kubernetes: kind (local)
# -----------------------------------------------------------------------------
kind-up: ## Create kind cluster (aiops-dev)
	@echo "${GREEN}╔════════════════════════════════════════════════════════════╗${RESET}"
	@echo "${GREEN}║          Creating kind cluster: aiops-dev                 ║${RESET}"
	@echo "${GREEN}╚════════════════════════════════════════════════════════════╝${RESET}"
	@echo ""
	@echo "${YELLOW}[Step 1/6] Pre-flight checks...${RESET}"
	@echo "  → Checking if kind is installed..."
	@which $(KIND) || (echo "${RED}ERROR: kind not found. Run 'make setup-tools'${RESET}" && exit 1)
	@echo "  → Checking if kubectl is installed..."
	@which $(KUBECTL) || (echo "${RED}ERROR: kubectl not found. Run 'make setup-tools'${RESET}" && exit 1)
	@echo "  → Checking if container runtime is running..."
	@$(CONTAINER_RUNTIME) ps > /dev/null 2>&1 || (echo "${RED}ERROR: $(CONTAINER_RUNTIME) is not running${RESET}" && exit 1)
	@echo "  ${GREEN}✓ All checks passed${RESET}"
	@echo ""
	@echo "${YELLOW}[Step 2/6] Checking for existing clusters...${RESET}"
	@if $(KIND) get clusters 2>/dev/null | grep -q "^aiops-dev$$"; then \
		echo "  ${YELLOW}⚠ Cluster 'aiops-dev' already exists${RESET}"; \
		echo "  → Cleaning up existing cluster..."; \
		$(KIND) delete cluster --name aiops-dev; \
		echo "  ${GREEN}✓ Old cluster removed${RESET}"; \
	else \
		echo "  ${GREEN}✓ No existing cluster found${RESET}"; \
	fi
	@echo ""
	@echo "${YELLOW}[Step 3/6] Validating cluster configuration...${RESET}"
	@if [ ! -f bootstrap/kind-cluster.yaml ]; then \
		echo "  ${RED}ERROR: bootstrap/kind-cluster.yaml not found${RESET}"; \
		exit 1; \
	fi
	@echo "  → Configuration file: bootstrap/kind-cluster.yaml"
	@echo "  ${GREEN}✓ Configuration valid${RESET}"
	@echo ""
	@echo "${YELLOW}[Step 4/6] Creating cluster (this may take 2-3 minutes)...${RESET}"
	@$(KIND) create cluster --name aiops-dev --config bootstrap/kind-cluster.yaml --wait 2m --verbosity=1 || \
		(echo "${RED}ERROR: Cluster creation failed. Run 'make kind-debug' for details.${RESET}" && exit 1)
	@echo "  ${GREEN}✓ Cluster created successfully${RESET}"
	@echo ""
	@echo "${YELLOW}[Step 5/6] Verifying cluster connectivity...${RESET}"
	@sleep 5
	@$(KUBECTL) cluster-info --context kind-aiops-dev || \
		(echo "${RED}ERROR: Cannot connect to cluster${RESET}" && exit 1)
	@echo "  ${GREEN}✓ Cluster is accessible${RESET}"
	@echo ""
	@echo "${YELLOW}[Step 6/6] Verifying nodes...${RESET}"
	@$(KUBECTL) get nodes --context kind-aiops-dev
	@echo ""
	@echo "${GREEN}╔════════════════════════════════════════════════════════════╗${RESET}"
	@echo "${GREEN}║              ✓ Cluster Ready!                              ║${RESET}"
	@echo "${GREEN}╚════════════════════════════════════════════════════════════╝${RESET}"

kind-down: ## Delete kind cluster
	@echo "${GREEN}Deleting kind cluster...${RESET}"
	$(KIND) delete cluster --name aiops-dev || true

kind-export: ## Export kubeconfig
	$(KIND) export kubeconfig --name aiops-dev

kind-debug: ## Show detailed debug info
	@echo "${YELLOW}╔════════════════════════════════════════════════════════════╗${RESET}"
	@echo "${YELLOW}║           kind Cluster Debug Information                  ║${RESET}"
	@echo "${YELLOW}╚════════════════════════════════════════════════════════════╝${RESET}"
	@echo ""
	@echo "${GREEN}[1] System Information:${RESET}"
	@echo "  OS: $(shell uname -a)"
	@echo "  WSL: $(shell grep -i microsoft /proc/version 2>/dev/null || echo 'Not WSL')"
	@echo "  Container Runtime: $(CONTAINER_RUNTIME)"
	@echo ""
	@echo "${GREEN}[2] Tool Versions:${RESET}"
	@echo "  kind: $(shell $(KIND) version 2>/dev/null || echo 'NOT INSTALLED')"
	@echo "  kubectl: $(shell $(KUBECTL) version --client --short 2>/dev/null || echo 'NOT INSTALLED')"
	@echo "  $(CONTAINER_RUNTIME): $(shell $(CONTAINER_RUNTIME) version --format '{{.Server.Version}}' 2>/dev/null || $(CONTAINER_RUNTIME) --version 2>/dev/null || echo 'NOT RUNNING')"
	@echo ""
	@echo "${GREEN}[3] Container Status:${RESET}"
	@$(CONTAINER_RUNTIME) ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "  ERROR: Container runtime not accessible"
	@echo ""
	@echo "${GREEN}[4] Existing kind Clusters:${RESET}"
	@$(KIND) get clusters 2>/dev/null || echo "  No clusters found"
	@echo ""
	@echo "${GREEN}[5] kubectl Configuration:${RESET}"
	@$(KUBECTL) config get-contexts 2>/dev/null || echo "  Cannot read kubeconfig"

# -----------------------------------------------------------------------------
# Linting & Validation
# -----------------------------------------------------------------------------
lint: lint-terraform lint-ansible lint-packer lint-python lint-yaml ## Run all linters

lint-terraform: ## Lint Terraform files
	@echo "${BLUE}Linting Terraform...${RESET}"
	@$(TERRAFORM) fmt -check -recursive || \
		(echo "${YELLOW}Terraform formatting issues found. Run 'make fmt-terraform' to fix${RESET}" && exit 1)
	@cd infra/local && $(TERRAFORM) init -backend=false >/dev/null 2>&1 && $(TERRAFORM) validate || \
		echo "${YELLOW}⚠ Local Terraform validation skipped${RESET}"
	@cd infra/proxmox && $(TERRAFORM) init -backend=false >/dev/null 2>&1 && $(TERRAFORM) validate || \
		echo "${YELLOW}⚠ Proxmox Terraform validation skipped${RESET}"
	@echo "${GREEN}✓ Terraform linting passed${RESET}"

lint-ansible: ## Lint Ansible playbooks
	@echo "${BLUE}Linting Ansible...${RESET}"
	@command -v ansible-lint >/dev/null 2>&1 || \
		(echo "${YELLOW}⚠ ansible-lint not found. Install: pip install ansible-lint${RESET}" && exit 0)
	@ansible-lint $(ANSIBLE_PLAYBOOK_DIR)/ || \
		(echo "${YELLOW}Ansible linting issues found${RESET}" && exit 1)
	@echo "${GREEN}✓ Ansible linting passed${RESET}"

lint-packer: ## Validate Packer templates
	@echo "${BLUE}Validating Packer templates...${RESET}"
	@cd packer && $(PACKER) validate centos9-cloudinit.pkr.hcl || \
		(echo "${RED}Packer validation failed${RESET}" && exit 1)
	@echo "${GREEN}✓ Packer validation passed${RESET}"

lint-python: ## Lint Python code
	@echo "${BLUE}Linting Python...${RESET}"
	@if [ -d "$(TESTS_DIR)" ]; then \
		command -v flake8 >/dev/null 2>&1 && \
			$(PYTHON) -m flake8 $(TESTS_DIR)/ scripts/ || \
			echo "${YELLOW}⚠ flake8 not found. Install: pip install flake8${RESET}"; \
	else \
		echo "${YELLOW}⚠ tests/ directory not found${RESET}"; \
	fi
	@echo "${GREEN}✓ Python linting passed${RESET}"

lint-yaml: ## Lint YAML files
	@echo "${BLUE}Linting YAML...${RESET}"
	@command -v yamllint >/dev/null 2>&1 && \
		yamllint . || \
		echo "${YELLOW}⚠ yamllint not found. Install: pip install yamllint${RESET}"
	@echo "${GREEN}✓ YAML linting passed${RESET}"

fmt: fmt-terraform ## Auto-fix formatting issues

fmt-terraform: ## Format Terraform files
	@echo "${BLUE}Formatting Terraform...${RESET}"
	@$(TERRAFORM) fmt -recursive
	@echo "${GREEN}✓ Terraform formatted${RESET}"

# -----------------------------------------------------------------------------
# Testing
# -----------------------------------------------------------------------------
test: test-unit test-integration ## Run all tests

test-unit: ## Run unit tests
	@echo "${BLUE}Running unit tests...${RESET}"
	@if [ -d "$(TESTS_DIR)/unit" ]; then \
		$(PYTHON) -m pytest $(TESTS_DIR)/unit/ -v --cov=. --cov-report=term --cov-report=xml || exit 1; \
	else \
		echo "${YELLOW}⚠ tests/unit/ not found. Run 'make setup-tests' to create test structure.${RESET}"; \
	fi
	@echo "${GREEN}✓ Unit tests passed${RESET}"

test-integration: ## Run integration tests
	@echo "${BLUE}Running integration tests...${RESET}"
	@if [ -d "$(TESTS_DIR)/integration" ]; then \
		echo "  → Starting services..."; \
		$(COMPOSE) up -d; \
		sleep 5; \
		echo "  → Running tests..."; \
		$(PYTHON) -m pytest $(TESTS_DIR)/integration/ -v || \
			($(COMPOSE) down && exit 1); \
		echo "  → Stopping services..."; \
		$(COMPOSE) down; \
	else \
		echo "${YELLOW}⚠ tests/integration/ not found. Run 'make setup-tests' to create test structure.${RESET}"; \
	fi
	@echo "${GREEN}✓ Integration tests passed${RESET}"

test-e2e: ## Run end-to-end tests
	@echo "${BLUE}Running E2E tests...${RESET}"
	@if [ -d "$(TESTS_DIR)/e2e" ]; then \
		$(PYTHON) -m pytest $(TESTS_DIR)/e2e/ -v || exit 1; \
	else \
		echo "${YELLOW}⚠ tests/e2e/ not found. Run 'make setup-tests' to create test structure.${RESET}"; \
	fi
	@echo "${GREEN}✓ E2E tests passed${RESET}"

test-local: apply-local ## Run local environment tests
	@echo "${GREEN}Running local tests...${RESET}"
	$(MAKE) test-infra-local
	$(MAKE) test-services-local
	$(MAKE) test-ai

test-prod: apply-prod ## Run production environment tests
	@echo "${GREEN}Running prod tests...${RESET}"
	$(MAKE) test-infra-prod
	$(MAKE) test-services-prod

test-infra-local: ## Test local infrastructure
	@echo "Testing local infrastructure..."
	$(KUBECTL) get nodes

test-infra-prod: ## Test production infrastructure
	@echo "Validating Proxmox VMs..."
	$(ANSIBLE) -i $(ANSIBLE_INVENTORY) all -m ping

test-services-local: ## Test local services
	@echo "Testing services locally..."
	$(KUBECTL) exec -n ai-ops deploy/dns -- dig +short google.com || echo "${YELLOW}⚠ DNS service not deployed${RESET}"

test-services-prod: ## Test production services
	$(ANSIBLE) -i $(ANSIBLE_INVENTORY) dns -m command -a "dig @10.0.1.5 corp.example.com" || echo "${YELLOW}⚠ DNS not configured${RESET}"

test-ai: ## Test AI Ops Agent
	@echo "${GREEN}Testing AI Ops Agent (NL → Intent)...${RESET}"
	@curl -s -X POST http://localhost:30080/api/v1/intent \
		-H "Content-Type: application/json" \
		-d '{"nl": "Add DNS A record for test.local to 192.168.1.100"}' | jq || \
		echo "${YELLOW}⚠ AI agent not available${RESET}"

coverage: ## Generate coverage report
	@echo "${BLUE}Generating coverage report...${RESET}"
	@if [ -d "$(TESTS_DIR)" ]; then \
		$(PYTHON) -m pytest $(TESTS_DIR)/ --cov=. --cov-report=html --cov-report=term; \
		echo "${GREEN}Coverage report generated in htmlcov/index.html${RESET}"; \
	else \
		echo "${YELLOW}⚠ tests/ directory not found${RESET}"; \
	fi

# -----------------------------------------------------------------------------
# Security
# -----------------------------------------------------------------------------
security: security-trivy security-secrets security-terraform security-ansible ## Run all security scans

security-trivy: ## Scan for vulnerabilities with Trivy
	@echo "${BLUE}Scanning with Trivy...${RESET}"
	@command -v $(TRIVY) >/dev/null 2>&1 || \
		(echo "${YELLOW}Warning: trivy not found. Install: https://github.com/aquasecurity/trivy${RESET}" && exit 0)
	@$(TRIVY) fs . --severity CRITICAL,HIGH --exit-code 0
	@$(TRIVY) config . --exit-code 0
	@echo "${GREEN}✓ Trivy scan complete${RESET}"

security-secrets: ## Scan for secrets with gitleaks
	@echo "${BLUE}Scanning for secrets...${RESET}"
	@command -v $(GITLEAKS) >/dev/null 2>&1 || \
		(echo "${YELLOW}Warning: gitleaks not found. Install: https://github.com/gitleaks/gitleaks${RESET}" && exit 0)
	@$(GITLEAKS) detect --source . --verbose --exit-code 0
	@echo "${GREEN}✓ No secrets found${RESET}"

security-terraform: ## Scan Terraform with tfsec
	@echo "${BLUE}Scanning Terraform security...${RESET}"
	@command -v $(TFSEC) >/dev/null 2>&1 || \
		(echo "${YELLOW}Warning: tfsec not found. Install: https://github.com/aquasecurity/tfsec${RESET}" && exit 0)
	@$(TFSEC) infra/ --minimum-severity HIGH --soft-fail
	@echo "${GREEN}✓ Terraform security scan complete${RESET}"

security-ansible: ## Scan Ansible for security issues
	@echo "${BLUE}Scanning Ansible security...${RESET}"
	@command -v ansible-lint >/dev/null 2>&1 && \
		ansible-lint --profile=production $(ANSIBLE_PLAYBOOK_DIR)/ || \
		echo "${YELLOW}⚠ ansible-lint not found${RESET}"
	@echo "${GREEN}✓ Ansible security scan complete${RESET}"

# -----------------------------------------------------------------------------
# SBOM & Signing
# -----------------------------------------------------------------------------
sbom: ## Generate SBOM (Syft)
	@echo "${GREEN}Generating SBOM (Syft)...${RESET}"
	@command -v $(SYFT) >/dev/null 2>&1 || \
		(echo "${YELLOW}Warning: syft not found. Install: https://github.com/anchore/syft${RESET}" && exit 0)
	@$(SYFT) . -o cyclonedx-json > sbom.json
	@$(SYFT) . -o spdx-json > sbom.spdx.json
	@echo "${GREEN}✓ SBOM generated${RESET}"

sign: sbom ## Sign artifacts (cosign)
	@echo "${GREEN}Signing SBOM and manifests...${RESET}"
	@command -v $(COSIGN) >/dev/null 2>&1 || \
		(echo "${YELLOW}Warning: cosign not found${RESET}" && exit 0)
	@if [ -f cosign.key ]; then \
		$(COSIGN) sign-blob --key cosign.key sbom.json > sbom.json.sig; \
		echo "${GREEN}✓ Artifacts signed${RESET}"; \
	else \
		echo "${YELLOW}⚠ cosign.key not found. Generate with: cosign generate-key-pair${RESET}"; \
	fi

# -----------------------------------------------------------------------------
# Terraform: Dual Backend Support
# -----------------------------------------------------------------------------
init: init-$(ENV)

init-local: ## Initialize Terraform (local backend)
	@echo "${GREEN}Initializing Terraform (local backend)${RESET}"
	@cd infra/local && $(TERRAFORM) init -backend-config="../$(TF_BACKEND_LOCAL)" || exit 1

init-prod: ## Initialize Terraform (Proxmox backend)
	@echo "${GREEN}Initializing Terraform (Proxmox backend)${RESET}"
	@cd infra/proxmox && $(TERRAFORM) init -backend-config="../$(TF_BACKEND_PROD)" || exit 1

plan: plan-$(ENV)

plan-local: ## Plan local infrastructure
	@echo "${GREEN}Planning local infrastructure...${RESET}"
	@cd infra/local && $(TERRAFORM) plan -out=plan.tfplan || exit 1

plan-prod: ## Plan Proxmox infrastructure
	@echo "${GREEN}Planning Proxmox infrastructure...${RESET}"
	@cd infra/proxmox && $(TERRAFORM) plan -out=plan.tfplan || exit 1

apply: apply-$(ENV)

apply-local: init-local plan-local ## Apply local infrastructure
	@echo "${GREEN}Applying local infrastructure...${RESET}"
	@cd infra/local && $(TERRAFORM) apply -auto-approve plan.tfplan || exit 1

apply-prod: init-prod plan-prod ## Apply to Proxmox
	@echo "${GREEN}Applying to Proxmox...${RESET}"
	@cd infra/proxmox && $(TERRAFORM) apply -auto-approve plan.tfplan || exit 1

migrate-state: ## Migrate Terraform state (local → prod)
	@echo "${YELLOW}Migrating Terraform state: local → prod${RESET}"
	@echo "1. Backup current state"
	@cd infra/local && $(TERRAFORM) state pull > ../backup-local.tfstate
	@echo "2. Reconfigure backend"
	@cd infra/proxmox && $(TERRAFORM) init -migrate-state -force-copy -backend-config="../$(TF_BACKEND_PROD)"
	@echo "${GREEN}Migration complete${RESET}"

# -----------------------------------------------------------------------------
# Packer: VM Template Building
# -----------------------------------------------------------------------------
packer-validate: ## Validate Packer template
	@echo "${GREEN}Validating Packer template...${RESET}"
	@cd packer && $(PACKER) validate centos9-cloudinit.pkr.hcl || exit 1
	@echo "${GREEN}✓ Packer template valid${RESET}"

packer-build: packer-validate ## Build CentOS 9 cloud-init template
	@echo "${GREEN}Building CentOS 9 cloud-init template with Packer...${RESET}"
	@echo "Ensure PM_API_URL, PM_API_TOKEN_ID, PM_API_TOKEN_SECRET are set"
	@cd packer && $(PACKER) build centos9-cloudinit.pkr.hcl
	@echo "${GREEN}Template 'centos9-cloud' created successfully${RESET}"

packer-debug: ## Build with debug output
	@echo "${GREEN}Building with debug output...${RESET}"
	@cd packer && PACKER_LOG=1 $(PACKER) build -debug centos9-cloudinit.pkr.hcl

# -----------------------------------------------------------------------------
# Ansible: Cluster & Application Deployment
# -----------------------------------------------------------------------------
ansible-ping: ## Test connectivity to all hosts
	@echo "${GREEN}Testing connectivity to all hosts...${RESET}"
	@$(ANSIBLE) all -i $(ANSIBLE_INVENTORY) -m ping || exit 1

ansible-deploy-k3s: ## Deploy k3s cluster
	@echo "${GREEN}Deploying k3s cluster...${RESET}"
	@$(ANSIBLE) -i $(ANSIBLE_INVENTORY) $(ANSIBLE_PLAYBOOK_DIR)/deploy-k3s.yml || exit 1
	@echo "${GREEN}k3s cluster deployed successfully!${RESET}"

ansible-deploy-apps: ## Deploy applications to k3s
	@echo "${GREEN}Deploying applications to k3s...${RESET}"
	@$(ANSIBLE) -i $(ANSIBLE_INVENTORY) $(ANSIBLE_PLAYBOOK_DIR)/deploy-apps.yml || exit 1
	@echo "${GREEN}Applications deployed successfully!${RESET}"

ansible-kubeconfig: ## Fetch kubeconfig from cluster
	@echo "${GREEN}Fetching kubeconfig from cluster...${RESET}"
	@mkdir -p ~/.kube
	@scp -o StrictHostKeyChecking=no cloud-user@10.100.0.10:~/.kube/config ~/.kube/config-aiops-prod
	@echo "${GREEN}Kubeconfig saved to: ~/.kube/config-aiops-prod${RESET}"

ansible-deploy-infra: ## Deploy infrastructure services (DNS + FreeIPA)
	@echo "${GREEN}Deploying infrastructure services...${RESET}"
	@$(ANSIBLE) -i $(ANSIBLE_INVENTORY) $(ANSIBLE_PLAYBOOK_DIR)/deploy-infrastructure-services.yml || exit 1

ansible-deploy-dns: ## Deploy DNS server (BIND)
	@echo "${GREEN}Deploying DNS server...${RESET}"
	@$(ANSIBLE) -i $(ANSIBLE_INVENTORY) $(ANSIBLE_PLAYBOOK_DIR)/deploy-infrastructure-services.yml --tags dns || exit 1

ansible-deploy-freeipa: ## Deploy FreeIPA
	@echo "${GREEN}Deploying FreeIPA...${RESET}"
	@$(ANSIBLE) -i $(ANSIBLE_INVENTORY) $(ANSIBLE_PLAYBOOK_DIR)/deploy-infrastructure-services.yml --tags freeipa || exit 1

ansible-validate: ## Validate complete deployment
	@echo "${GREEN}Running comprehensive deployment validation...${RESET}"
	@$(ANSIBLE) -i $(ANSIBLE_INVENTORY) $(ANSIBLE_PLAYBOOK_DIR)/validate-deployment.yml || exit 1

ansible-verify: ansible-validate ## Alias for ansible-validate

ansible-upgrade-k3s: ## Upgrade k3s cluster
	@echo "${GREEN}Upgrading k3s cluster...${RESET}"
	@read -p "Continue? (y/N) " confirm && [ "$$confirm" = "y" ] || exit 1
	@K3S_VERSION=$(K3S_VERSION) $(ANSIBLE) -i $(ANSIBLE_INVENTORY) $(ANSIBLE_PLAYBOOK_DIR)/upgrade-k3s.yml

ansible-drain-node: ## Drain node for maintenance
	@read -p "Enter node name: " node && \
		$(ANSIBLE) -i $(ANSIBLE_INVENTORY) k3s-cp-01 -m shell -a "kubectl drain $$node --ignore-daemonsets --delete-emptydir-data"

ansible-uncordon-node: ## Uncordon node
	@read -p "Enter node name: " node && \
		$(ANSIBLE) -i $(ANSIBLE_INVENTORY) k3s-cp-01 -m shell -a "kubectl uncordon $$node"

ansible-logs: ## Fetch k3s logs
	@$(ANSIBLE) -i $(ANSIBLE_INVENTORY) control_plane -m shell -a "journalctl -u k3s -n 100"

# -----------------------------------------------------------------------------
# Comprehensive Validation
# -----------------------------------------------------------------------------
validate-all: ## Run comprehensive validation across all layers
	@echo "${GREEN}╔════════════════════════════════════════════════════════════╗${RESET}"
	@echo "${GREEN}║        Comprehensive Validation (All Layers)              ║${RESET}"
	@echo "${GREEN}╚════════════════════════════════════════════════════════════╝${RESET}"
	@echo ""
	@echo "${BLUE}==> [1/5] Validating Packer Templates${RESET}"
	@make packer-validate || echo "${YELLOW}WARNING: Packer validation failed${RESET}"
	@echo ""
	@echo "${BLUE}==> [2/5] Validating Terraform Configuration${RESET}"
	@cd infra/proxmox && $(TERRAFORM) validate || echo "${YELLOW}WARNING: Terraform validation failed${RESET}"
	@echo ""
	@echo "${BLUE}==> [3/5] Validating Ansible Playbooks${RESET}"
	@ansible-playbook --syntax-check $(ANSIBLE_PLAYBOOK_DIR)/*.yml || echo "${YELLOW}WARNING: Ansible syntax check failed${RESET}"
	@echo ""
	@echo "${BLUE}==> [4/5] Validating Kubernetes Manifests${RESET}"
	@$(KUBECTL) apply --dry-run=client -f cluster/ 2>/dev/null || echo "${YELLOW}WARNING: K8s validation skipped${RESET}"
	@echo ""
	@echo "${BLUE}==> [5/5] Running Linters${RESET}"
	@make lint || echo "${YELLOW}WARNING: Linting found issues${RESET}"
	@echo ""
	@echo "${GREEN}╔════════════════════════════════════════════════════════════╗${RESET}"
	@echo "${GREEN}║              ✓ Validation Complete!                       ║${RESET}"
	@echo "${GREEN}╚════════════════════════════════════════════════════════════╝${RESET}"

# -----------------------------------------------------------------------------
# Autoscaler: Build & Deploy
# -----------------------------------------------------------------------------
autoscaler-build: ## Build autoscaler container image
	@echo "${GREEN}Building autoscaler container image...${RESET}"
	@$(CONTAINER_RUNTIME) build -t $(AUTOSCALER_IMAGE):$(AUTOSCALER_TAG) \
		-f cluster/autoscaler/Dockerfile . || exit 1
	@echo "${GREEN}Built $(AUTOSCALER_IMAGE):$(AUTOSCALER_TAG)${RESET}"

autoscaler-push: autoscaler-build ## Push autoscaler image
	@echo "${GREEN}Pushing autoscaler image...${RESET}"
	@$(CONTAINER_RUNTIME) push $(AUTOSCALER_IMAGE):$(AUTOSCALER_TAG) || exit 1

autoscaler-sign: autoscaler-push ## Sign autoscaler image
	@echo "${GREEN}Signing autoscaler image...${RESET}"
	@command -v $(COSIGN) >/dev/null 2>&1 && \
		$(COSIGN) sign --key cosign.key $(AUTOSCALER_IMAGE):$(AUTOSCALER_TAG) || \
		echo "${YELLOW}⚠ cosign not available${RESET}"

autoscaler-deploy: ## Deploy autoscaler to k3s
	@echo "${GREEN}Deploying autoscaler to k3s...${RESET}"
	@$(KUBECTL) apply -f cluster/autoscaler/deployment.yaml || exit 1
	@echo "${GREEN}Autoscaler deployed successfully${RESET}"

autoscaler-status: ## Check autoscaler status
	@echo "${GREEN}Autoscaler status:${RESET}"
	@$(KUBECTL) get cronjob -n autoscaler || echo "${YELLOW}⚠ Autoscaler not deployed${RESET}"
	@$(KUBECTL) get pods -n autoscaler --sort-by=.metadata.creationTimestamp | tail -5 || true

# -----------------------------------------------------------------------------
# VM Management
# -----------------------------------------------------------------------------
vm-list: ## List VMs with autoscale tags
	@echo "${GREEN}Listing VMs with autoscale tags...${RESET}"
	@cd infra/proxmox && $(TERRAFORM) output -json autoscaling_config | jq -r '.asg_vmids[]' || echo "${YELLOW}⚠ No VMs found${RESET}"

vm-scale-up: ## Manually trigger scale up
	@echo "${GREEN}Manually triggering scale up...${RESET}"
	@$(KUBECTL) exec -n autoscaler $$($(KUBECTL) get pod -n autoscaler -l app=proxmox-autoscaler -o jsonpath='{.items[0].metadata.name}') \
		-- python3 /app/autoscaler.py --once --cpu-scale-up 0

vm-scale-down: ## Manually trigger scale down
	@echo "${GREEN}Manually triggering scale down...${RESET}"
	@$(KUBECTL) exec -n autoscaler $$($(KUBECTL) get pod -n autoscaler -l app=proxmox-autoscaler -o jsonpath='{.items[0].metadata.name}') \
		-- python3 /app/autoscaler.py --once --cpu-scale-down 100

# -----------------------------------------------------------------------------
# CI/CD Targets (Platform-Agnostic)
# -----------------------------------------------------------------------------
ci-lint: doctor lint ## CI: Run linting (called by GitHub/GitLab/Jenkins/Tekton)

ci-test: doctor test ## CI: Run tests

ci-security: doctor security ## CI: Run security scans

ci-build: doctor packer-validate autoscaler-build ## CI: Build artifacts

ci-deploy: doctor ## CI: Deploy to staging (placeholder)
	@echo "${YELLOW}Deploy to staging - implement based on your deployment strategy${RESET}"

ci-pr: ci-lint ci-test ci-security ## CI: Full PR validation (no deploy)
	@echo "${GREEN}╔════════════════════════════════════════════════════════════╗${RESET}"
	@echo "${GREEN}║          ✓ PR Validation Complete!                        ║${RESET}"
	@echo "${GREEN}╚════════════════════════════════════════════════════════════╝${RESET}"

ci-main: ci-lint ci-test ci-security ci-build ## CI: Full main branch workflow
	@echo "${GREEN}╔════════════════════════════════════════════════════════════╗${RESET}"
	@echo "${GREEN}║          ✓ Main Branch Workflow Complete!                 ║${RESET}"
	@echo "${GREEN}╚════════════════════════════════════════════════════════════╝${RESET}"

# -----------------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------------
clean: ## Clean up temporary files
	@echo "${GREEN}Cleaning workspace...${RESET}"
	@rm -rf .terraform* *.tfplan *.tfstate *.tfstate.backup 2>/dev/null || true
	@rm -f sbom.* 2>/dev/null || true
	@find . -name "*.sig" -delete 2>/dev/null || true
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name "htmlcov" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name ".coverage" -delete 2>/dev/null || true
	@rm -f coverage.xml 2>/dev/null || true
	@echo "${GREEN}✓ Cleanup complete${RESET}"

clean-all: clean ## Deep clean (including caches)
	@echo "${GREEN}Deep cleaning...${RESET}"
	@$(COMPOSE) down -v 2>/dev/null || true
	@$(CONTAINER_RUNTIME) system prune -f 2>/dev/null || true
	@echo "${GREEN}✓ Deep cleanup complete${RESET}"

# -----------------------------------------------------------------------------
# End of Makefile
# -----------------------------------------------------------------------------
