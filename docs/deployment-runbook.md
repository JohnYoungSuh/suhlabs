# AIOps Substrate - Deployment Runbook

## Complete Deployment Workflow

This runbook provides step-by-step instructions for deploying the AIOps substrate from scratch.

---

## Prerequisites

### Infrastructure
- [ ] Proxmox cluster (3+ nodes) operational
- [ ] Ceph storage configured
- [ ] Network VLAN configured (default: VLAN 100)
- [ ] DNS resolution working

### Credentials
- [ ] Proxmox API token created
- [ ] SSH keys generated
- [ ] Vault tokens prepared
- [ ] k3s cluster token generated

### Local Tools
- [ ] Packer >= 1.9.0
- [ ] Terraform >= 1.6.0
- [ ] Ansible >= 2.15.0
- [ ] kubectl >= 1.28.0
- [ ] Docker Desktop with WSL2

---

## Phase 1: Build VM Template

### 1.1 Configure Proxmox Credentials

```bash
export PM_API_URL="https://proxmox.corp.example.com:8006/api2/json"
export PM_API_TOKEN_ID="terraform@pam!terraform"
export PM_API_TOKEN_SECRET="your-secret-token"
```

### 1.2 Validate Packer Template

```bash
make packer-validate
```

Expected output:
```
The configuration is valid.
```

### 1.3 Build CentOS 9 Template

```bash
make packer-build
```

This will:
- Download CentOS Stream 9 ISO
- Install OS with kickstart automation
- Configure cloud-init
- Install containerd and k3s prerequisites
- Create Proxmox template: `centos9-cloud`

Time: ~20-30 minutes

---

## Phase 2: Provision Infrastructure

### 2.1 Configure Terraform Variables

```bash
cd infra/proxmox
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars
```

Update:
- `proxmox_api_token_id` and `proxmox_api_token_secret`
- `ssh_public_keys` (add your SSH public key)
- `vpc_cidr` (default: 10.100.0.0/24)
- Node counts (control_plane_count, worker_min_count, worker_max_count)

### 2.2 Initialize Terraform

```bash
make init-prod
```

### 2.3 Plan Infrastructure

```bash
make plan-prod
```

Review the plan. Expected resources:
- 2x HAProxy load balancers
- 3x k3s control plane VMs
- 3x k3s worker VMs (base pool)
- 7x k3s worker VMs (ASG pool, initially stopped)
- 1x Bastion host
- VPC network bridge
- Firewall rules

### 2.4 Apply Infrastructure

```bash
make apply-prod
```

Time: ~10-15 minutes

### 2.5 Verify VMs are Created

```bash
make vm-list
```

---

## Phase 3: Deploy k3s Cluster

### 3.1 Update Ansible Inventory

```bash
# Option 1: Use Terraform output to generate inventory
cd infra/proxmox
terraform output ansible_inventory > ../../inventory/proxmox.yml

# Option 2: Manually edit inventory
vim inventory/proxmox.yml
```

### 3.2 Test Connectivity

```bash
make ansible-ping
```

Expected: All hosts respond with `pong`

If connectivity fails:
- Check SSH keys are deployed via cloud-init
- Verify VMs are running: `pvesh get /cluster/resources --type vm`
- Check network connectivity: `ping 10.100.0.10`

### 3.3 Run Pre-flight Checks

```bash
make ansible-preflight
```

This validates:
- OS compatibility (CentOS/RHEL >= 8)
- Memory >= 2GB
- Disk space >= 10GB
- SSH access

### 3.4 Deploy k3s Cluster

```bash
make ansible-deploy-k3s
```

This will:
1. Deploy HAProxy load balancers with Keepalived (VIP: 10.100.0.5)
2. Initialize first control plane node (k3s-cp-01)
3. Join additional control plane nodes (k3s-cp-02, k3s-cp-03)
4. Join worker nodes (k3s-worker-01, 02, 03)
5. Configure kubectl
6. Label and taint nodes

