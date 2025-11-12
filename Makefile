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
        tf-fmt tf-validate tf-destroy tf-practice \
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
	@echo "${GREEN}Day 3: Terraform Practice:${RESET}"
	@echo "  tf-fmt           Format Terraform code"
	@echo "  tf-validate      Validate Terraform configuration"
	@echo "  tf-destroy       Destroy local infrastructure"
	@echo "  tf-practice      Practice Terraform workflow (target: <2min)"
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

# Day 3 targets
tf-fmt:
	@echo "${GREEN}Formatting Terraform code...${RESET}"
	cd infra/local && $(TERRAFORM) fmt
	cd infra/modules && $(TERRAFORM) fmt -recursive

tf-validate: init-local
	@echo "${GREEN}Validating Terraform configuration...${RESET}"
	cd infra/local && $(TERRAFORM) validate

tf-destroy:
	@echo "${YELLOW}Destroying local infrastructure...${RESET}"
	cd infra/local && $(TERRAFORM) destroy -auto-approve
	$(MAKE) kind-down

tf-practice:
	@echo "${GREEN}Day 3: Terraform Muscle Memory Practice${RESET}"
	@echo "This will run: init → plan → apply → destroy"
	@echo "Target: Complete in <2 minutes"
	@echo ""
	@echo "Starting practice run..."
	@start=$$(date +%s); \
	$(MAKE) init-local && \
	$(MAKE) plan-local && \
	cd infra/local && $(TERRAFORM) apply -auto-approve plan.tfplan && \
	sleep 5 && \
	$(TERRAFORM) destroy -auto-approve && \
	end=$$(date +%s); \
	elapsed=$$((end - start)); \
	echo ""; \
	echo "${GREEN}Practice run completed in $$elapsed seconds${RESET}"; \
	if [ $$elapsed -lt 120 ]; then \
		echo "${GREEN}✅ SUCCESS! Under 2 minutes - muscle memory achieved!${RESET}"; \
	else \
		echo "${YELLOW}⏱️  Not quite there yet. Target: <120s, Actual: $${elapsed}s${RESET}"; \
	fi

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
# Reusable Secret Validation Functions
# -----------------------------------------------------------------------------
# Usage: $(call wait-for-secret,secret-name,namespace,timeout-seconds)
define wait-for-secret
	@echo "Waiting for secret $(1) in namespace $(2)..."
	@for i in $$(seq 1 $(3)); do \
		if kubectl get secret $(1) -n $(2) >/dev/null 2>&1; then \
			echo "✓ Secret $(1) exists"; \
			exit 0; \
		fi; \
		echo "Waiting for secret $(1) ($$i/$(3))..."; \
		sleep 1; \
	done; \
	echo "❌ Secret $(1) not found after $(3) seconds"; \
	exit 1
endef

# Usage: $(call validate-secret-key,secret-name,namespace,key-name)
define validate-secret-key
	@echo "Validating secret $(1) has key $(3)..."
	@if ! kubectl get secret $(1) -n $(2) -o jsonpath='{.data.$(3)}' | grep -q .; then \
		echo "❌ Secret $(1) missing key $(3)"; \
		exit 1; \
	fi
	@echo "✓ Secret $(1) has key $(3)"
endef

# -----------------------------------------------------------------------------
# cert-manager Installation with Full Validation
# -----------------------------------------------------------------------------
.PHONY: cert-manager-up cert-manager-down cert-validate

cert-manager-up:
	@echo "${GREEN}Installing cert-manager...${RESET}"
	kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
	@echo "Waiting for cert-manager CRDs to be established..."
	kubectl wait --for condition=established --timeout=120s \
		crd/certificates.cert-manager.io \
		crd/issuers.cert-manager.io \
		crd/clusterissuers.cert-manager.io
	@echo "Waiting for cert-manager pods to be ready..."
	kubectl wait --namespace cert-manager \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/instance=cert-manager \
		--timeout=120s
	@echo "Waiting for webhook to be ready..."
	kubectl wait --namespace cert-manager \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/name=webhook \
		--timeout=120s
	@echo "Verifying webhook registration..."
	@for i in 1 2 3 4 5; do \
		if kubectl get validatingwebhookconfigurations.admissionregistration.k8s.io cert-manager-webhook >/dev/null 2>&1; then \
			echo "✓ Webhook registered and operational"; \
			break; \
		fi; \
		echo "Waiting for webhook registration ($$i/5)..."; \
		sleep 5; \
	done
	@echo "${GREEN}✓ cert-manager fully operational${RESET}"

cert-manager-down:
	@echo "${YELLOW}Removing cert-manager...${RESET}"
	kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml || true

