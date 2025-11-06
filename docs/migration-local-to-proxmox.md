# Migration Guide: Local → Proxmox Production

## Overview

This guide covers migrating the AIOps substrate from local development (kind/k3s on Docker Desktop) to production Proxmox cluster with HA k3s, Ceph storage, and GitOps.

---

## 1. Prerequisites Checklist

### Infrastructure

- [ ] Proxmox cluster with 3+ nodes running
- [ ] Ceph storage cluster configured and healthy (`ceph -s` shows HEALTH_OK)
- [ ] Network VLAN/subnet configured for k3s cluster
- [ ] DNS zone delegated or authoritative DNS server accessible
- [ ] NTP synchronized across all Proxmox nodes
- [ ] Proxmox API user created with required permissions (VM.Allocate, VM.Config, Datastore.Allocate)

### Local Environment

- [ ] Docker Desktop + WSL2 running
- [ ] Local kind/k3s cluster operational (`kubectl get nodes`)
- [ ] Terraform >= 1.6.0 installed (`terraform version`)
- [ ] Ansible >= 2.15.0 installed (`ansible --version`)
- [ ] kubectl + helm installed
- [ ] Vault CLI installed (`vault version`)
- [ ] cosign installed for artifact signing
- [ ] syft installed for SBOM generation

### Secrets & Access

- [ ] Proxmox API token/credentials stored in Vault
- [ ] SSH keys generated and added to Proxmox templates
- [ ] OIDC provider configured (or FreeIPA ready)
- [ ] Vault root/recovery tokens backed up
- [ ] Terraform state backend accessible (S3/Consul/Proxmox)

### Workloads & State

- [ ] Local AI agent workloads tested (`make test-ai`)
- [ ] Ollama models downloaded and verified
- [ ] Terraform state exported (`make export-state`)
- [ ] Application data backed up (MinIO buckets, Vault data)
- [ ] ConfigMaps/Secrets inventory documented
- [ ] Persistent volumes identified and sized

### Validation

```bash
# Run pre-migration checks
make preflight-local
make preflight-proxmox
```

---

## 2. Migration Steps

### Phase 1: Proxmox Infrastructure Provisioning

#### Step 1: Initialize Proxmox Terraform Backend

```bash
# Export Proxmox credentials
export PM_API_URL="https://proxmox.corp.example.com:8006/api2/json"
export PM_API_TOKEN_ID="terraform@pam!terraform"
export PM_API_TOKEN_SECRET="your-secret-token"

# Initialize Proxmox backend
make init-prod

# Verify backend configuration
cd infra/proxmox && terraform init -backend-config=backend.hcl
```

#### Step 2: Plan Infrastructure

```bash
# Generate execution plan
make plan-prod

# Review outputs
# - VM count, specs (CPU/RAM/disk)
# - Network configuration
# - Ceph pool allocation
# - Load balancer IPs
```

#### Step 3: Provision VMs

```bash
# Apply Terraform configuration
make apply-prod

# Expected resources:
# - 3x k3s control-plane VMs (4 vCPU, 8GB RAM, 50GB Ceph RBD)
# - 3x k3s worker VMs (8 vCPU, 16GB RAM, 100GB Ceph RBD)
# - 1x bastion/jump host VM (2 vCPU, 4GB RAM)
# - HAProxy/Keepalived for k3s API HA (optional)

# Capture Terraform outputs
terraform output -json > /tmp/proxmox-outputs.json
```

### Phase 2: Kubernetes Cluster Bootstrap

#### Step 4: Deploy k3s HA Cluster