Time: ~15-20 minutes

### 3.5 Fetch Kubeconfig

```bash
make ansible-kubeconfig
```

Kubeconfig saved to: `~/.kube/config-aiops-prod`

### 3.6 Verify Cluster

```bash
export KUBECONFIG=~/.kube/config-aiops-prod
kubectl get nodes -o wide
```

Expected output:
```
NAME            STATUS   ROLES                  AGE   VERSION
k3s-cp-01       Ready    control-plane,master   5m    v1.28.5+k3s1
k3s-cp-02       Ready    control-plane,master   4m    v1.28.5+k3s1
k3s-cp-03       Ready    control-plane,master   3m    v1.28.5+k3s1
k3s-worker-01   Ready    worker                 2m    v1.28.5+k3s1
k3s-worker-02   Ready    worker                 2m    v1.28.5+k3s1
k3s-worker-03   Ready    worker                 2m    v1.28.5+k3s1
```

---

## Phase 4: Deploy Applications

### 4.1 Deploy Core Services

```bash
make ansible-deploy-apps
```

This deploys:
- **Storage**: local-path provisioner
- **Vault**: Secrets management (namespace: vault)
- **Ollama**: LLM runtime (namespace: aiops)
- **MinIO**: S3-compatible storage (namespace: aiops)
- **AI Ops Agent**: FastAPI service (namespace: aiops)
- **Autoscaler**: VM autoscaling CronJob (namespace: autoscaler)

Time: ~10-15 minutes

### 4.2 Verify Application Status

```bash
kubectl get pods -A
```

Expected: All pods in `Running` status

### 4.3 Initialize Vault

If Vault is not initialized, the playbook will output initialization keys.

**IMPORTANT**: Save these keys securely!

```bash
# Unseal Vault (requires 3 of 5 keys)
kubectl exec -n vault vault-0 -- vault operator unseal <key-1>
kubectl exec -n vault vault-0 -- vault operator unseal <key-2>
kubectl exec -n vault vault-0 -- vault operator unseal <key-3>

# Login with root token
kubectl exec -n vault vault-0 -- vault login <root-token>
```

### 4.4 Verify Ollama Model

```bash
kubectl exec -n aiops deployment/ollama -- ollama list
```

Expected output:
```
NAME            SIZE
llama3.1:8b     4.7GB
```

### 4.5 Test AI Ops Agent

```bash
# Get worker node IP
WORKER_IP=$(kubectl get nodes -l node-role.kubernetes.io/worker=true -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# Test health endpoint
curl http://$WORKER_IP:30080/health
```

Expected:
```json
{"status":"healthy"}
```

### 4.6 Test Natural Language Request

```bash
curl -X POST http://$WORKER_IP:30080/api/v1/intent \
  -H "Content-Type: application/json" \
  -d '{"request": "Add DNS A record for test.local to 192.168.1.100"}'
```

Expected: JSON response with intent classification and Terraform/Ansible schema

---

## Phase 5: Deploy Autoscaler

### 5.1 Build Autoscaler Image

```bash
make autoscaler-build
```

### 5.2 Push to Registry (if using private registry)

```bash
REGISTRY=your-registry.com make autoscaler-push
```

### 5.3 Deploy Autoscaler

The autoscaler is already deployed by `ansible-deploy-apps`, but you can verify:

```bash
make autoscaler-status
```

### 5.4 Test Manual Scaling

```bash
# Trigger scale up
make vm-scale-up

# Check VM status
make vm-list

# Trigger scale down
make vm-scale-down
```

---

## Phase 6: Post-Deployment

### 6.1 Configure DNS

Update DNS to point to services:

```
aiops.corp.example.com  → Worker Node IP:30080
vault.corp.example.com  → Port-forward or Ingress
minio.corp.example.com  → Port-forward or Ingress
```

### 6.2 Configure Firewall

Open NodePort range on worker nodes:

