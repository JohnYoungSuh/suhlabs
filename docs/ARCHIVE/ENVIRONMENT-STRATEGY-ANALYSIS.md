# Environment Strategy Analysis - DevSecOps Best Practices

**Date**: 2025-11-27
**Context**: Dev box restarts frequently, Vault unsealing confusion between validation and POC environments
**Constraint**: Cannot keep dev box running 24/7

---

## Current State Gap Analysis

### What We Have Today

```
┌─────────────────────────────────────────────────────────────┐
│ Dev Box (Laptop/Workstation - Intermittent Uptime)         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Path 1: Validation (Temporary)                       │  │
│  │ - Cluster: kind-aiops-validation                     │  │
│  │ - Created by: autonomous-validation.sh               │  │
│  │ - Lifespan: ~1 hour (during test run)                │  │
│  │ - Vault: Fresh, auto-unsealed during test            │  │
│  │ - Purpose: Prove autonomous rebuild capability       │  │
│  │ - State: Destroyed after each test                   │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Path 2: POC/Development (Persistent)                 │  │
│  │ - Cluster: kind-aiops-dev                            │  │
│  │ - Created by: make kind-up                           │  │
│  │ - Lifespan: Weeks (persistent development)           │  │
│  │ - Vault: SEALED on every restart ❌                  │  │
│  │ - Purpose: Production-ready staging                  │  │
│  │ - State: Persisted (but Vault state lost)            │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Critical Gaps Identified

| Gap | Impact | Current State | Desired State |
|-----|--------|---------------|---------------|
| **G1: Environment Confusion** | High - Wasted debugging time | No clear naming/tagging | Explicit env markers |
| **G2: Vault Seal on Restart** | High - Manual intervention required | Sealed every restart | Auto-unseal working |
| **G3: Stateful Service Persistence** | Medium - Lost work on restart | Vault keys in file, not K8s | Kubernetes-native secrets |
| **G4: Uptime Dependency** | High - Can't shut down dev box | Requires always-on dev box | Option for always-on cluster |
| **G5: Validation vs POC Isolation** | Medium - Namespace collision risk | Same naming patterns | Clear separation |

---

## Root Cause Analysis

### Why Vault Unsealing is Confusing

**Problem Statement:**
"Is the validation Vault sealed or the POC Vault sealed?"

**Root Causes:**
1. **No visual/namespace distinction**: Both use `vault` namespace, `vault-0` pod name
2. **Context switching**: `kubectl config current-context` not checked proactively
3. **Assumption mismatch**: User assumes validation env, AI assumes POC env
4. **No environment labels**: Pods/resources don't have `env=poc` or `env=validation` labels

**Incident Example (Today):**
```
User: "Is my Vault working?"
AI: Checks POC Vault → "Sealed, not working"
User: "I thought you were checking validation Vault"
→ 15 minutes wasted clarifying which environment
```

### Why Dev Box Restart Breaks POC

**Problem Statement:**
Vault sealed on every restart, requires manual unseal

**Root Causes:**
1. **Auto-unseal not deployed**: ConfigMap exists but not applied to StatefulSet
2. **Kind cluster ephemeral**: Docker restart → Kubernetes state reset
3. **Vault design**: Starts sealed by default (correct security behavior)
4. **No runbook**: Manual unseal process not documented/automated

---

## Top 3 Options (DevSecOps Best Practices)

### Option 1: Multi-Environment Kind with Clear Tagging (Quick Win)

**Strategy**: Keep current setup but add explicit environment tagging

#### Implementation

```bash
# POC Environment (always running on dev box)
make kind-up
kubectl label nodes --all env=poc
kubectl label namespace vault env=poc
kubectl annotate namespace vault description="POC environment - production-ready staging"

# Auto-unseal deployment
cd cluster/foundation/vault
./setup-auto-unseal.sh  # Deploy auto-unseal sidecar

# Validation Environment (on-demand)
./scripts/autonomous-validation.sh
# Already creates separate cluster (kind-aiops-validation)
```

#### Environment Markers

```yaml
# All POC resources get labels:
metadata:
  labels:
    env: poc
    tier: staging
    managed-by: human

# All validation resources get labels:
metadata:
  labels:
    env: validation
    tier: test
    managed-by: ai-agent
    ephemeral: "true"
```

#### Pros
- ✅ Zero cost (uses existing hardware)
- ✅ Quick to implement (1-2 hours)
- ✅ Clear environment distinction
- ✅ Auto-unseal solves restart problem
- ✅ No new infrastructure needed

#### Cons
- ❌ Still requires dev box to be on for POC
- ❌ Kind performance limits (not true multi-node)
- ❌ Dev box restart still requires waiting for cluster/Vault startup

#### Cost
- **Money**: $0
- **Time**: 1-2 hours setup
- **Ongoing**: 2-5 min manual intervention per dev box restart

#### Validation Criteria
```bash
# Test 1: Environment clarity
kubectl config current-context
# Output should clearly show: kind-aiops-dev-poc or kind-aiops-validation

