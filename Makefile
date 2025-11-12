# =============================================================================
# AIOps Substrate – Makefile
# Supports: Local (Docker Desktop + WSL2 + k3s) → Production (Proxmox + k3s)
# Author: Infrastructure Architect & AI Ops Strategist
# Version: 2.0
# =============================================================================

.PHONY: all help \
        dev-up dev-down dev-logs \
        kind-up kind-down kind-export \
        init init-local init-prod \
        plan plan-local plan-prod \
        apply apply-local apply-prod \
        test test-local test-prod test-ai \
        lint format validate \
        sbom sign \
        vault-up vault-down \
        ollama-pull \
        migrate-state \
        clean

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# Environment switch
ENV ?= local
TF_BACKEND_LOCAL := infra/local/backend.hcl
TF_BACKEND_PROD  := infra/proxmox/backend.hcl

# Tools
TERRAFORM := terraform
ANSIBLE   := ansible-playbook
KUBECTL   := kubectl
KIND      := kind
DOCKER    := docker
COMPOSE   := docker-compose -f bootstrap/docker-compose.yml
VAULT     := vault
OLLAMA    := ollama
SYFT      := syft
COSIGN    := cosign

# Colors
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
RESET  := $(shell tput -Txterm sgr0)

# -----------------------------------------------------------------------------
# Default target
# -----------------------------------------------------------------------------
all: help

# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------
help:
	@echo ""
	@echo "${YELLOW}AIOps Substrate – Makefile${RESET}"
	@echo "Usage: make <target> [ENV=local|prod]"
	@echo ""
	@echo "${GREEN}Local Dev (Docker Desktop + WSL2):${RESET}"
	@echo "  dev-up           Start full local stack (Vault, Ollama, MinIO, k3s)"
	@echo "  dev-down         Stop and clean local stack"
	@echo "  kind-up          Create kind cluster (aiops-dev)"
	@echo "  kind-down        Delete kind cluster"
	@echo "  apply-local      Apply Terraform (local kind)"
	@echo "  test-ai          Test AI agent with NL request"
	@echo ""
	@echo "${GREEN}Production (Proxmox):${RESET}"
	@echo "  init-prod        Initialize Terraform with Proxmox backend"
	@echo "  apply-prod       Apply Terraform to Proxmox"
	@echo "  migrate-state    Migrate state from local → prod"
	@echo ""
	@echo "${GREEN}Shared:${RESET}"
	@echo "  lint             Run all linters"
	@echo "  sbom             Generate SBOM (Syft)"
	@echo "  sign             Sign artifacts (cosign)"
	@echo "  clean            Remove .terraform, plans, logs"
	@echo ""

# -----------------------------------------------------------------------------
# Local Stack: Docker Compose + kind
# -----------------------------------------------------------------------------
dev-up: vault-up ollama-pull
	@echo "${GREEN}Starting local dev stack...${RESET}"
	$(COMPOSE) up -d
	@echo "Waiting for Vault..."
	@sleep 5
	$(VAULT) login root || true
	@echo "Local stack ready: http://localhost:8200 (token: root)"

dev-down:
	@echo "${GREEN}Stopping local dev stack...${RESET}"
	$(COMPOSE) down -v
	$(MAKE) kind-down

dev-logs:
	$(COMPOSE) logs -f

vault-up:
	@echo "${GREEN}Starting Vault (dev mode)...${RESET}"
	$(COMPOSE) up -d vault

vault-down:
	$(COMPOSE) rm -fsv vault

ollama-pull:
	@echo "${GREEN}Pulling Llama3.1 for AI agent...${RESET}"
	$(OLLAMA) pull llama3.1:8b

# -----------------------------------------------------------------------------
# Kubernetes: kind (local)
# -----------------------------------------------------------------------------
kind-up:
	@echo "${GREEN}Creating kind cluster: aiops-dev${RESET}"
	$(KIND) create cluster --name aiops-dev --config bootstrap/kind-cluster.yaml --wait 2m
	$(KUBECTL) cluster-info
	@echo "Kubeconfig exported to ~/.kube/config"

kind-down:
	@echo "${GREEN}Deleting kind cluster...${RESET}"
	$(KIND) delete cluster --name aiops-dev || true

kind-export:
	$(KIND) export kubeconfig --name aiops-dev

# -----------------------------------------------------------------------------
# Terraform: Dual Backend Support
# -----------------------------------------------------------------------------
init: init-$(ENV)

init-local:
	@echo "${GREEN}Initializing Terraform (local backend)${RESET}"
	cd infra/local && $(TERRAFORM) init -backend-config="../$(TF_BACKEND_LOCAL)"

init-prod:
	@echo "${GREEN}Initializing Terraform (Proxmox backend)${RESET}"
	cd infra/proxmox && $(TERRAFORM) init -backend-config="../$(TF_BACKEND_PROD)"

plan: plan-$(ENV)

plan-local:
	@echo "${GREEN}Planning local infrastructure...${RESET}"
	cd infra/local && $(TERRAFORM) plan -out=plan.tfplan

plan-prod:
	@echo "${GREEN}Planning Proxmox infrastructure...${RESET}"
	cd infra/proxmox && $(TERRAFORM) plan -out=plan.tfplan

apply: apply-$(ENV)

apply-local: init-local plan-local
	@echo "${GREEN}Applying local infrastructure...${RESET}"
	cd infra/local && $(TERRAFORM) apply -auto-approve plan.tfplan