```bash
# Run Ansible playbook for k3s installation
cd services/k3s
ansible-playbook -i ../../inventory/proxmox.yml playbook.yml \
  --extra-vars "cluster_token=$(vault kv get -field=token secret/k3s/cluster)"

# Verify cluster
export KUBECONFIG=/tmp/k3s-proxmox-kubeconfig.yaml
kubectl get nodes -o wide

# Expected output:
# NAME           STATUS   ROLES                  AGE   VERSION
# k3s-cp-01      Ready    control-plane,master   2m    v1.28.x
# k3s-cp-02      Ready    control-plane,master   2m    v1.28.x
# k3s-cp-03      Ready    control-plane,master   2m    v1.28.x
# k3s-worker-01  Ready    <none>                 1m    v1.28.x
# k3s-worker-02  Ready    <none>                 1m    v1.28.x
# k3s-worker-03  Ready    <none>                 1m    v1.28.x
```

#### Step 5: Configure Storage Classes

```bash
# Deploy Ceph CSI driver
kubectl apply -f cluster/storage/ceph-csi.yaml

# Verify storage class
kubectl get sc

# NAME              PROVISIONER                AGE   DEFAULT
# ceph-rbd          rbd.csi.ceph.com           30s   true
# ceph-rbd-retain   rbd.csi.ceph.com           30s   false
```

### Phase 3: Core Services Migration

#### Step 6: Deploy Vault to Production

```bash
# Deploy Vault with HA backend (Raft)
kubectl apply -f cluster/vault/

# Unseal Vault (repeat on all replicas)
vault operator unseal <key-1>
vault operator unseal <key-2>
vault operator unseal <key-3>

# Verify Vault status
kubectl exec -it vault-0 -- vault status

# Migrate secrets from local Vault
vault kv list -format=json secret/ | \
  jq -r '.[]' | \
  xargs -I {} sh -c 'vault kv get -format=json secret/{} | \
    vault kv put secret/{} -'
```

#### Step 7: Deploy GitOps (Argo CD)

```bash
# Install Argo CD
kubectl create namespace argocd
kubectl apply -n argocd -f cluster/argocd/install.yaml

# Wait for Argo CD to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Port-forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

#### Step 8: Configure GitOps Applications

```bash
# Apply application manifests
kubectl apply -f cluster/argocd/apps/

# Verify applications
argocd app list

# NAME              SYNC STATUS   HEALTH STATUS
# ai-ops-agent      Synced        Healthy
# ollama            Synced        Healthy
# minio             Synced        Healthy
# dns-manager       Synced        Healthy
```

### Phase 4: AI Agent Migration

#### Step 9: Migrate Ollama Models

```bash
# Export models from local
docker exec ollama ollama list
docker cp ollama:/root/.ollama/models /tmp/ollama-models

# Deploy Ollama to k3s
kubectl apply -f cluster/ollama/

# Wait for pod ready
kubectl wait --for=condition=ready pod -l app=ollama --timeout=300s

# Copy models to persistent volume
kubectl cp /tmp/ollama-models \
  $(kubectl get pod -l app=ollama -o jsonpath='{.items[0].metadata.name}'):/root/.ollama/

# Verify models
kubectl exec -it $(kubectl get pod -l app=ollama -o jsonpath='{.items[0].metadata.name}') \
  -- ollama list
```

#### Step 10: Deploy AI Agent

```bash
# Build and push container image
cd cluster/ai-ops-agent
docker build -t registry.corp.example.com/aiops-agent:v1.0.0 .
docker push registry.corp.example.com/aiops-agent:v1.0.0

# Sign container image
cosign sign --key cosign.key \
  registry.corp.example.com/aiops-agent:v1.0.0

# Generate SBOM
syft registry.corp.example.com/aiops-agent:v1.0.0 \
  -o spdx-json > ai-ops-agent-sbom.spdx.json

# Deploy via Argo CD
kubectl apply -f cluster/argocd/apps/ai-ops-agent.yaml

# Verify deployment
kubectl get pods -l app=ai-ops-agent
kubectl logs -l app=ai-ops-agent --tail=50
```

### Phase 5: Supporting Services

#### Step 11: Deploy DNS/Samba/FreeIPA

```bash
# Run Ansible playbooks
cd services/dns
ansible-playbook -i ../../inventory/proxmox.yml playbook.yml

