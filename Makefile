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
        packer-build packer-validate \
        ansible-ping ansible-deploy-k3s ansible-deploy-apps ansible-kubeconfig \
        autoscaler-build autoscaler-deploy autoscaler-status \
        template-clone vm-create vm-list \
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
	@echo "${GREEN}Image Building:${RESET}"
	@echo "  packer-validate  Validate Packer template"
	@echo "  packer-build     Build CentOS 9 cloud-init template"
	@echo "  autoscaler-build Build and push autoscaler container"
	@echo ""
	@echo "${GREEN}Ansible Deployment:${RESET}"
	@echo "  ansible-ping         Test connectivity to all hosts"
	@echo "  ansible-deploy-k3s   Deploy k3s cluster (HA control plane + workers)"
	@echo "  ansible-deploy-apps  Deploy applications to k3s"
	@echo "  ansible-kubeconfig   Fetch kubeconfig from cluster"
	@echo ""
	@echo "${GREEN}Autoscaling:${RESET}"
	@echo "  autoscaler-deploy Deploy autoscaler to k3s"
	@echo "  autoscaler-status Check autoscaler status"
	@echo "  vm-list          List all VMs with autoscale tags"
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
# Packer: VM Template Building
# -----------------------------------------------------------------------------
PACKER := packer
PACKER_TEMPLATE := packer/centos9-cloudinit.pkr.hcl

packer-validate:
	@echo "${GREEN}Validating Packer template...${RESET}"
	cd packer && $(PACKER) validate centos9-cloudinit.pkr.hcl

packer-build: packer-validate
	@echo "${GREEN}Building CentOS 9 cloud-init template with Packer...${RESET}"
	@echo "This will create a VM template on Proxmox node"
	@echo "Ensure PM_API_URL, PM_API_TOKEN_ID, PM_API_TOKEN_SECRET are set"
	cd packer && $(PACKER) build centos9-cloudinit.pkr.hcl
	@echo "${GREEN}Template 'centos9-cloud' created successfully${RESET}"

packer-debug:
	@echo "${GREEN}Building with debug output...${RESET}"
	cd packer && PACKER_LOG=1 $(PACKER) build -debug centos9-cloudinit.pkr.hcl

# -----------------------------------------------------------------------------
# Ansible: Cluster & Application Deployment
# -----------------------------------------------------------------------------
ANSIBLE_INVENTORY := inventory/proxmox.yml
ANSIBLE_PLAYBOOK_DIR := ansible

ansible-ping:
	@echo "${GREEN}Testing connectivity to all hosts...${RESET}"
	$(ANSIBLE) all -i $(ANSIBLE_INVENTORY) -m ping

ansible-preflight:
	@echo "${GREEN}Running pre-flight checks...${RESET}"
	$(ANSIBLE) -i $(ANSIBLE_INVENTORY) $(ANSIBLE_PLAYBOOK_DIR)/deploy-k3s.yml --tags preflight

ansible-deploy-lb:
	@echo "${GREEN}Deploying HAProxy load balancers...${RESET}"
	$(ANSIBLE) -i $(ANSIBLE_INVENTORY) $(ANSIBLE_PLAYBOOK_DIR)/deploy-k3s.yml --tags loadbalancer

ansible-deploy-k3s: ansible-preflight ansible-deploy-lb
	@echo "${GREEN}Deploying k3s cluster...${RESET}"
	@echo "This will:"
	@echo "  1. Deploy HAProxy load balancers with Keepalived"
	@echo "  2. Initialize first control plane node"
	@echo "  3. Join additional control plane nodes"
	@echo "  4. Join worker nodes"
	@echo ""
	$(ANSIBLE) -i $(ANSIBLE_INVENTORY) $(ANSIBLE_PLAYBOOK_DIR)/deploy-k3s.yml
	@echo ""
	@echo "${GREEN}k3s cluster deployed successfully!${RESET}"
	@echo "Run 'make ansible-kubeconfig' to fetch the kubeconfig"

ansible-deploy-apps:
	@echo "${GREEN}Deploying applications to k3s...${RESET}"
	@echo "This will deploy:"
	@echo "  - Storage provisioner (local-path)"
	@echo "  - Vault (secrets management)"
	@echo "  - Ollama (LLM runtime)"
	@echo "  - MinIO (S3 storage)"
	@echo "  - AI Ops Agent (FastAPI service)"
	@echo "  - Autoscaler (CronJob)"
	@echo ""
	$(ANSIBLE) -i $(ANSIBLE_INVENTORY) $(ANSIBLE_PLAYBOOK_DIR)/deploy-apps.yml
	@echo ""
	@echo "${GREEN}Applications deployed successfully!${RESET}"

ansible-kubeconfig:
	@echo "${GREEN}Fetching kubeconfig from cluster...${RESET}"
	@mkdir -p ~/.kube
	scp -o StrictHostKeyChecking=no cloud-user@10.100.0.10:~/.kube/config ~/.kube/config-aiops-prod
	@echo "Kubeconfig saved to: ~/.kube/config-aiops-prod"
	@echo ""
	@echo "To use this kubeconfig:"
	@echo "  export KUBECONFIG=~/.kube/config-aiops-prod"
	@echo "  kubectl get nodes"