# Test 2: Auto-unseal works
sudo reboot
# After reboot:
kubectl exec -n vault vault-0 -- vault status
# Should show: Sealed: false (within 30 seconds)

# Test 3: No namespace collision
kubectl get ns --show-labels | grep env=
# Should clearly separate poc vs validation
```

---

### Option 2: Proxmox VM Cluster (Always-On Development)

**Strategy**: Deploy persistent K3s cluster on Proxmox VMs

#### Implementation

```bash
# Use existing Terraform code
cd infra/proxmox
terraform init
terraform apply -var="env=poc"

# Deploy foundation services
ansible-playbook -i inventory/poc.ini playbooks/k3s-deploy.yml
ansible-playbook -i inventory/poc.ini playbooks/vault-deploy.yml

# Auto-unseal with YubiHSM 2 or cloud KMS (production-grade)
```

#### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Proxmox Host (Always On)                                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ VM: k3s-cp   │  │ VM: k3s-w1   │  │ VM: k3s-w2   │     │
│  │ 4 vCPU       │  │ 2 vCPU       │  │ 2 vCPU       │     │
│  │ 8GB RAM      │  │ 4GB RAM      │  │ 4GB RAM      │     │
│  │              │  │              │  │              │     │
│  │ Vault (HA)   │  │ Ollama       │  │ AI Agent     │     │
│  │ CoreDNS      │  │ Qdrant       │  │              │     │
│  │ cert-manager │  │              │  │              │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│                                                             │
│  Labels: env=poc, tier=staging, persistent=true            │
│                                                             │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ Dev Box (Intermittent)                                      │
├─────────────────────────────────────────────────────────────┤
│  Kind cluster: aiops-validation (on-demand testing only)    │
│  kubectl context: points to Proxmox cluster by default      │
└─────────────────────────────────────────────────────────────┘
```

#### Pros
- ✅ Always-on POC environment (no restart issues)
- ✅ True multi-node Kubernetes (production-like)
- ✅ Can use YubiHSM 2 for real HSM auto-unseal
- ✅ Persistent storage (no state loss)
- ✅ Dev box can be turned off without affecting POC
- ✅ Better interview story (real cluster, not Kind)

#### Cons
- ❌ Hardware must stay on 24/7 (electricity cost)
- ❌ Proxmox setup complexity (1-2 days initial setup)
- ❌ Requires dedicated hardware or server

#### Cost
- **Money**:
  - Hardware: $0 (assuming Proxmox already available)
  - Electricity: ~$5-10/month (3 VMs, low power)
  - YubiHSM 2 (optional): $650 one-time (production-grade HSM)

- **Time**:
  - Initial setup: 1-2 days
  - Ongoing: ~0 (fully automated)

- **Hardware Requirements**:
  - Proxmox host with 16GB+ RAM, 100GB+ storage
  - Or rent dedicated server (~$30-50/month)

#### Validation Criteria
```bash
# Test 1: Uptime independence
# Shut down dev box, Proxmox cluster stays up
ssh proxmox-host
kubectl get pods -A
# All pods running

# Test 2: Auto-unseal with YubiHSM
systemctl restart vault
# Vault auto-unseals via YubiHSM (no manual intervention)

# Test 3: Multi-node workload
kubectl get nodes
# 3 nodes, all Ready

# Test 4: Persistent storage
kubectl exec vault-0 -- vault kv get secret/test
# Data persists across reboots
```

---

### Option 3: Hybrid - Proxmox POC + Kind Validation (Best of Both Worlds)

**Strategy**: POC on always-on Proxmox, validation on dev box Kind

#### Implementation

```bash
# POC Environment (Proxmox - Always On)
cd infra/proxmox
terraform apply -var="env=poc"
kubectl config rename-context admin@k3s aiops-poc

# Validation Environment (Kind - On Demand)
kind create cluster --name aiops-validation
kubectl config rename-context kind-aiops-validation aiops-validation

# Set default to POC
kubectl config use-context aiops-poc

# Switch to validation when needed
kubectl config use-context aiops-validation
./scripts/autonomous-validation.sh
```

#### Environment Matrix

| Environment | Cluster | Uptime | Purpose | Vault Unseal | State Persistence |
|-------------|---------|--------|---------|--------------|-------------------|
| **POC** | Proxmox K3s | 24/7 | Development, demos, testing | Auto (YubiHSM/KMS) | Full |
| **Validation** | Kind | On-demand (1h) | Autonomous testing | Auto (during test) | Ephemeral |
| **Production** | K3s/K8s | 24/7 | Real workload | Auto (YubiHSM 2) | Full |