cd ../samba
ansible-playbook -i ../../inventory/proxmox.yml playbook.yml

cd ../freeipa
ansible-playbook -i ../../inventory/proxmox.yml playbook.yml

# Verify services
make test-dns
make test-samba
make test-freeipa
```

#### Step 12: Configure OIDC Integration

```bash
# Configure Vault OIDC
vault write auth/oidc/config \
  oidc_discovery_url="https://ipa.corp.example.com/ipa" \
  oidc_client_id="vault" \
  oidc_client_secret="$IPA_CLIENT_SECRET" \
  default_role="developer"

# Create OIDC role
vault write auth/oidc/role/developer \
  bound_audiences="vault" \
  allowed_redirect_uris="https://vault.corp.example.com/ui/vault/auth/oidc/oidc/callback" \
  user_claim="sub" \
  policies="developer"

# Test OIDC login
vault login -method=oidc role=developer
```

### Phase 6: State Migration & Cutover

#### Step 13: Migrate Terraform State

```bash
# Export local state
cd infra/local
terraform state pull > /tmp/local-state.json

# Initialize remote backend
cd ../proxmox
terraform init -backend-config=backend.hcl

# Import existing resources (if needed)
# terraform import proxmox_vm_qemu.k3s_cp[0] 100
# terraform import proxmox_vm_qemu.k3s_cp[1] 101
# ...

# Validate state
terraform plan
# Should show: No changes. Your infrastructure matches the configuration.
```

#### Step 14: Update DNS Records

```bash
# Update production DNS entries
cd services/dns
ansible-playbook -i ../../inventory/proxmox.yml update-dns.yml \
  --extra-vars "zone=corp.example.com" \
  --extra-vars "records_file=../../config/prod-dns-records.json"

# Verify resolution
dig @ns.corp.example.com aiops.corp.example.com +short
dig @ns.corp.example.com vault.corp.example.com +short
```

#### Step 15: Final Validation

```bash
# Run comprehensive tests
make test-prod
make test-ai
make test-dns
make test-vault

# Verify AI agent endpoint
curl -H "Authorization: Bearer $VAULT_TOKEN" \
  https://aiops.corp.example.com/api/v1/intent \
  -d '{"request": "Add DNS A record for test.local to 192.168.1.100"}'

# Expected response:
# {
#   "intent": "create_dns_record",
#   "schema": {...},
#   "status": "success",
#   "signature": "cosign://..."
# }
```

---

## 3. Validation Scripts (Make Targets)

Add to `Makefile`:

```makefile
# Pre-migration checks
.PHONY: preflight-local
preflight-local:
	@echo "==> Running local preflight checks..."
	@docker version >/dev/null 2>&1 || (echo "ERROR: Docker not running" && exit 1)
	@kubectl cluster-info >/dev/null 2>&1 || (echo "ERROR: kubectl not configured" && exit 1)
	@terraform version | grep -q "v1\.[6-9]" || (echo "ERROR: Terraform >= 1.6 required" && exit 1)
	@vault status >/dev/null 2>&1 || (echo "ERROR: Vault not accessible" && exit 1)
	@make test-local
	@echo "✓ Local environment ready for migration"

.PHONY: preflight-proxmox
preflight-proxmox:
	@echo "==> Running Proxmox preflight checks..."
	@curl -k -s "$$PM_API_URL" >/dev/null || (echo "ERROR: Proxmox API unreachable" && exit 1)
	@ssh -q proxmox-01 "pvesh get /cluster/status" || (echo "ERROR: SSH access failed" && exit 1)
	@ssh -q proxmox-01 "ceph -s | grep -q HEALTH_OK" || (echo "ERROR: Ceph not healthy" && exit 1)
	@echo "✓ Proxmox cluster ready for migration"

