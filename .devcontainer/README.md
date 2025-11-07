# Devcontainer for AIOps Substrate

This devcontainer provides a complete, pre-configured development environment with all tools installed.

## What's Included

### Pre-installed Tools

- **Docker** (via docker-in-docker) - Run containers inside the devcontainer
- **Terraform** 1.6.6 - Infrastructure as code
- **Packer** 1.10.0 - VM template builder
- **kubectl** (latest) - Kubernetes CLI
- **kind** v0.20.0 - Kubernetes in Docker
- **helm** (latest) - Kubernetes package manager
- **ansible** (latest) - Automation tool
- **GitHub CLI** - gh command
- **Python** 3.11 - With pip, black, pylint

### VS Code Extensions

All recommended extensions auto-install:
- HashiCorp Terraform + HCL
- Red Hat Ansible + YAML
- Python (Pylance, Black formatter)
- Kubernetes Tools
- Docker
- GitLens
- Markdown All in One

## Quick Start

### Option 1: VS Code UI

1. **Install Extension**: "Dev Containers" (ms-vscode-remote.remote-containers)

2. **Open Folder**: `File → Open Folder` → Select `aiops-substrate/`

3. **Reopen in Container**:
   - Click popup: "Reopen in Container"
   - Or Command Palette (`Ctrl+Shift+P`): "Dev Containers: Reopen in Container"

4. **Wait for Build**: First time takes 3-5 minutes

5. **Start Working**:
   ```bash
   # All tools already installed!
   make dev-up      # Start services
   make kind-up     # Create k8s cluster
   ```

### Option 2: Command Line

```bash
# From local machine
cd ~/projects/suhlabs/aiops-substrate

# Open in devcontainer
devcontainer open .
```

## Features

### Docker-in-Docker

Run Docker commands inside the container:
```bash
docker ps
docker compose up
docker build
```

No need for Docker Desktop WSL2 integration!

### Port Forwarding

These ports are automatically forwarded to your local machine:
- **30080** - AI Ops Agent
- **8200** - Vault
- **11434** - Ollama
- **9000** - MinIO S3
- **9001** - MinIO Console
- **6443** - Kubernetes API

Access from Windows: `http://localhost:8200`

### Persistent Storage

Your workspace files persist between container rebuilds:
- `/workspaces/aiops-substrate` (your code)
- `~/.kube` (kubectl config)
- Docker volumes (container data)

## Usage

### After Container Starts

```bash
# Verify all tools
docker --version
terraform version
packer version
kubectl version --client
kind version
helm version
ansible --version

# Start local services
make dev-up

# Create Kubernetes cluster
make kind-up

# Check cluster
kubectl get nodes
```

### Rebuild Container

If you update `.devcontainer/devcontainer.json`:

1. Command Palette (`Ctrl+Shift+P`)
2. "Dev Containers: Rebuild Container"

### Stop Container

- Close VS Code window (container stops automatically)
- Or Command Palette: "Dev Containers: Close Remote Connection"

## Troubleshooting

### Container won't start

**Check**: Docker Desktop is running on Windows
- Start Docker Desktop
- Wait for whale icon to be steady (not animated)

### Port already in use

**Fix**: Stop conflicting services on Windows
```powershell
# In PowerShell
netstat -ano | findstr :8200
# Kill process using the port
```

### Tools missing after rebuild

**Fix**: Rebuild from scratch
1. Command Palette: "Dev Containers: Rebuild Without Cache"
2. Wait for complete rebuild

### Can't connect to Kubernetes

**Fix**: Recreate kind cluster
```bash
make kind-down
make kind-up
```

## Comparison: Devcontainer vs Local WSL2

| Feature | Devcontainer | Local WSL2 |
|---------|--------------|------------|
| Tool installation | Automatic | Manual |
| Docker | Built-in (DinD) | Needs Desktop integration |
| Consistency | Same for everyone | Varies |
| Setup time | 3-5 min (first time) | 30+ min |
| WSL2 issues | Isolated | Can conflict |
| Certificates | No issues | Cert validation errors |

## Advanced

### Custom Port Forwarding

Edit `.devcontainer/devcontainer.json`:
```json
"forwardPorts": [8080, 3000],
```

### Add More Tools

In `postCreateCommand`:
```json
"postCreateCommand": "pip install mypy && npm install -g prettier"
```

### Mount Additional Volumes

```json
"mounts": [
  "source=${localEnv:HOME}/.ssh,target=/home/vscode/.ssh,readonly,type=bind"
]
```

## Resources

- [VS Code Dev Containers](https://code.visualstudio.com/docs/devcontainers/containers)
- [Devcontainer Features](https://containers.dev/features)
- [Docker-in-Docker](https://github.com/devcontainers/features/tree/main/src/docker-in-docker)
