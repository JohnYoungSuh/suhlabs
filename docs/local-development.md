# Local Development Guide

This guide walks you through setting up a complete local development environment using Docker Desktop and kind (Kubernetes in Docker).

## Why Local First?

- ✅ **Fast iteration** - No VM provisioning wait times
- ✅ **Test safely** - No risk to production hardware
- ✅ **Learn the workflow** - Understand deployment before production
- ✅ **Portable** - Work from any machine with Docker
- ✅ **Easy cleanup** - `make dev-down` removes everything

## Prerequisites

### Required Tools

1. **Docker Desktop** (with WSL2 on Windows)
   ```bash
   docker --version
   # Should be >= 24.0
   ```

2. **kind** (Kubernetes in Docker)
   ```bash
   # Install on Linux/WSL2
   curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
   chmod +x ./kind
   sudo mv ./kind /usr/local/bin/kind

   # Verify
   kind --version
   ```

3. **kubectl**
   ```bash
   # Install on Linux/WSL2
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   chmod +x kubectl
   sudo mv kubectl /usr/local/bin/

   # Verify
   kubectl version --client
   ```

4. **Ansible** (for playbook testing)
   ```bash
   # Install on Linux/WSL2
   sudo apt update
   sudo apt install -y ansible

   # Or via pip
   pip3 install ansible

   # Verify
   ansible --version
   ```

5. **Make** (should already be installed)
   ```bash
   make --version
   ```

## Quick Start

### Step 1: Start Local Services

From the project root:

```bash
# Start Vault, Ollama, MinIO, PostgreSQL
make dev-up
```

This will start:
- **Vault**: http://localhost:8200 (token: `root`)
- **Ollama**: http://localhost:11434
- **MinIO**: http://localhost:9000 (console: http://localhost:9001)
  - User: `admin`
  - Password: `changeme123`
- **PostgreSQL**: localhost:5432
  - User: `aiops`
  - Password: `aiops123`

### Step 2: Pull Ollama Model

```bash
# Pull the Llama 3.1 8B model (takes ~5 minutes)
docker exec -it aiops-ollama ollama pull llama3.1:8b

# Verify
docker exec -it aiops-ollama ollama list
```

### Step 3: Create kind Cluster

```bash
# Create 3-node cluster (1 control plane, 2 workers)
make kind-up

# Verify cluster
kubectl get nodes
# Should show 3 nodes: aiops-dev-control-plane, aiops-dev-worker, aiops-dev-worker2
```

### Step 4: Deploy Applications Locally

```bash
# Deploy to kind cluster
kubectl apply -f cluster/ai-ops-agent/deployment.yaml

# Check status
kubectl get pods -A
```

## Development Workflow

### Test Ansible Playbooks

The local environment lets you test Ansible playbooks without VMs:

```bash
# Test inventory
ansible-inventory -i inventory/local.yml --list

# Test connectivity (for local testing, create a localhost inventory)
ansible -i inventory/local.yml all -m ping

# Run playbook in check mode
ansible-playbook -i inventory/local.yml ansible/deploy-apps.yml --check
```

### Access Services

```bash
# Vault
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=root
vault status

# Ollama
curl http://localhost:11434/api/tags

# MinIO Console
open http://localhost:9001

# Kubernetes Dashboard (if deployed)
kubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard 8443:443
```

### View Logs

```bash
# Docker Compose logs
make dev-logs

# Or specific service
docker logs -f aiops-vault
docker logs -f aiops-ollama
docker logs -f aiops-minio

# Kubernetes pod logs
kubectl logs -n aiops deployment/ai-ops-agent -f
```

## Testing Checklist

Before moving to production Proxmox deployment, verify:

- [ ] Vault is accessible and unsealed
- [ ] Ollama has llama3.1:8b model loaded
- [ ] MinIO console is accessible
- [ ] kind cluster has 3 nodes Ready
- [ ] Can deploy test workloads to kind
- [ ] Ansible playbooks run without errors (in check mode)
- [ ] AI Ops Agent responds to health checks

## Cleanup

```bash
# Stop and remove everything
make dev-down

# Or individually
make kind-down
docker-compose -f bootstrap/docker-compose.yml down -v
```

## Troubleshooting

### Docker Desktop not running

**Error**: `Cannot connect to the Docker daemon`

**Solution**: Start Docker Desktop

### kind cluster creation fails

**Error**: `failed to create cluster`

**Solution**: Check Docker has enough resources (4GB+ RAM recommended)
```bash
docker system info | grep -i memory
```

### Ollama model pull fails

**Error**: `failed to pull model`

**Solution**: Check disk space. Llama 3.1 8B requires ~5GB.
```bash
df -h
```

### Port already in use

**Error**: `Bind for 0.0.0.0:8200 failed: port is already allocated`

**Solution**: Stop conflicting service or change port in `bootstrap/docker-compose.yml`

## Next Steps

Once local development is working:

1. ✅ Test all Ansible playbooks locally
2. ✅ Verify application deployments
3. ✅ Document any issues or improvements
4. 🚀 **Move to production Proxmox deployment**

See [deployment-runbook.md](deployment-runbook.md) for production deployment steps.

## Local vs Production Differences

| Aspect | Local (kind) | Production (Proxmox) |
|--------|--------------|----------------------|
| Cluster | kind (Docker) | k3s (VMs) |
| Nodes | 3 containers | 6+ VMs |
| Storage | hostPath | Ceph or local-path |
| Network | Docker bridge | VLAN + HAProxy |
| HA | Single control plane | 3x control plane |
| Persistence | Lost on restart | Persistent |
| Cost | Free | ~$500-1000 hardware |

## Resources

- [kind Documentation](https://kind.sigs.k8s.io/)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [Ansible Testing Strategies](https://docs.ansible.com/ansible/latest/dev_guide/testing.html)