# Post-migration validation
.PHONY: test-prod
test-prod:
	@echo "==> Testing production cluster..."
	@kubectl get nodes | grep -q "Ready" || (echo "ERROR: Nodes not ready" && exit 1)
	@kubectl get pods -A | grep -qv "Error\|CrashLoop" || (echo "ERROR: Pods failing" && exit 1)
	@kubectl get pvc -A | grep -q "Bound" || (echo "WARN: PVCs not bound")
	@echo "✓ Kubernetes cluster healthy"

.PHONY: test-ai
test-ai:
	@echo "==> Testing AI agent..."
	@export POD=$$(kubectl get pod -l app=ai-ops-agent -o jsonpath='{.items[0].metadata.name}'); \
	kubectl exec -it $$POD -- curl -s http://localhost:8000/health | grep -q "ok" || (echo "ERROR: AI agent unhealthy" && exit 1)
	@curl -k -H "Authorization: Bearer $$VAULT_TOKEN" \
		https://aiops.corp.example.com/api/v1/intent \
		-d '{"request": "ping"}' | grep -q "pong" || (echo "ERROR: AI endpoint failed" && exit 1)
	@echo "✓ AI agent operational"

.PHONY: test-dns
test-dns:
	@echo "==> Testing DNS resolution..."
	@dig @ns.corp.example.com aiops.corp.example.com +short | grep -q "[0-9]" || (echo "ERROR: DNS not resolving" && exit 1)
	@echo "✓ DNS functional"

.PHONY: test-vault
test-vault:
	@echo "==> Testing Vault..."
	@kubectl exec -it vault-0 -- vault status | grep -q "Sealed.*false" || (echo "ERROR: Vault sealed" && exit 1)
	@vault kv get secret/k3s/cluster >/dev/null || (echo "ERROR: Cannot read secrets" && exit 1)
	@echo "✓ Vault operational"

.PHONY: test-gitops
test-gitops:
	@echo "==> Testing Argo CD..."
	@argocd app list | grep -q "Synced.*Healthy" || (echo "ERROR: Apps not synced" && exit 1)
	@echo "✓ GitOps operational"

.PHONY: export-state
export-state:
	@echo "==> Exporting Terraform state..."
	@cd infra/local && terraform state pull > /tmp/aiops-local-state-$$(date +%Y%m%d-%H%M%S).json
	@echo "✓ State exported to /tmp/"

.PHONY: backup-vault
backup-vault:
	@echo "==> Backing up Vault data..."
	@kubectl exec -it vault-0 -- vault operator raft snapshot save /tmp/vault-snapshot.snap
	@kubectl cp vault-0:/tmp/vault-snapshot.snap /tmp/vault-backup-$$(date +%Y%m%d-%H%M%S).snap
	@echo "✓ Vault backup saved to /tmp/"
```

---

## 4. Rollback Plan

### Scenario A: Infrastructure Provisioning Failure (Phase 1-2)

**Symptoms**: Terraform apply fails, VMs not created, network issues

**Rollback Steps**:

```bash
# 1. Destroy partial infrastructure
cd infra/proxmox
terraform destroy -auto-approve

# 2. Clean up orphaned resources
ssh proxmox-01 "qm list | grep k3s | awk '{print \$1}' | xargs -I {} qm destroy {}"

# 3. Verify cleanup
ssh proxmox-01 "qm list | grep -q k3s && echo 'CLEANUP INCOMPLETE' || echo 'CLEANUP OK'"

# 4. Continue using local environment
export KUBECONFIG=~/.kube/config-kind-aiops-dev
kubectl config use-context kind-aiops-dev
```

**Impact**: None - still running on local

**RTO**: < 10 minutes

---

### Scenario B: Core Services Migration Failure (Phase 3)

**Symptoms**: Vault unsealed failed, Argo CD not syncing, secrets inaccessible

**Rollback Steps**:

```bash
# 1. Stop Argo CD from syncing
kubectl patch app -n argocd ai-ops-agent -p '{"spec":{"syncPolicy":null}}' --type=merge