ansible-verify:
	@echo "${GREEN}Verifying cluster deployment...${RESET}"
	$(ANSIBLE) -i $(ANSIBLE_INVENTORY) $(ANSIBLE_PLAYBOOK_DIR)/deploy-k3s.yml --tags verify
	$(ANSIBLE) -i $(ANSIBLE_INVENTORY) $(ANSIBLE_PLAYBOOK_DIR)/deploy-apps.yml --tags verify

ansible-upgrade-k3s:
	@echo "${GREEN}Upgrading k3s cluster...${RESET}"
	@echo "WARNING: This will upgrade k3s on all nodes"
	@read -p "Continue? (y/N) " confirm && [ "$$confirm" = "y" ] || exit 1
	K3S_VERSION=$(K3S_VERSION) $(ANSIBLE) -i $(ANSIBLE_INVENTORY) $(ANSIBLE_PLAYBOOK_DIR)/upgrade-k3s.yml

ansible-drain-node:
	@echo "${GREEN}Draining node for maintenance...${RESET}"
	@read -p "Enter node name: " node && \
	$(ANSIBLE) -i $(ANSIBLE_INVENTORY) k3s-cp-01 -m shell -a "kubectl drain $$node --ignore-daemonsets --delete-emptydir-data"

ansible-uncordon-node:
	@echo "${GREEN}Uncordoning node...${RESET}"
	@read -p "Enter node name: " node && \
	$(ANSIBLE) -i $(ANSIBLE_INVENTORY) k3s-cp-01 -m shell -a "kubectl uncordon $$node"

ansible-logs:
	@echo "${GREEN}Fetching k3s logs from control plane...${RESET}"
	$(ANSIBLE) -i $(ANSIBLE_INVENTORY) control_plane -m shell -a "journalctl -u k3s -n 100"

# -----------------------------------------------------------------------------
# Autoscaler: Build & Deploy
# -----------------------------------------------------------------------------
REGISTRY ?= registry.corp.example.com
AUTOSCALER_IMAGE := $(REGISTRY)/proxmox-autoscaler
AUTOSCALER_TAG ?= latest

autoscaler-build:
	@echo "${GREEN}Building autoscaler container image...${RESET}"
	$(DOCKER) build -t $(AUTOSCALER_IMAGE):$(AUTOSCALER_TAG) \
		-f cluster/autoscaler/Dockerfile .
	@echo "${GREEN}Built $(AUTOSCALER_IMAGE):$(AUTOSCALER_TAG)${RESET}"

autoscaler-push: autoscaler-build
	@echo "${GREEN}Pushing autoscaler image...${RESET}"
	$(DOCKER) push $(AUTOSCALER_IMAGE):$(AUTOSCALER_TAG)

autoscaler-sign: autoscaler-push
	@echo "${GREEN}Signing autoscaler image...${RESET}"
	$(COSIGN) sign --key cosign.key $(AUTOSCALER_IMAGE):$(AUTOSCALER_TAG)

autoscaler-deploy:
	@echo "${GREEN}Deploying autoscaler to k3s...${RESET}"
	$(KUBECTL) apply -f cluster/autoscaler/deployment.yaml
	@echo "Waiting for autoscaler CronJob to be created..."
	$(KUBECTL) wait --for=condition=complete --timeout=60s \
		-n autoscaler job -l app=proxmox-autoscaler || true
	@echo "${GREEN}Autoscaler deployed successfully${RESET}"

autoscaler-status:
	@echo "${GREEN}Autoscaler status:${RESET}"
	@echo ""
	@echo "CronJob:"
	$(KUBECTL) get cronjob -n autoscaler
	@echo ""
	@echo "Recent Jobs:"
	$(KUBECTL) get jobs -n autoscaler --sort-by=.metadata.creationTimestamp | tail -5
	@echo ""
	@echo "Recent Pods:"
	$(KUBECTL) get pods -n autoscaler --sort-by=.metadata.creationTimestamp | tail -5
	@echo ""
	@echo "Recent Logs:"
	$(KUBECTL) logs -n autoscaler -l app=proxmox-autoscaler --tail=20 || echo "No logs yet"

autoscaler-logs:
	$(KUBECTL) logs -n autoscaler -l app=proxmox-autoscaler -f

autoscaler-test:
	@echo "${GREEN}Triggering manual autoscaler run...${RESET}"
	$(KUBECTL) create job -n autoscaler --from=cronjob/proxmox-autoscaler autoscaler-manual-$$(date +%s)

# -----------------------------------------------------------------------------
# VM Management
# -----------------------------------------------------------------------------
vm-list:
	@echo "${GREEN}Listing VMs with autoscale tags...${RESET}"
	@cd infra/proxmox && $(TERRAFORM) output -json autoscaling_config | jq -r '.asg_vmids[]'

vm-scale-up:
	@echo "${GREEN}Manually triggering scale up...${RESET}"
	$(KUBECTL) exec -n autoscaler \
		$$($(KUBECTL) get pod -n autoscaler -l app=proxmox-autoscaler -o jsonpath='{.items[0].metadata.name}') \
		-- python3 /app/autoscaler.py --once --cpu-scale-up 0

vm-scale-down:
	@echo "${GREEN}Manually triggering scale down...${RESET}"
	$(KUBECTL) exec -n autoscaler \
		$$($(KUBECTL) get pod -n autoscaler -l app=proxmox-autoscaler -o jsonpath='{.items[0].metadata.name}') \
		-- python3 /app/autoscaler.py --once --cpu-scale-down 100

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