cert-validate:
	@echo "${GREEN}Validating Certificates and Secrets...${RESET}"
	@CERTS=$$(kubectl get certificates -n github-runner -o name 2>/dev/null | wc -l); \
	if [ $$CERTS -eq 0 ]; then \
		echo "No certificates found (OK if runner not deployed yet)"; \
		exit 0; \
	fi; \
	for cert in $$(kubectl get certificates -n github-runner -o name); do \
		echo "Checking $$cert..."; \
		SECRET_NAME=$$(kubectl get $$cert -n github-runner -o jsonpath='{.spec.secretName}' 2>/dev/null); \
		if [ -z "$$SECRET_NAME" ]; then \
			echo "  ⚠️  Certificate has no secretName"; \
			continue; \
		fi; \
		echo "  Waiting for Certificate ready condition..."; \
		if ! kubectl wait --for=condition=ready $$cert -n github-runner --timeout=60s 2>/dev/null; then \
			echo "  ❌ Certificate not ready after 60s"; \
			exit 1; \
		fi; \
		echo "  Checking Secret $$SECRET_NAME exists..."; \
		if ! kubectl get secret $$SECRET_NAME -n github-runner >/dev/null 2>&1; then \
			echo "  ❌ Secret $$SECRET_NAME not found"; \
			exit 1; \
		fi; \
		echo "  Validating tls.crt is non-empty..."; \
		TLS_CRT=$$(kubectl get secret $$SECRET_NAME -n github-runner -o jsonpath='{.data.tls\.crt}' 2>/dev/null); \
		if [ -z "$$TLS_CRT" ]; then \
			echo "  ❌ tls.crt is empty - triggering re-issuance"; \
			kubectl delete secret $$SECRET_NAME -n github-runner 2>/dev/null || true; \
			kubectl annotate $$cert -n github-runner cert-manager.io/issue-temporary-certificate- --overwrite; \
			sleep 15; \
			if ! kubectl wait --for=condition=ready $$cert -n github-runner --timeout=90s; then \
				echo "  ❌ Re-issuance failed"; \
				exit 1; \
			fi; \
			TLS_CRT=$$(kubectl get secret $$SECRET_NAME -n github-runner -o jsonpath='{.data.tls\.crt}'); \
		fi; \
		echo "  Verifying valid X.509 certificate..."; \
		if ! echo "$$TLS_CRT" | base64 -d | openssl x509 -noout -text >/dev/null 2>&1; then \
			echo "  ❌ Invalid X.509 certificate"; \
			exit 1; \
		fi; \
		echo "  ✓ Certificate validated"; \
	done
	@echo "${GREEN}✓ All certificates validated${RESET}"

# -----------------------------------------------------------------------------
# GitHub Actions Runner with Proper Sequencing
# -----------------------------------------------------------------------------
.PHONY: runner-token runner-up runner-down runner-status

runner-token:
	@echo "${GREEN}Creating GitHub token secret...${RESET}"
	@if kubectl get secret github-token -n github-runner >/dev/null 2>&1; then \
		echo "Token secret already exists"; \
	else \
		echo "Enter your GitHub Personal Access Token (scopes: repo, workflow, admin:org):"; \
		read -s TOKEN; \
		kubectl create namespace github-runner 2>/dev/null || true; \
		kubectl create secret generic github-token \
			--namespace=github-runner \
			--from-literal=token=$$TOKEN; \
		echo "✓ Token secret created"; \
	fi

runner-up: cert-manager-up runner-token
	@echo "${GREEN}Installing Actions Runner Controller...${RESET}"
	@echo "Adding Helm repository..."
	helm repo add actions-runner-controller \
		https://actions-runner-controller.github.io/actions-runner-controller 2>/dev/null || true
	helm repo update
	@echo "Installing ARC chart (this may take 2-3 minutes)..."
	helm install arc \
		--namespace github-runner \
		--create-namespace \
		--timeout 10m \
		--wait \
		--wait-for-jobs \
		actions-runner-controller/actions-runner-controller \
		--set authSecret.github_token=$$(kubectl get secret github-token -n github-runner -o jsonpath='{.data.token}' | base64 -d)
	$(call wait-for-secret,controller-manager,github-runner,60)
	@echo "Verifying ARC controller is ready..."
	kubectl wait --namespace github-runner \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/name=actions-runner-controller \
		--timeout=120s
	@echo "Waiting for webhook service endpoints..."
	@for i in 1 2 3 4 5 6 7 8 9 10; do \
		ENDPOINTS=$$(kubectl get endpoints -n github-runner arc-actions-runner-controller-webhook -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null); \
		if [ -n "$$ENDPOINTS" ]; then \
			echo "✓ Webhook endpoints ready: $$ENDPOINTS"; \
			break; \
		fi; \
		echo "Waiting for webhook endpoints ($$i/10)..."; \
		sleep 10; \
	done
	@echo "Validating certificates..."
	$(MAKE) cert-validate
	@echo "Deploying runner manifest..."
	kubectl apply -f infra/github-runner/runner.yaml
	@echo "${GREEN}✓ Runner deployment complete${RESET}"
	@echo ""
	@echo "Check runner status:"
	@echo "  kubectl get runners -n github-runner"
	@echo "  kubectl get pods -n github-runner"

runner-down:
	@echo "${YELLOW}Removing GitHub Actions runners...${RESET}"
	kubectl delete -f infra/github-runner/runner.yaml 2>/dev/null || true
	helm uninstall arc -n github-runner 2>/dev/null || true
	kubectl delete namespace github-runner 2>/dev/null || true
	@echo "✓ Runner removed"

runner-status:
	@echo "=== GitHub Runner Status ==="
	@echo ""
	@echo "Runners:"
	@kubectl get runners -n github-runner 2>/dev/null || echo "  No runners found"
	@echo ""
	@echo "Pods:"
	@kubectl get pods -n github-runner 2>/dev/null || echo "  No pods found"
	@echo ""
	@echo "Certificates:"
	@kubectl get certificates -n github-runner 2>/dev/null || echo "  No certificates found"

# -----------------------------------------------------------------------------
# End of Makefile
# -----------------------------------------------------------------------------