# 2. Restore Vault snapshot
kubectl cp /tmp/vault-backup-YYYYMMDD.snap vault-0:/tmp/restore.snap
kubectl exec -it vault-0 -- vault operator raft snapshot restore /tmp/restore.snap

# 3. Verify Vault data
vault kv list secret/

# 4. If unrecoverable, redirect to local Vault
export VAULT_ADDR=http://localhost:8200
vault status
```

**Impact**: Production Vault unavailable, use local Vault temporarily

**RTO**: < 30 minutes

---

### Scenario C: AI Agent Failure (Phase 4)

**Symptoms**: AI agent pods CrashLooping, Ollama models missing, API 5xx errors

**Rollback Steps**:

```bash
# 1. Scale down AI agent
kubectl scale deployment ai-ops-agent --replicas=0

# 2. Verify Ollama pod
kubectl logs -l app=ollama --tail=100
kubectl exec -it $(kubectl get pod -l app=ollama -o jsonpath='{.items[0].metadata.name}') -- ollama list

# 3. Re-copy models if missing
kubectl cp /tmp/ollama-models $(kubectl get pod -l app=ollama -o jsonpath='{.items[0].metadata.name}'):/root/.ollama/

# 4. Restart AI agent with previous image version
kubectl set image deployment/ai-ops-agent \
  ai-ops-agent=registry.corp.example.com/aiops-agent:v0.9.0

# 5. Redirect traffic to local AI agent
export AI_AGENT_URL=http://localhost:30080
```

**Impact**: Production AI agent down, use local instance

**RTO**: < 15 minutes

---

### Scenario D: Complete Migration Failure (Post-Phase 6)

**Symptoms**: Multiple services down, data loss, cluster unreachable

**Rollback Steps**:

```bash
# 1. Update DNS to point back to local
cd services/dns
ansible-playbook -i ../../inventory/local.yml rollback-dns.yml

# 2. Restore local kubeconfig
export KUBECONFIG=~/.kube/config-kind-aiops-dev
kubectl config use-context kind-aiops-dev

# 3. Restart local stack
make dev-down
make dev-up
make kind-up

# 4. Restore Vault data
docker cp /tmp/vault-backup-YYYYMMDD.snap vault:/tmp/restore.snap
docker exec vault vault operator raft snapshot restore /tmp/restore.snap

# 5. Verify local services
make test-local
make test-ai