```bash
# On each worker node
firewall-cmd --permanent --add-port=30000-32767/tcp
firewall-cmd --reload
```

### 6.3 Setup Monitoring (Optional)

Deploy Prometheus and Grafana:

```bash
kubectl apply -f cluster/monitoring/prometheus.yaml
kubectl apply -f cluster/monitoring/grafana.yaml
```

### 6.4 Setup Backups (Optional)

Deploy Velero for cluster backups:

```bash
kubectl apply -f cluster/backup/velero.yaml
```

---

## Troubleshooting

### k3s Nodes Not Ready

```bash
# Check k3s service status
make ansible-logs

# Restart k3s on control plane
ansible -i inventory/proxmox.yml control_plane -m systemd -a "name=k3s state=restarted"

# Restart k3s-agent on workers
ansible -i inventory/proxmox.yml workers -m systemd -a "name=k3s-agent state=restarted"
```

### HAProxy Not Responding

```bash
# Check HAProxy status
ansible -i inventory/proxmox.yml loadbalancers -m systemd -a "name=haproxy"

# Check Keepalived VIP
ansible -i inventory/proxmox.yml loadbalancers -m shell -a "ip addr show | grep 10.100.0.5"

# View HAProxy stats
curl http://10.100.0.6:8404/stats
```

### Pods Stuck in Pending

```bash
# Check node resources
kubectl describe nodes

# Check PVC status
kubectl get pvc -A

# Check storage provisioner
kubectl logs -n storage deployment/local-path-provisioner
```

### Autoscaler Not Scaling

```bash
# Check autoscaler logs
make autoscaler-logs

# Verify Proxmox credentials
kubectl get secret -n autoscaler proxmox-credentials -o yaml

# Manually trigger scaling test
make autoscaler-test
```

---

## Maintenance

### Upgrade k3s

```bash
# Set new version
export K3S_VERSION=v1.29.0+k3s1

# Upgrade cluster
make ansible-upgrade-k3s
```

### Drain Node for Maintenance

```bash
make ansible-drain-node
# Enter node name when prompted
```

### Uncordon Node After Maintenance

```bash
make ansible-uncordon-node
# Enter node name when prompted
```

### Backup Vault

```bash
kubectl exec -n vault vault-0 -- vault operator raft snapshot save /tmp/vault-backup.snap
kubectl cp vault/vault-0:/tmp/vault-backup.snap ./vault-backup-$(date +%Y%m%d).snap
```

---

## Access Information

### Services

| Service | URL | Credentials |
|---------|-----|-------------|
| AI Ops Agent | http://worker-ip:30080 | Bearer token from Vault |
| Vault | http://10.100.0.x:8200 | Root token from init |
| HAProxy Stats | http://10.100.0.6:8404/stats | admin / changeme |
| MinIO Console | Port-forward 9001 | admin / changeme123 |
| Kubernetes API | https://10.100.0.5:6443 | kubeconfig |

### Port Forwards

```bash
# Vault
kubectl port-forward -n vault svc/vault 8200:8200

# MinIO Console
kubectl port-forward -n aiops svc/minio 9001:9001

# Ollama
kubectl port-forward -n aiops svc/ollama 11434:11434
```

---

## Quick Reference

```bash
# Full deployment from scratch
make packer-build
make init-prod && make apply-prod
make ansible-deploy-k3s
make ansible-deploy-apps

# Verify deployment
make ansible-verify
kubectl get nodes
kubectl get pods -A

# Fetch kubeconfig
make ansible-kubeconfig
export KUBECONFIG=~/.kube/config-aiops-prod

# Test AI agent
curl http://<worker-ip>:30080/health
```

---

## Support

For issues or questions:
- Check logs: `make ansible-logs`
- Review Terraform state: `terraform state list`
- Verify Ansible inventory: `ansible-inventory -i inventory/proxmox.yml --list`
- Contact: youngs@suhlabs.com
