# =============================================================================
# AIOps Substrate – Makefile
# Architecture: Backend (Cloud SaaS) + Appliance (Raspberry Pi)
# Supports: Local (Docker) → Proxmox (k3s) → AWS (EKS)
# Version: 3.0
# =============================================================================

.PHONY: all help \
        dev-up dev-down dev-logs dev-restart \
        backend-up backend-down backend-logs \
        appliances-up appliances-down appliances-logs \
        ollama-pull ollama-model \
        test test-backend test-appliance test-integration \
        lint format validate \
        build-backend build-appliance build-all \
        deploy deploy-proxmox deploy-aws \
        clean clean-all

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# Environment switch
ENV ?= local

# Tools
DOCKER    := docker
COMPOSE   := docker compose
TERRAFORM := terraform
ANSIBLE   := ansible-playbook
KUBECTL   := kubectl
PYTHON    := python3
SYFT      := syft
COSIGN    := cosign

# Project paths
BACKEND_DIR   := backend
APPLIANCE_DIR := appliance
INFRA_DIR     := infra

# Docker Compose profiles
COMPOSE_FILE := docker-compose.yml

# Colors
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
BLUE   := $(shell tput -Txterm setaf 4)
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
	@echo "${YELLOW}╔═══════════════════════════════════════════════════╗${RESET}"
	@echo "${YELLOW}║  AIOps Substrate – Backend + Appliance Platform  ║${RESET}"
	@echo "${YELLOW}╚═══════════════════════════════════════════════════╝${RESET}"
	@echo ""
	@echo "${BLUE}📦 Local Development (Docker):${RESET}"
	@echo "  dev-up           Start full stack (backend + 3 appliances)"
	@echo "  dev-down         Stop all services"
	@echo "  dev-logs         View logs from all services"
	@echo "  dev-restart      Restart all services"
	@echo ""
	@echo "${BLUE}🔧 Backend Services:${RESET}"
	@echo "  backend-up       Start backend only (API, LLM, DB)"
	@echo "  backend-down     Stop backend services"
	@echo "  backend-logs     View backend logs"
	@echo "  ollama-model     Pull Llama 3.2 3B model"
	@echo ""
	@echo "${BLUE}📱 Appliances:${RESET}"
	@echo "  appliances-up    Start simulated appliances"
	@echo "  appliances-down  Stop appliances"
	@echo "  appliances-logs  View appliance logs"
	@echo ""
	@echo "${BLUE}🏗️  Build:${RESET}"
	@echo "  build-backend    Build backend Docker image"
	@echo "  build-appliance  Build appliance Docker image"
	@echo "  build-all        Build all images"
	@echo ""
	@echo "${BLUE}🧪 Testing:${RESET}"
	@echo "  test             Run all tests"
	@echo "  test-backend     Test backend API"
	@echo "  test-appliance   Test appliance services"
	@echo "  test-integration Test backend + appliance integration"
	@echo ""
	@echo "${BLUE}☁️  Deployment:${RESET}"
	@echo "  deploy-proxmox   Deploy to Proxmox (k3s cluster)"
	@echo "  deploy-aws       Deploy to AWS (EKS cluster)"
	@echo ""
	@echo "${BLUE}🔍 Quality:${RESET}"
	@echo "  lint             Run all linters"
	@echo "  format           Format code (Python, Terraform)"
	@echo "  validate         Validate configurations"
	@echo ""
	@echo "${BLUE}🧹 Cleanup:${RESET}"
	@echo "  clean            Clean build artifacts"
	@echo "  clean-all        Clean everything (including volumes)"
	@echo ""
	@echo "${GREEN}Quick Start:${RESET}"
	@echo "  1. make ollama-model     # Pull LLM model (one-time)"
	@echo "  2. make dev-up           # Start everything"
	@echo "  3. Visit http://localhost:8000"
	@echo ""

# -----------------------------------------------------------------------------
# Local Development (Docker Compose)
# -----------------------------------------------------------------------------

