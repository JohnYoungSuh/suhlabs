# Quick Start Guide

Get up and running with AIOps Substrate in 5 minutes.

## Prerequisites

- Docker Desktop installed and running
- WSL2 enabled (Windows) or Linux
- Git installed

## Step 1: Clone Repository

```bash
cd /home/suhlabs/projects/suhlabs
git clone https://github.com/JohnYoungSuh/suhlabs.git aiops-substrate
cd aiops-substrate
```

## Step 2: Install Development Tools

```bash
# Install kubectl, kind, helm, ansible
make setup-tools
```

This installs:
- ✅ kubectl (Kubernetes CLI)
- ✅ kind (Kubernetes in Docker)
- ✅ helm (Kubernetes package manager)
- ✅ ansible (Automation tool)

## Step 3: Enable Docker Desktop WSL2 Integration

1. Open Docker Desktop
2. Go to **Settings → Resources → WSL Integration**
3. Enable your WSL distro
4. Click **Apply & Restart**

Verify:
```bash
docker --version
docker compose version
```

## Step 4: Start Local Stack

```bash
# Start Vault, Ollama, MinIO, PostgreSQL
make dev-up
```

Services will be available at:
- Vault: http://localhost:8200 (token: `root`)
- Ollama: http://localhost:11434
- MinIO: http://localhost:9000
- PostgreSQL: localhost:5432

## Step 5: Create Kubernetes Cluster

```bash
# Create 3-node kind cluster
make kind-up

# Verify cluster
kubectl get nodes
```

You should see 3 nodes:
- aiops-dev-control-plane
- aiops-dev-worker
- aiops-dev-worker2

## Step 6: Pull LLM Model

```bash
# Pull Llama 3.1 8B model (~5 minutes)
docker exec -it aiops-ollama ollama pull llama3.1:8b

# Verify
docker exec -it aiops-ollama ollama list
```

## Step 7: Deploy Applications

```bash
# Deploy AI Ops Agent (coming soon)
kubectl apply -f cluster/ai-ops-agent/

# Check status
kubectl get pods -A
```

## Verify Everything

```bash
# Check services
docker ps

# Check Kubernetes
kubectl get nodes
kubectl get pods -A

# Test Vault
curl http://localhost:8200/v1/sys/health

# Test Ollama
curl http://localhost:11434/api/tags
```

## Next Steps

- **Test Ansible Playbooks**: See [local-development.md](local-development.md)
- **Deploy to Production**: See [deployment-runbook.md](deployment-runbook.md)
- **Configure Proxmox**: See [packer/README.md](../packer/README.md)

## Cleanup

```bash
# Stop everything
make dev-down

# This will:
# - Stop all Docker containers
# - Delete kind cluster
# - Remove volumes
```

## Troubleshooting

### Docker not found
- Enable WSL2 integration in Docker Desktop
- See [docker-desktop-wsl2-setup.md](docker-desktop-wsl2-setup.md)

### kind not found
- Run `make setup-tools`
- Or manually install: `curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64 && chmod +x ./kind && sudo mv ./kind /usr/local/bin/`

### Port already in use
- Change ports in `bootstrap/docker-compose.yml`
- Or stop conflicting services

## Common Commands

```bash
# See all available commands
make help

# Start local development
make dev-up
make kind-up

# Stop local development
make dev-down

# View logs
make dev-logs

# Install/update tools
make setup-tools
```

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│              Docker Desktop (WSL2)                  │
├─────────────────────────────────────────────────────┤
│  Services (docker-compose):                         │
│  ├── Vault (secrets)                                │
│  ├── Ollama (LLM)                                   │
│  ├── MinIO (S3)                                     │
│  └── PostgreSQL (DB)                                │
├─────────────────────────────────────────────────────┤
│  Kubernetes (kind):                                 │
│  ├── Control Plane (1 node)                         │
│  ├── Workers (2 nodes)                              │
│  └── Apps:                                          │
│      ├── AI Ops Agent                               │
│      ├── DNS Service                                │
│      └── FreeIPA (optional)                         │
└─────────────────────────────────────────────────────┘
```

## Support

For issues or questions:
- Check [local-development.md](local-development.md)
- Review [troubleshooting guide](docker-desktop-wsl2-setup.md#common-issues)
- Check project README