#### Context Switching Workflow

```bash
# Always verify context before commands
alias kctx='kubectl config current-context'
alias kpoc='kubectl config use-context aiops-poc'
alias kval='kubectl config use-context aiops-validation'

# Add to PS1 prompt (show current context)
PS1='[\u@\h \W (⎈ $(kubectl config current-context))]\$ '

# Example:
[user@host ~ (⎈ aiops-poc)]$ kubectl get pods -n vault
# Clear which environment you're in
```

#### Pros
- ✅ POC always available (Proxmox)
- ✅ Validation ephemeral (Kind, no persistence needed)
- ✅ Clear separation of concerns
- ✅ Dev box can be off without affecting POC
- ✅ Low cost (single Proxmox server)
- ✅ Production-like POC environment

#### Cons
- ❌ Proxmox hardware must stay on
- ❌ Slightly more complex (two cluster types)
- ❌ Context switching requires discipline

#### Cost
- **Money**: ~$5-10/month electricity (Proxmox)
- **Time**: 2-3 days initial setup, then ~0
- **Hardware**: Existing Proxmox or $30-50/month dedicated server

#### Validation Criteria
```bash
# Test 1: Clear context awareness
kctx
# Output: aiops-poc (default)

# Test 2: POC survives dev box shutdown
# Shut down dev box
ssh proxmox-host
kubectl get pods -A
# POC still running

# Test 3: Validation isolated
kval
kind get clusters
# Shows: aiops-validation

kubectl get ns --show-labels
# All namespaces labeled: env=validation, ephemeral=true

# Test 4: No cross-contamination
kpoc
kubectl get ns | grep validation
# Empty (validation on different cluster)
```

---

## Comparison Matrix

| Criteria | Option 1: Tagged Kind | Option 2: Proxmox Only | Option 3: Hybrid | Weight |
|----------|----------------------|------------------------|------------------|--------|
| **Cost (Money)** | $0 | $5-10/mo | $5-10/mo | 20% |
| **Setup Time** | 1-2 hours | 1-2 days | 2-3 days | 15% |
| **Clarity** | Medium | High | Very High | 25% |
| **POC Availability** | Low (dev box on) | High (24/7) | High (24/7) | 20% |
| **Production-Like** | Low (Kind) | High (K3s) | High (K3s) | 10% |
| **Validation Isolation** | Medium | Low | High | 10% |
| **Interview Value** | Medium | High | High | 10% |
| **Total Score** | 5.8/10 | 7.8/10 | **8.6/10** | - |

---

## Recommendation: Option 3 (Hybrid)

### Why Hybrid is Best

1. **Clear Separation**: POC (Proxmox) and Validation (Kind) are physically separate clusters
2. **Cost-Effective**: Single Proxmox server vs. cloud ($273/month AWS)
3. **Interview Story**: "I run POC on always-on K3s cluster, validation on ephemeral Kind"
4. **DevSecOps Best Practice**: Matches real production pattern (persistent + ephemeral)
5. **Solves Your Problem**: No confusion (different cluster names), no Vault seal issues (POC auto-unseals)

### Implementation Roadmap

#### Phase 1: POC on Proxmox (Week 1)
```bash
Day 1-2: Terraform Proxmox VMs
Day 3: Ansible K3s deployment
Day 4: Vault + auto-unseal (SoftHSM or YubiHSM)
Day 5: Cert-manager + CoreDNS
Day 6-7: AI Ops agent + Ollama
```

#### Phase 2: Environment Tagging (Week 1)
```bash
# Add labels to all resources
kubectl label namespace vault env=poc tier=staging
kubectl label namespace default env=poc tier=staging

# Update Kind validation to use different naming
# autonomous-validation.sh already does this (kind-aiops-validation)
```

#### Phase 3: Context Management (Week 1)
```bash
# Rename contexts for clarity
kubectl config rename-context admin@k3s aiops-poc
kubectl config rename-context kind-aiops-validation aiops-validation

# Set default
kubectl config use-context aiops-poc

# Add aliases to .bashrc
echo 'alias kctx="kubectl config current-context"' >> ~/.bashrc
echo 'alias kpoc="kubectl config use-context aiops-poc"' >> ~/.bashrc
echo 'alias kval="kubectl config use-context aiops-validation"' >> ~/.bashrc
```

#### Phase 4: Auto-Unseal (Week 2)
```bash
# POC environment (Proxmox)
cd cluster/foundation/vault
./setup-auto-unseal.sh

# Validation environment (already handled by autonomous-validation.sh)
# No action needed
```