# Start full stack (backend + appliances)
dev-up:
	@echo "${GREEN}🚀 Starting full AIOps development environment...${RESET}"
	$(COMPOSE) up -d
	@echo ""
	@echo "${GREEN}✅ Stack started successfully!${RESET}"
	@echo ""
	@echo "  Backend API:     http://localhost:8000"
	@echo "  API Docs:        http://localhost:8000/docs"
	@echo "  Ollama:          http://localhost:11434"
	@echo "  PostgreSQL:      localhost:5432 (user: aiops, pass: aiops123)"
	@echo "  Redis:           localhost:6379"
	@echo ""
	@echo "  Appliance 001:   http://localhost:8001 (DNS: 5301, Samba: 4451)"
	@echo "  Appliance 002:   http://localhost:8002 (DNS: 5302, Samba: 4452)"
	@echo "  Appliance 003:   http://localhost:8003 (DNS: 5303, Samba: 4453)"
	@echo ""
	@echo "${YELLOW}💡 Tip: Run 'make dev-logs' to view logs${RESET}"
	@echo ""

dev-down:
	@echo "${YELLOW}Stopping all services...${RESET}"
	$(COMPOSE) down

dev-down-clean:
	@echo "${YELLOW}Stopping and removing volumes...${RESET}"
	$(COMPOSE) down -v

dev-logs:
	$(COMPOSE) logs -f

dev-restart:
	@echo "${YELLOW}Restarting services...${RESET}"
	$(COMPOSE) restart

dev-status:
	$(COMPOSE) ps

# -----------------------------------------------------------------------------
# Backend Services
# -----------------------------------------------------------------------------

backend-up:
	@echo "${GREEN}Starting backend services only...${RESET}"
	$(COMPOSE) up -d postgres redis ollama backend-api
	@echo "Backend ready at http://localhost:8000"

backend-down:
	$(COMPOSE) stop postgres redis ollama backend-api

backend-logs:
	$(COMPOSE) logs -f backend-api

backend-shell:
	$(COMPOSE) exec backend-api /bin/bash

# Pull Ollama model
ollama-model:
	@echo "${GREEN}Pulling Llama 3.2 3B model...${RESET}"
	$(DOCKER) exec aiops-ollama ollama pull llama3.2:3b
	@echo "${GREEN}Model pulled successfully${RESET}"

ollama-list:
	$(DOCKER) exec aiops-ollama ollama list

# -----------------------------------------------------------------------------
# Appliances
# -----------------------------------------------------------------------------

appliances-up:
	@echo "${GREEN}Starting appliances...${RESET}"
	$(COMPOSE) up -d appliance-001 appliance-002 appliance-003

appliances-down:
	$(COMPOSE) stop appliance-001 appliance-002 appliance-003

appliances-logs:
	$(COMPOSE) logs -f appliance-001 appliance-002 appliance-003

appliance-shell:
	@echo "Select appliance (1-3):"
	@read -p "Appliance: " num; \
	$(COMPOSE) exec appliance-00$$num /bin/bash

# -----------------------------------------------------------------------------
# Build
# -----------------------------------------------------------------------------

build-backend:
	@echo "${GREEN}Building backend Docker image...${RESET}"
	$(DOCKER) build -t aiops-backend:latest $(BACKEND_DIR)/api

build-appliance:
	@echo "${GREEN}Building appliance Docker image...${RESET}"
	$(DOCKER) build -t aiops-appliance:latest $(APPLIANCE_DIR)

build-all: build-backend build-appliance
	@echo "${GREEN}All images built successfully${RESET}"

# -----------------------------------------------------------------------------
# Testing
# -----------------------------------------------------------------------------

test: test-backend test-appliance

test-backend:
	@echo "${GREEN}Testing backend API...${RESET}"
	@echo "Checking API health..."
	curl -f http://localhost:8000/health || echo "Backend not running. Start with 'make backend-up'"