apply-prod: init-prod plan-prod
	@echo "${GREEN}Applying to Proxmox...${RESET}"
	cd infra/proxmox && $(TERRAFORM) apply -auto-approve plan.tfplan

migrate-state:
	@echo "${YELLOW}Migrating Terraform state: local → prod${RESET}"
	@echo "1. Backup current state"
	cd infra/local && $(TERRAFORM) state pull > ../backup-local.tfstate
	@echo "2. Reconfigure backend"
	cd infra/proxmox && $(TERRAFORM) init -migrate-state -force-copy -backend-config="../$(TF_BACKEND_PROD)"
	@echo "Migration complete. Verify with 'terraform state list'"

# -----------------------------------------------------------------------------
# GitHub Actions Self-Hosted Runner
# -----------------------------------------------------------------------------
.PHONY: runner-up runner-down runner-token

cert-manager-up:
	@echo "${GREEN}Installing cert-manager...${RESET}"
	kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
	@echo "Waiting for cert-manager..."
	kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=120s || true


runner-token:
	@echo "${GREEN}Get GitHub PAT from: https://github.com/settings/tokens${RESET}"
	@echo "Required scopes: repo, workflow, admin:org"
	@read -p "Enter GitHub PAT: " token && \
		kubectl create namespace github-runner || true && \
		kubectl create secret generic github-token \
			--namespace=github-runner \
			--from-literal=token=$$token \
			--dry-run=client -o yaml | kubectl apply -f -

runner-up: cert-manager-up runner-token
	@echo "${GREEN}Installing Actions Runner Controller...${RESET}"
	helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller || true
	helm repo update
	helm install arc \
		--namespace github-runner --create-namespace \
		actions-runner-controller/actions-runner-controller \
		--set authSecret.github_token=$$(kubectl get secret github-token -n github-runner -o jsonpath='{.data.token}' | base64 -d)
	@echo "Deploying runner for your repo..."
	kubectl apply -f infra/github-runner/runner.yaml

runner-down:
	@echo "${GREEN}Removing GitHub Actions runners...${RESET}"
	helm uninstall arc -n github-runner || true
	kubectl delete namespace github-runner || true

# -----------------------------------------------------------------------------
# Testing
# -----------------------------------------------------------------------------
test: test-$(ENV)

test-local: apply-local
	@echo "${GREEN}Running local tests...${RESET}"
	$(MAKE) test-infra-local
	$(MAKE) test-services-local
	$(MAKE) test-ai

test-prod: apply-prod
	@echo "${GREEN}Running prod tests...${RESET}"
	$(MAKE) test-infra-prod
	$(MAKE) test-services-prod
	$(MAKE) test-ai-prod

test-infra-local:
	@echo "Pinging control plane..."
	$(KUBECTL) get nodes

test-infra-prod:
	@echo "Validating Proxmox VMs..."
	# Assumes SSH access via ansible
	$(ANSIBLE) -i inventory/proxmox.yml all -m ping

test-services-local:
	@echo "Testing DNS, Samba, IPA locally..."
	$(KUBECTL) exec -n ai-ops deploy/dns -- dig +short google.com

test-services-prod:
	$(ANSIBLE) -i inventory/proxmox.yml dns -m command -a "dig @10.0.1.5 corp.example.com"

test-ai:
	@echo "${GREEN}Testing AI Ops Agent (NL → Intent)...${RESET}"
	curl -s -X POST http://localhost:30080/api/v1/intent \
	  -H "Content-Type: application/json" \
	  -d '{"nl": "Add DNS A record for test.local to 192.168.1.100"}' | jq

test-ai-prod:
	@echo "${GREEN}Testing AI agent in prod...${RESET}"
	curl -sk -X POST https://ai-ops.corp.example.com/api/v1/intent \
	  -H "Authorization: Bearer $(VAULT_TOKEN)" \
	  -d '{"nl": "Add DNS A record for prod.local to 10.0.10.100"}'

# -----------------------------------------------------------------------------
# Linting & Validation
# -----------------------------------------------------------------------------
lint:
	@echo "${GREEN}Linting Terraform, Ansible, YAML...${RESET}"
	$(TERRAFORM) fmt -check -recursive
	ansible-lint services/
	yamllint .
	tflint infra/
	pre-commit run --all-files

format:
	$(TERRAFORM) fmt -recursive
	black .
	isort .

validate:
	$(TERRAFORM) validate
	ansible-playbook --syntax-check services/dns.yml
	ansible-playbook --syntax-check services/samba.yml
	ansible-playbook --syntax-check services/pki.yml

# -----------------------------------------------------------------------------
# Security & Compliance
# -----------------------------------------------------------------------------
sbom:
	@echo "${GREEN}Generating SBOM (Syft)...${RESET}"
	$(SYFT) . -o cyclonedx-json > sbom.json
	$(SYFT) . -o spdx-json > sbom.spdx.json

sign: sbom
	@echo "${GREEN}Signing SBOM and manifests...${RESET}"
	$(COSIGN) sign-blob --key cosign.key sbom.json > sbom.json.sig
	$(COSIGN) sign-blob --key cosign.key cluster/k3s/apps/ai-ops-agent/deployment.yaml > deployment.yaml.sig

# -----------------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------------
clean:
	@echo "${GREEN}Cleaning workspace...${RESET}"
	rm -rf .terraform* *.tfplan *.tfstate *.tfstate.backup
	rm -f sbom.*
	find . -name "*.sig" -delete
	$(MAKE) dev-down

# -----------------------------------------------------------------------------
# End of Makefile
# -----------------------------------------------------------------------------