#### Phase 5: Documentation (Week 2)
```bash
# Create runbooks
docs/runbooks/
├── POC-ENVIRONMENT.md          # How to access/manage POC
├── VALIDATION-ENVIRONMENT.md   # How to run validation tests
├── VAULT-UNSEAL-POC.md         # Auto-unseal troubleshooting
└── CONTEXT-SWITCHING.md        # How to switch between envs
```

---

## Alternative: Quick Win Today (1 Hour)

If you can't deploy Proxmox immediately, do this NOW:

### Immediate Actions (Option 1+)

```bash
# 1. Deploy auto-unseal to POC (15 min)
cd cluster/foundation/vault
kubectl apply -f auto-unseal-sidecar.yaml
./save-keys-to-k8s.sh
# Manually patch StatefulSet or redeploy

# 2. Rename contexts for clarity (5 min)
kubectl config rename-context kind-aiops-dev aiops-poc-kind
# Now you always know you're in POC

# 3. Add env labels (10 min)
kubectl label namespace vault env=poc tier=staging
kubectl label namespace default env=poc tier=staging
kubectl label nodes --all env=poc

# 4. Update PS1 prompt (5 min)
echo 'export PS1="[\u@\h \W (⎈ \$(kubectl config current-context))]\$ "' >> ~/.bashrc
source ~/.bashrc
# Now your prompt shows: [user@host ~ (⎈ aiops-poc-kind)]$

# 5. Test auto-unseal (30 min)
kubectl delete pod vault-0 -n vault
# Wait for restart, verify auto-unseal works
kubectl exec -n vault vault-0 -- vault status
# Should show: Sealed: false
```

**Result**: You'll have clarity on which environment + auto-unseal working in 1 hour.

**Then plan**: Proxmox migration over next 2 weeks when time allows.

---

## Validation Criteria for Success

### Environment Clarity Test
```bash
# PASS: Can immediately tell which environment you're in
kubectl config current-context
# Output: aiops-poc (not kind-aiops-dev)

# PASS: Labels make it obvious
kubectl get ns vault -o jsonpath='{.metadata.labels}'
# Output: {"env":"poc","tier":"staging"}
```

### Auto-Unseal Test
```bash
# PASS: Vault auto-unseals after restart
kubectl delete pod vault-0 -n vault
sleep 60
kubectl exec -n vault vault-0 -- vault status | grep Sealed
# Output: Sealed   false
```

### Isolation Test
```bash
# PASS: Validation creates separate cluster
./scripts/autonomous-validation.sh
kind get clusters
# Output: aiops-validation (NOT aiops-poc)

# PASS: No namespace collision
kubectl config use-context aiops-poc
kubectl get ns | grep validation
# Output: (empty)
```

### Uptime Test
```bash
# PASS: POC survives dev box shutdown (Proxmox only)
ssh proxmox-host
systemctl reboot
# After reboot:
kubectl get pods -A
# All pods Running, Vault unsealed
```

---

## Decision Matrix for Your Situation

### If You Have Proxmox Available
→ **Choose Option 3 (Hybrid)**
- Start with Proxmox POC (Week 1-2)
- Keep Kind for validation (already working)
- Best long-term solution

### If No Proxmox (Yet)
→ **Choose Option 1+ (Quick Win Today)**
- Deploy auto-unseal immediately
- Add environment tagging
- Plan Proxmox migration later

### If Budget for Dedicated Server
→ **Choose Option 2 or 3**
- Rent Hetzner/OVH dedicated server ($30-50/month)
- Deploy Proxmox + K3s
- Production-grade setup

---

## Interview Talking Points (Based on Chosen Option)

### If You Choose Option 3 (Recommended)

**Interviewer**: "How do you manage multiple environments?"

**You**:
"I run a hybrid setup: POC environment on always-on Proxmox K3s cluster with YubiHSM auto-unseal, and ephemeral validation environment on Kind for autonomous testing. This mirrors production patterns - persistent staging environment plus on-demand test environments. I use Kubernetes context naming (aiops-poc vs aiops-validation) and resource labels (env=poc, env=validation) to avoid confusion. When I ran into Vault seal issues after dev box restarts, I implemented auto-unseal with ConfigMap-backed persistence and environment-specific namespacing to prevent cross-contamination."

**Impact**: Shows you understand:
- Multi-environment management
- Production-like patterns
- Operational troubleshooting
- Infrastructure design trade-offs

---

## Next Steps

1. **Decide**: Which option fits your hardware/budget/timeline?
2. **Quick win**: Deploy auto-unseal + tagging today (1 hour)
3. **Long-term**: Plan Proxmox migration if choosing Option 2/3
4. **Document**: Update README with environment strategy
5. **Validate**: Run all validation tests above

Want me to help you implement the quick win (Option 1+) right now?