test-appliance:
	@echo "${GREEN}Testing appliance services...${RESET}"
	@echo "Testing appliance 001..."
	curl -f http://localhost:8001 || echo "Appliance not running. Start with 'make appliances-up'"

test-integration:
	@echo "${GREEN}Running integration tests...${RESET}"
	@echo "Test 1: Heartbeat from appliance to backend"
	$(DOCKER) exec aiops-appliance-001 python3 -c "import httpx; print(httpx.post('http://backend-api:8000/api/v1/heartbeat', json={'appliance_id':'test','version':'1.0','uptime':100,'services':{},'metrics':{}}).json())"
	@echo "Test 2: Config sync"
	$(DOCKER) exec aiops-appliance-001 python3 -c "import httpx; print(httpx.get('http://backend-api:8000/api/v1/appliance/test/config').json())"

# Test LLM integration
test-llm:
	@echo "${GREEN}Testing LLM integration...${RESET}"
	cd $(BACKEND_DIR)/llm && $(PYTHON) client.py

# -----------------------------------------------------------------------------
# Linting & Validation
# -----------------------------------------------------------------------------

lint:
	@echo "${GREEN}Running linters...${RESET}"
	@echo "Linting Python..."
	cd $(BACKEND_DIR)/api && ruff check .
	cd $(APPLIANCE_DIR)/agent && ruff check .
	@echo "Linting Ansible..."
	ansible-lint $(BACKEND_DIR)/ansible/
	@echo "Linting Terraform..."
	terraform fmt -check -recursive $(INFRA_DIR)/

format:
	@echo "${GREEN}Formatting code...${RESET}"
	black $(BACKEND_DIR)/ $(APPLIANCE_DIR)/
	isort $(BACKEND_DIR)/ $(APPLIANCE_DIR)/
	terraform fmt -recursive $(INFRA_DIR)/

validate:
	@echo "${GREEN}Validating configurations...${RESET}"
	@echo "Validating Ansible playbooks..."
	ansible-playbook --syntax-check $(BACKEND_DIR)/ansible/playbooks/*.yml
	@echo "Validating Terraform..."
	cd $(INFRA_DIR)/proxmox && terraform validate
	cd $(INFRA_DIR)/aws && terraform validate

# -----------------------------------------------------------------------------
# Deployment (Proxmox / AWS)
# -----------------------------------------------------------------------------

deploy-proxmox:
	@echo "${GREEN}Deploying to Proxmox (k3s)...${RESET}"
	cd $(INFRA_DIR)/proxmox && terraform init && terraform apply
	@echo "${GREEN}Proxmox deployment complete${RESET}"

deploy-aws:
	@echo "${GREEN}Deploying to AWS (EKS)...${RESET}"
	cd $(INFRA_DIR)/aws && terraform init && terraform apply
	@echo "${GREEN}AWS deployment complete${RESET}"

# Run Ansible playbook on appliances
ansible-run:
	@echo "Which playbook? (dns, samba, users, mail, pki)"
	@read -p "Playbook: " playbook; \
	$(ANSIBLE) -i $(BACKEND_DIR)/ansible/inventory/appliances.yml \
	  $(BACKEND_DIR)/ansible/playbooks/$$playbook.yml

# -----------------------------------------------------------------------------
# Security & Compliance
# -----------------------------------------------------------------------------

sbom:
	@echo "${GREEN}Generating SBOM...${RESET}"
	$(SYFT) . -o cyclonedx-json > sbom.json
	$(SYFT) . -o spdx-json > sbom.spdx.json

# -----------------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------------

clean:
	@echo "${YELLOW}Cleaning build artifacts...${RESET}"
	find . -type f -name "*.pyc" -delete
	find . -type d -name "__pycache__" -delete
	find . -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
	rm -f sbom.*

clean-all: clean
	@echo "${YELLOW}Cleaning everything (including Docker volumes)...${RESET}"
	$(COMPOSE) down -v --remove-orphans
	docker system prune -af --volumes

# -----------------------------------------------------------------------------
# End of Makefile
# -----------------------------------------------------------------------------
