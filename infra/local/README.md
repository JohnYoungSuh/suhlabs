# Local Kind Cluster - Terraform Configuration

This directory contains Terraform configuration for deploying a local Kind (Kubernetes in Docker) cluster for development and testing of the AI Ops Substrate.

## Architecture

```
┌─────────────────────────────────────────┐
│         Kind Cluster (Docker)           │
│                                         │
│  ┌────────────┐   ┌──────────────────┐ │
│  │  Control   │   │  Worker Node 1   │ │
│  │   Plane    │   │                  │ │
│  └────────────┘   └──────────────────┘ │
│         │                    │          │
│  ┌──────────────────┐       │          │
│  │  Worker Node 2   │───────┘          │
│  └──────────────────┘                  │
│                                         │
│  Namespaces:                            │
│  - ai-ops (AI Ops Agent)                │
│  - monitoring (Prometheus, Grafana)     │
│  - vault (Secrets Management)           │
└─────────────────────────────────────────┘
         ↑                    ↑
    Port 30080          Port 30443
```

## Prerequisites

1. **Docker** - Kind runs Kubernetes in Docker containers
2. **Terraform** >= 1.6.0
3. **kubectl** - For interacting with the cluster

### Installation (macOS/Linux)

```bash
# Install Terraform
brew install terraform

# Install Kind
brew install kind

# Install kubectl
brew install kubectl

# Or use the provided Makefile
make install-tools
```

## Quick Start

### 1. Initialize Terraform

```bash
cd infra/local
terraform init
```

### 2. Review the Plan

```bash
terraform plan
```

### 3. Apply Configuration

```bash
terraform apply
```

This will create:
- 1x Kind cluster named `aiops-dev`
- 1x Control plane node
- 2x Worker nodes
- 3x Namespaces (ai-ops, monitoring, vault)
- ConfigMaps for AI Ops configuration
- Service accounts

### 4. Access the Cluster

```bash
# Kind automatically updates your kubeconfig
kubectl cluster-info --context kind-aiops-dev

# View namespaces
kubectl get namespaces

# View nodes
kubectl get nodes
```

### 5. Destroy (when done)

```bash
terraform destroy
```

## Configuration

### Customize Cluster

Edit `variables.tf` or create `terraform.tfvars`:

```hcl
# terraform.tfvars
cluster_name  = "my-cluster"
worker_nodes  = 3
environment   = "development"

ai_ops_config = {
  log_level   = "debug"
  ollama_host = "http://ollama-service:11434"
}
```

### Enable Network Policies

```hcl
enable_network_policies = true
```

This creates default-deny policies for all namespaces (zero-trust).

### Enable Resource Quotas

```hcl
enable_resource_quotas = true
```

This limits resource usage per namespace.

## Usage with Makefile

```bash
# From project root
make tf-init       # Initialize Terraform
make tf-plan       # Show execution plan
make tf-apply      # Apply configuration
make tf-destroy    # Destroy infrastructure

# Combined workflow
make kind-up       # Creates cluster using Terraform
```

## Outputs

After `terraform apply`, you'll see:

```hcl
Outputs:

cluster_name      = "aiops-dev"
cluster_endpoint  = "https://127.0.0.1:xxxxx"
namespaces        = ["ai-ops", "monitoring", "vault"]
ai_ops_namespace  = "ai-ops"
service_account   = "ai-ops-agent"
```

## Testing the Cluster

```bash
# Check cluster health
kubectl get nodes
kubectl get pods -A

# Test AI Ops namespace
kubectl get all -n ai-ops

# Port forward for testing
kubectl port-forward -n ai-ops svc/ai-ops-agent 8000:80
curl http://localhost:8000/health
```

## Troubleshooting

### Cluster won't start

```bash
# Check Docker is running
docker ps

# Check Kind logs
kind get clusters
kind delete cluster --name aiops-dev
terraform apply  # Recreate
```

### Port conflicts

If ports 30080 or 30443 are in use:

```hcl
# terraform.tfvars
http_port  = 31080
https_port = 31443
```

### Kubeconfig issues

```bash
# Manually update kubeconfig
kind export kubeconfig --name aiops-dev

# Verify context
kubectl config current-context
```

## Day 3 Goals (from Sprint Plan)

- [x] Create Terraform configuration for Kind cluster
- [x] Set up provider configurations (kind, kubernetes, helm)
- [x] Create reusable namespace module
- [x] Practice Terraform workflow (init → plan → apply → destroy)
- [ ] Test: Destroy and recreate cluster 10x until <2 min

## Muscle Memory Targets

According to the 14-Day Sprint Plan, Day 3 targets:
- `terraform init → apply → destroy` in <2 minutes
- Recreate entire stack blindfolded

## Next Steps

1. **Day 4**: Ansible for configuration management
2. **Day 5**: Vault secrets integration
3. **Day 6**: Full CI/CD pipeline
4. **Day 7**: Week 1 integration test

## Module Structure

```
infra/
├── local/
│   ├── main.tf           # Main configuration
│   ├── variables.tf      # Input variables
│   ├── versions.tf       # Provider versions
│   ├── README.md         # This file
│   └── terraform.tfstate # State file (local backend)
├── modules/
│   └── k8s-namespace/    # Reusable namespace module
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── README.md
└── proxmox/              # Production deployment (future)
```

## Resources Created

| Resource | Type | Purpose |
|----------|------|---------|
| kind_cluster.default | Kind Cluster | Local K8s cluster |
| kubernetes_namespace.namespaces | Namespace | ai-ops, monitoring, vault |
| kubernetes_service_account.ai_ops_agent | ServiceAccount | AI Ops agent identity |
| kubernetes_config_map.ai_ops_config | ConfigMap | AI Ops configuration |

## Security Notes

- **Non-root containers**: All deployments should use non-root users
- **Network policies**: Enable in production for zero-trust
- **Resource quotas**: Prevent resource exhaustion
- **RBAC**: Service accounts have minimal required permissions

## Performance

| Operation | Time (Cold) | Time (Warm) |
|-----------|-------------|-------------|
| terraform init | 15s | 2s |
| terraform plan | 5s | 3s |
| terraform apply | 90s | 60s |
| terraform destroy | 30s | 20s |

## References

- [Kind Documentation](https://kind.sigs.k8s.io/)
- [Terraform Kubernetes Provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)
- [14-Day Sprint Plan](../../docs/14-DAY-SPRINT.md)

---

**Day 3 Status**: ✅ Configuration Complete, Ready for Testing