# 6. Update configuration to use local endpoints
sed -i 's/aiops.corp.example.com/localhost:30080/g' config/*.yaml

# 7. Notify users of rollback
echo "ALERT: Rolled back to local environment. Proxmox migration aborted." | \
  mail -s "AIOps Migration Rollback" ops@example.com
```

**Impact**: Full rollback to local environment

**RTO**: < 60 minutes

---

### Rollback Testing

```bash
# Test rollback procedures quarterly
make test-rollback-scenario-a
make test-rollback-scenario-b
make test-rollback-scenario-c
make test-rollback-scenario-d
```

---

## 5. Risk Table

| Risk | Likelihood | Impact | Mitigation | Owner |
|------|-----------|--------|------------|-------|
| **Ceph storage full during migration** | Medium | High | Monitor Ceph usage (`ceph df`), allocate 2x required space, enable Ceph alerts | Infra Team |
| **k3s cluster split-brain** | Low | Critical | Use odd number of control-plane nodes (3+), monitor etcd health, configure anti-affinity | Infra Team |
| **Vault seal keys lost** | Low | Critical | Backup seal keys to multiple secure locations (KMS, offline), use Shamir secret sharing | Security Team |
| **Ollama model corruption** | Medium | Medium | Checksum validation before/after transfer, keep source models backed up, use immutable storage | AI Team |
| **Network segmentation breaks DNS** | Medium | High | Test DNS resolution from all VLANs, configure forwarders, maintain local DNS cache | Network Team |
| **Terraform state corruption** | Low | Critical | Enable state locking, use remote backend with versioning, daily state backups | Infra Team |
| **GitOps sync loop** | Medium | Medium | Implement sync waves, use health checks, configure retry backoff, monitor Argo CD metrics | DevOps Team |
| **OIDC auth failure** | Medium | High | Maintain emergency break-glass account, test OIDC before cutover, have local auth fallback | Security Team |
| **Certificate expiration** | Low | Medium | Use cert-manager with auto-renewal, monitor cert expiry (Prometheus alerts), 30-day renewal buffer | Security Team |
| **Data loss during state migration** | Low | Critical | Export state before migration, validate checksums, test restore procedure, use append-only logs | Infra Team |
| **Proxmox node failure during migration** | Low | High | Use HA-enabled VMs, test node evacuation, maintain quorum (3+ nodes), enable fencing | Infra Team |
| **API rate limits exhausted** | Medium | Low | Implement exponential backoff, use batching, monitor API usage, request limit increase | DevOps Team |
| **Ansible playbook partial failure** | Medium | Medium | Use idempotent tasks, implement check mode, tag critical tasks, enable verbose logging | Infra Team |
| **Container registry unavailable** | Low | High | Use local Harbor/registry mirror, pre-pull critical images, configure image pull retries | DevOps Team |
| **Time drift causes auth failures** | Low | Medium | Configure NTP on all nodes, monitor time skew, use chrony with multiple sources | Infra Team |

### Risk Severity Matrix

```
       Impact
       Low    Medium   High    Critical
     ┌──────┬────────┬───────┬─────────┐
 Low │ ✓    │   ⚠    │  ⚠    │   ⚠     │
     ├──────┼────────┼───────┼─────────┤
Med  │ ✓    │   ⚠    │  ⚠    │   🔴    │
     ├──────┼────────┼───────┼─────────┤
High │ ⚠    │   ⚠    │  🔴   │   🔴    │
     └──────┴────────┴───────┴─────────┘

✓  = Accept    ⚠  = Monitor    🔴 = Mitigate
```

---

## 6. Post-Migration Checklist

- [ ] All pods running and healthy (`kubectl get pods -A`)
- [ ] PVCs bound to Ceph storage (`kubectl get pvc -A`)
- [ ] Vault unsealed and accessible
- [ ] Argo CD syncing applications
- [ ] AI agent responding to API requests
- [ ] Ollama models loaded and functional
- [ ] DNS resolving production FQDNs
- [ ] OIDC authentication working
- [ ] Certificates valid and auto-renewing
- [ ] Monitoring dashboards operational (Prometheus/Grafana)
- [ ] Backup jobs scheduled (Velero)
- [ ] Alerts configured and firing test alerts
- [ ] Documentation updated with production endpoints
- [ ] Local environment decommissioned or archived

---

## 7. Support & Escalation

| Issue Type | Contact | SLA |
|-----------|---------|-----|
| Infrastructure (Proxmox/Ceph) | infra@example.com | 1 hour |
| Kubernetes/GitOps | devops@example.com | 2 hours |
| Security/Vault/OIDC | security@example.com | 1 hour |
| AI Agent/Ollama | ai-team@example.com | 4 hours |
| DNS/Network | network@example.com | 2 hours |

**Emergency Hotline**: +1-555-0199 (24/7)

---

## 8. References

- [Proxmox API Documentation](https://pve.proxmox.com/pve-docs/api-viewer/)
- [k3s HA Installation](https://docs.k3s.io/installation/ha-embedded)
- [Argo CD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [Vault Production Hardening](https://developer.hashicorp.com/vault/tutorials/operations/production-hardening)
- [Ceph Operations Manual](https://docs.ceph.com/en/latest/rados/operations/)

---

**Document Version**: 1.0.0
**Last Updated**: 2025-11-06
**Next Review**: 2025-12-06
**Owner**: Infrastructure Team
