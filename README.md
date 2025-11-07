# AIOps Substrate

Family homelab with AI-powered infrastructure management - from Docker Desktop to production Proxmox cluster.

## Quick Start

```bash
# 1. Clone repository
git clone https://github.com/JohnYoungSuh/suhlabs.git aiops-substrate
cd aiops-substrate

# 2. Install development tools
make setup-tools

# 3. Start local services
make dev-up

# 4. Create Kubernetes cluster
make kind-up

# 5. Open in VS Code
code aiops-substrate.code-workspace
```

See [docs/QUICKSTART.md](docs/QUICKSTART.md) for detailed instructions.

## Project Structure

```
aiops-substrate/
├── packer/              # VM templates for Proxmox
├── infra/               # Terraform infrastructure
│   ├── local/          # Local (kind) setup
│   └── proxmox/        # Production Proxmox
├── ansible/            # Automation playbooks
│   ├── roles/          # Reusable roles
│   └── deploy-*.yml    # Deployment playbooks
├── cluster/            # Kubernetes manifests
│   ├── ai-ops-agent/   # AI-powered agent
│   └── autoscaler/     # VM autoscaling
├── bootstrap/          # Local development
│   ├── docker-compose.yml
│   └── kind-cluster.yaml
├── docs/               # Documentation
├── scripts/            # Helper scripts
├── jira/              # Sprint planning
└── Makefile           # All commands
```

## Features

- 🤖 **AI-Powered Management** - Natural language infrastructure requests via Ollama LLM
- ☸️ **Kubernetes** - k3s cluster with HA control plane
- 🔐 **Security First** - Vault secrets, FreeIPA identity, network policies
- 📦 **Infrastructure as Code** - Packer, Terraform, Ansible automation
- 🔄 **Auto-scaling** - VM autoscaling based on cluster metrics
- 🏠 **Family-Friendly** - Services for media, storage, backups

## Architecture

### Local Development (Phase 1)
```
Docker Desktop + WSL2
├── Vault (secrets)
├── Ollama (LLM)
├── MinIO (S3)
└── kind (Kubernetes)
```

### Production (Phase 2)
```
Proxmox Cluster
├── HAProxy (2x) - Load balancer with Keepalived
├── k3s Control Plane (3x) - HA with embedded etcd
├── k3s Workers (3+) - Workload nodes
└── Services
    ├── AI Ops Agent
    ├── FreeIPA (LDAP/Kerberos)
    ├── BIND DNS
    └── Family Services (Plex, Nextcloud, etc.)
```

## Documentation

- [Quick Start Guide](docs/QUICKSTART.md) - Get running in 5 minutes
- [Local Development](docs/local-development.md) - Docker Desktop setup
- [Deployment Runbook](docs/deployment-runbook.md) - Production deployment
- [Packer Templates](packer/README.md) - VM template building
- [Docker Desktop Setup](docs/docker-desktop-wsl2-setup.md) - WSL2 integration

## Common Commands

### Local Development
```bash
make dev-up          # Start services (Vault, Ollama, MinIO)
make kind-up         # Create Kubernetes cluster
make dev-down        # Stop and cleanup
```

### Packer (VM Templates)
```bash
make packer-validate # Validate template
make packer-build    # Build CentOS 9 template
```

### Terraform (Infrastructure)
```bash
make init-prod       # Initialize Terraform
make plan-prod       # Plan infrastructure
make apply-prod      # Provision VMs
```

### Ansible (Deployment)
```bash
make ansible-ping            # Test connectivity
make ansible-deploy-k3s      # Deploy k3s cluster
make ansible-deploy-apps     # Deploy applications
make ansible-kubeconfig      # Fetch kubeconfig
```

### Kubernetes
```bash
kubectl get nodes           # List cluster nodes
kubectl get pods -A        # List all pods
make ansible-validate      # Full validation
```

## Prerequisites

### Local Development
- Docker Desktop with WSL2
- 8GB+ RAM
- 20GB+ free disk space

### Production Deployment
- Proxmox VE cluster (3+ nodes recommended)
- Proxmox API access
- Network VLAN for cluster
- 2+ mini PCs or servers

## Workflow

1. **Local First**: Develop and test on Docker Desktop + kind
2. **Build Template**: Create VM template with Packer
3. **Provision**: Deploy VMs with Terraform
4. **Configure**: Deploy k3s with Ansible
5. **Deploy Apps**: Install services and applications
6. **Monitor**: Observe and manage infrastructure

## Jira Integration

Sprint planning and task tracking:
- [jira/ansible-deployment-sprint.csv](jira/ansible-deployment-sprint.csv) - Import into Jira
- [jira/jira-import.csv](jira/jira-import.csv) - Complete project structure

Reference issue keys in commits:
```bash
git commit -m "HOMELAB-3: Add feature xyz"
```

## Technology Stack

| Layer | Technology |
|-------|-----------|
| **Orchestration** | Kubernetes (k3s) |
| **Infrastructure** | Proxmox VE, Terraform, Packer |
| **Automation** | Ansible |
| **Secrets** | HashiCorp Vault |
| **Identity** | FreeIPA (LDAP + Kerberos) |
| **DNS** | BIND |
| **Load Balancer** | HAProxy + Keepalived |
| **AI/LLM** | Ollama (Llama 3.1) |
| **Storage** | MinIO (S3), Ceph (optional) |
| **Monitoring** | Prometheus + Grafana (optional) |

## Contributing

This is a personal homelab project, but feedback and suggestions are welcome!

## License

MIT License - See [LICENSE](LICENSE) for details

## Support

For issues or questions:
- Check documentation in [docs/](docs/)
- Review [troubleshooting guides](docs/docker-desktop-wsl2-setup.md#common-issues)
- Open an issue on GitHub

---

**Status**: 🚧 Active Development
**Phase**: Local Development → Production Deployment
**Last Updated**: 2025-11-07
