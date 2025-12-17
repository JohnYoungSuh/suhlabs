# 14-Day Balanced Sprint Plan
**Learning-Focused with Production Foundations**

---

## Philosophy: Learn by Building, Build It Right

### The Balance

**Learning-First** (14-Day Sprint Original):
- Simple → Complex progression
- Get things working quickly
- Learn concepts incrementally
- **Problem**: Technical debt (reconfigure certs later)

**Production-First** (Architecture-Driven):
- Foundation → Services
- Security from day 1
- No rework needed
- **Problem**: Overwhelming complexity upfront

**Balanced Approach** (This Plan):
- ✅ Learn incrementally (keep educational value)
- ✅ Add foundational services early (DNS/PKI on Day 4)
- ✅ Use "good enough" foundations (not full production)
- ✅ Avoid major rework (certs work from day 5 onward)
- ✅ Upgrade foundations incrementally (SoftHSM → YubiHSM later)

---

## The Key Change: Day 4 Becomes "Foundation Day"

### Original Day 4: Ansible Basics
```
Problem: No DNS, no PKI yet
Result: Self-signed certs, frustration, rework later
```

### Balanced Day 4: Foundation Services + Ansible
```
Goal: Minimal DNS + PKI that "just works"
Tools: Simple CoreDNS + SoftHSM + Vault PKI
Time: Same 8 hours, but split:
  - 3h: Deploy CoreDNS (cluster DNS)
  - 3h: Deploy Vault PKI with SoftHSM (dev mode)
  - 2h: Ansible basics (still learn Ansible, but less depth)
Result: Real certificates from Day 5 onward
```

---

## Week 1: Foundation + First Blood (Days 1-7)

### Day 1: Terminal Mastery + Local K8s
**Status**: ✅ From original plan, no changes needed
**Goal**: Muscle memory for tmux + deploy first K8s app

**Keep Everything From Original:**
- Terminal setup (tmux, vim)
- Kind cluster deployment
- First nginx deployment
- Lab: Break & rebuild cluster 3x

**Why No Change**: This is perfect as-is for learning K8s basics.

---

### Day 2: Docker + CI Pipeline Basics
**Status**: ✅ COMPLETED (2025-11-12)
**Goal**: Containerize app + GitHub Actions CI

**What We Built:**
- FastAPI AI Ops Agent
- Multi-stage Dockerfile
- GitHub Actions CI pipeline

**Why No Change**: Perfect progression, builds on Day 1.

---

### Day 3: Terraform + IaC Muscle Memory
**Status**: ✅ COMPLETED (2025-11-12)
**Goal**: Provision infra via code

**What We Built:**
- Complete Terraform config for Kind cluster
- Reusable K8s namespace module
- Makefile integration

**Why No Change**: Essential IaC foundation, well-executed.

---

### Day 4: Foundation Services + Ansible (MODIFIED)
**Status**: 📍 NEXT - This is the balanced approach
**Goal**: Deploy minimal DNS/PKI + Learn Ansible basics

#### Morning Session (4h): Foundation Services

**Part 1: CoreDNS for Cluster DNS (1.5h)**
```bash
# Goal: Service discovery working
# Scope: Simple CoreDNS, not full BIND9

# Deploy CoreDNS via Terraform/Helm
cluster/k3s/foundation/coredns/
├── values.yaml          # CoreDNS config
└── custom-zones.yaml    # corp.local zone

# What you learn:
- How K8s DNS works
- Service discovery
- Custom DNS zones
- CoreDNS configuration
```

**Part 2: Vault PKI with SoftHSM (1.5h)**
```bash
# Goal: Real CA for certificates (dev mode)
# Scope: SoftHSM (software HSM), not YubiHSM yet

# Deploy Vault with PKI engine
services/vault/
├── init-pki.sh          # Initialize PKI
├── root-ca.hcl          # Root CA policy
└── intermediate-ca.hcl  # Intermediate CA

# What you learn:
- PKI hierarchy (Root → Intermediate → Leaf)
- Vault PKI engine
- Certificate issuance
- HSM concepts (even if software)
```

**Part 3: Verify Foundation (1h)**
```bash
# Test DNS
kubectl run -it dns-test --image=busybox --rm -- \
  nslookup kubernetes.default.svc.cluster.local

# Test PKI
vault write pki_int/issue/ai-ops-agent \
  common_name=ai-ops.corp.local \
  ttl=24h

# Success: You have working DNS + PKI!
```

#### Afternoon Session (4h): Ansible Basics (Condensed)

**Focus on Core Concepts Only:**
```bash
# You still learn Ansible, just less depth on Day 4

1. Install Ansible (30 min)
2. Create inventory (30 min)
3. Simple playbook - install tools (1h)
4. Vault playbook - bootstrap (1h)
5. Test idempotency (1h)

# What we SKIP for now (move to Day 7):
- Complex DNS playbook (you have CoreDNS already)
- Advanced Ansible features
- Multiple services

# What you GAIN:
- Real DNS + PKI foundation
- Less frustration on Days 5-6
- Certificates work correctly
```

#### Day 4 Success Metrics
- ✅ CoreDNS resolving cluster services
- ✅ Vault PKI issuing certificates
- ✅ Basic Ansible playbook working
- ✅ Understand: DNS → PKI → Services flow
- ✅ Time: 8 hours (same as original)

---

### Day 5: Secrets Management (Vault) - ENHANCED
**Goal**: No plaintext secrets + Integrate with PKI foundation

**Morning (4h): Vault Setup (Same as Original)**
```bash
# Original Day 5 content, but now:
- Vault is already deployed (from Day 4)
- PKI engine already configured
- Focus on: Secrets management, K8s integration
```

**Afternoon (4h): Cert-manager Integration (NEW)**
```bash
# This is NEW - replaces some Vault K8s auth

# Install cert-manager
helm install cert-manager jetstack/cert-manager

# Configure ClusterIssuer (Vault PKI)
cat > cluster-issuer-vault.yaml <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: vault-issuer
spec:
  vault:
    server: http://vault.vault.svc:8200
    path: pki_int/sign/ai-ops-agent
    auth:
      kubernetes:
        role: cert-manager
        mountPath: /v1/auth/kubernetes
EOF

# Test certificate issuance
kubectl apply -f test-certificate.yaml

# Success: Cert issued from YOUR PKI!
```

**What You Learn:**
- Vault secrets management (original)
- PKI integration (enhanced)
- Cert-manager automation (new)
- K8s certificate workflow (new)

**What Changes from Original:**
- Less time on basic Vault setup (already done Day 4)
- More time on cert-manager integration
- Result: All future services get real certs automatically

---

### Day 6: CI/CD Pipeline (Same as Original)
**Goal**: git push → test → build → deploy

**Keep Original Plan:**
- GitHub Actions pipeline
- Docker build + push
- Security scanning
- SBOM generation

**Enhancement (5 min addition):**
```yaml
# Add to CI pipeline
- name: Sign container image
  run: cosign sign --key vault://pki/sign $IMAGE
  # Now using YOUR PKI, not random keys!
```

**Why Minimal Change**: Day 5 foundation pays off here - signing just works.

---

### Day 7: Week 1 Integration + Advanced Ansible
**Goal**: Deploy entire stack + Deep dive Ansible

**Morning (4h): Full Stack Deploy (Original)**
```bash
make dev-up      # Vault + Ollama
make kind-up     # Terraform Kind cluster
make apply-local # All resources
make deploy-agent # AI Ops agent

# Test end-to-end
curl http://localhost:30080/health
```

**Afternoon (4h): Advanced Ansible (Moved from Day 4)**
```bash
# Now we go DEEP on Ansible
# (This was rushed on Day 4 in original plan)

1. Complex playbooks (DNS, Samba, etc.)
2. Roles and collections
3. Ansible Vault integration
4. Dynamic inventories
5. Error handling and idempotency

# Lab: Create full DNS service playbook
services/dns/playbook.yml
```

**Why This Works:**
- You have working foundation (DNS/PKI)
- Week 1 is complete before deep Ansible dive
- More time to learn Ansible properly
- Can test Ansible against real services

---

## Week 2: Advanced Security + LLM Integration (Days 8-14)

### Day 8: Zero-Trust Networking (SAME as Original)
**No Changes Needed**

Your foundation (Day 4-5) makes this easier:
- mTLS certificates already working (from Vault PKI)
- Just add: Network policies, service mesh
- No certificate troubleshooting needed

---

### Day 9: Ollama + LLM Integration (SAME as Original)
**No Changes Needed**

Original plan is good, and benefits from foundation:
- Ollama gets real TLS cert (from cert-manager)
- AI agent gets real cert (automatic)
- No self-signed cert warnings

---

### Day 10: RAG Pipeline Basics (SAME as Original)
**No Changes Needed**

---

### Day 11: SBOM + Supply Chain Security (SAME as Original)
**No Changes Needed**

But now enhanced:
- Sign with YOUR PKI (not random cosign keys)
- Trust chain is real (from Day 4-5 foundation)

---

### Day 12: Monitoring + Observability (SAME as Original)
**No Changes Needed**

---

### Day 13: Production Readiness (ENHANCED)
**Goal**: Health checks, autoscaling, backups

**Addition: Upgrade Foundation Services (2h)**
```bash
# Optional: Upgrade to production PKI

1. Replace SoftHSM with YubiHSM (if available)
2. Rotate Root CA to HSM
3. Replace CoreDNS with BIND9 (if needed)
4. Add DNSSEC

# Or keep SoftHSM/CoreDNS (good enough for now)
```

---

### Day 14: Final Integration + Demo (SAME as Original)
**No Changes Needed**

But demo is better:
- Real certificates throughout
- DNS resolution working
- No "ignore cert warnings" in demo
- Production-ready architecture

---

## Comparison: Original vs Balanced

### Time Investment

| Day | Original Plan | Balanced Plan | Change |
|-----|---------------|---------------|--------|
| 1 | Terminal + K8s | Terminal + K8s | None |
| 2 | Docker + CI | Docker + CI | None |
| 3 | Terraform | Terraform | None |
| 4 | Ansible (full) | Foundation + Ansible (basics) | **Modified** |
| 5 | Vault | Vault + Cert-manager | **Enhanced** |
| 6 | CI/CD | CI/CD | None |
| 7 | Integration | Integration + Advanced Ansible | **Enhanced** |
| 8-14 | Advanced topics | Advanced topics | None |

**Total Extra Work**: ~0 hours (just reorganized)

### What You Gain

✅ **No Certificate Rework**
- Original: Self-signed → Real certs (rework on Day 10+)
- Balanced: Real certs from Day 5

✅ **Less Frustration**
- Original: "Why aren't my certs working?" (Days 8-10)
- Balanced: "It just works" (Day 5+)

✅ **Better Learning**
- Original: Learn Ansible in rush, redo later
- Balanced: Learn Ansible basics (Day 4), deep dive (Day 7)

✅ **Production-Ready Sooner**
- Original: Week 2 = fixing Week 1 mistakes
- Balanced: Week 2 = adding features

### What You Don't Lose

✅ **Learning Progression**: Still simple → complex
✅ **Hands-on Experience**: Still deploy everything yourself
✅ **Muscle Memory**: Still practice workflows
✅ **Total Time**: Still 14 days, 8 hours/day

---

## Day 4 Detailed Breakdown (The Key Day)

### Morning: Foundation Services (4h)

#### Hour 1: CoreDNS Deployment
```bash
# Create Helm values
cat > cluster/foundation/coredns/values.yaml <<EOF
service:
  name: coredns
  clusterIP: 10.96.0.10

servers:
- zones:
  - zone: cluster.local
  port: 53
  plugins:
  - name: errors
  - name: health
  - name: ready
  - name: kubernetes
    parameters: cluster.local in-addr.arpa ip6.arpa
  - name: forward
    parameters: . /etc/resolv.conf

- zones:
  - zone: corp.local
  port: 53
  plugins:
  - name: errors
  - name: file
    parameters: /etc/coredns/zones/corp.local
EOF

# Deploy
helm repo add coredns https://coredns.github.io/helm
helm install coredns coredns/coredns -f values.yaml -n kube-system

# Test
kubectl run -it test --image=busybox --rm -- nslookup kubernetes.default
```

**Learning Outcomes**:
- How K8s DNS works
- CoreDNS plugin system
- Custom DNS zones
- Service discovery

---

#### Hour 2: SoftHSM Setup
```bash
# Install SoftHSM (software-based HSM simulator)
# Good for dev, teaches HSM concepts

# Initialize SoftHSM
softhsm2-util --init-token --slot 0 --label "vault-hsm"

# Configure Vault to use SoftHSM
cat > vault-config.hcl <<EOF
seal "pkcs11" {
  lib = "/usr/lib/softhsm/libsofthsm2.so"
  slot = "0"
  pin = "1234"
  key_label = "vault-key"
}

storage "file" {
  path = "/vault/data"
}

listener "tcp" {
  address = "0.0.0.0:8200"
  tls_disable = true  # Will enable after cert-manager
}
EOF
```

**Learning Outcomes**:
- HSM concepts (even if software)
- Vault seal/unseal process
- PKCS#11 interface
- Security key storage

---

#### Hour 3: Vault PKI Engine
```bash
# Deploy Vault (using config from Hour 2)
kubectl apply -f cluster/foundation/vault/deployment.yaml

# Initialize Vault
vault operator init

# Enable PKI engine
vault secrets enable pki

# Create Root CA
vault write pki/root/generate/internal \
  common_name="corp.local Root CA" \
  ttl=87600h  # 10 years

# Create Intermediate CA
vault secrets enable -path=pki_int pki
vault write pki_int/intermediate/generate/internal \
  common_name="corp.local Intermediate CA" \
  ttl=43800h  # 5 years

# Sign intermediate with root
vault write pki/root/sign-intermediate \
  csr=@pki_int.csr \
  format=pem_bundle \
  ttl=43800h

# Set up issuing role
vault write pki_int/roles/ai-ops-agent \
  allowed_domains=corp.local \
  allow_subdomains=true \
  max_ttl=720h
```

**Learning Outcomes**:
- PKI hierarchy (Root → Intermediate → Leaf)
- Certificate signing process
- Vault PKI engine
- CA best practices

---

#### Hour 4: Verify & Document
```bash
# Test DNS
kubectl run dns-test --image=busybox --rm -it -- \
  nslookup kubernetes.default.svc.cluster.local

# Test PKI - Issue a test certificate
vault write pki_int/issue/ai-ops-agent \
  common_name=test.corp.local \
  ttl=24h

# Document what you built
cat > docs/foundation-services.md <<EOF
# Foundation Services

## DNS (CoreDNS)
- Cluster DNS: cluster.local
- Custom zone: corp.local
- Service: coredns.kube-system.svc

## PKI (Vault + SoftHSM)
- Root CA: corp.local Root CA
- Intermediate CA: corp.local Intermediate CA
- Issuing path: pki_int/issue/ai-ops-agent

## Testing
\`\`\`bash
# DNS test
nslookup kubernetes.default

# PKI test
vault write pki_int/issue/ai-ops-agent common_name=test.corp.local
\`\`\`
EOF
```

**Learning Outcomes**:
- How to verify infrastructure
- Documentation best practices
- Foundation is ready for Day 5

---

### Afternoon: Ansible Basics (4h)

Condensed version of original Day 4 Ansible content:

#### Hours 5-6: Ansible Fundamentals (Condensed)
```bash
# Install Ansible
pip install ansible ansible-lint

# Create inventory
cat > inventory/local.yml <<EOF
all:
  children:
    k8s_local:
      hosts:
        localhost:
          ansible_connection: local
EOF

# First playbook - verify foundation
cat > playbooks/verify-foundation.yml <<EOF
---
- name: Verify foundation services
  hosts: localhost
  tasks:
    - name: Check CoreDNS pods
      command: kubectl get pods -n kube-system -l k8s-app=coredns
      register: coredns_status

    - name: Check Vault pod
      command: kubectl get pods -n vault -l app=vault
      register: vault_status

    - debug:
        msg: "Foundation services are running!"
EOF

# Run it
ansible-playbook -i inventory/local.yml playbooks/verify-foundation.yml
```

#### Hours 7-8: Simple Service Playbook
```bash
# Bootstrap playbook - install required tools
# This teaches Ansible basics without complex services

cat > playbooks/bootstrap.yml <<EOF
---
- name: Bootstrap development environment
  hosts: localhost
  tasks:
    - name: Check kubectl installed
      command: which kubectl
      changed_when: false

    - name: Check helm installed
      command: which helm
      changed_when: false

    - name: Verify Vault is accessible
      uri:
        url: http://localhost:8200/v1/sys/health
        status_code: [200, 429, 472, 473, 501, 503]
      register: vault_health

    - debug:
        msg: "Vault status: {{ vault_health.json.sealed }}"
EOF

# Run and verify idempotency
ansible-playbook -i inventory/local.yml playbooks/bootstrap.yml
ansible-playbook -i inventory/local.yml playbooks/bootstrap.yml
# Second run should show no changes
```

**What We SKIP for Day 4** (move to Day 7):
- Complex DNS record management
- Multi-service orchestration
- Advanced Ansible features (roles, handlers, etc.)

**Why This Works**:
- You learn Ansible fundamentals
- Foundation services are in place
- Day 7 = deep dive on Ansible with working services to target

---

## Key Principle: "Good Enough" Foundations

### CoreDNS (Not BIND9)
**Good Enough For**:
- Learning K8s DNS
- Service discovery
- Simple custom zones
- Days 1-14 of sprint

**Upgrade Later**:
- BIND9 for full DNS server
- DNSSEC for security
- Secondary nameservers
- Production deployment

### SoftHSM (Not YubiHSM)
**Good Enough For**:
- Learning PKI concepts
- Development environment
- Certificate automation
- Days 1-14 of sprint

**Upgrade Later**:
- YubiHSM for real hardware security
- FIPS 140-2 Level 3 compliance
- Production deployment
- Regulatory requirements

### Single Intermediate CA (Not Full Hierarchy)
**Good Enough For**:
- Learning certificate chains
- Automated cert issuance
- Service mTLS
- Days 1-14 of sprint

**Upgrade Later**:
- Multiple intermediate CAs (per-service)
- Offline root CA
- Certificate transparency logs
- Production PKI

---

## Migration Path: Dev → Production

### Phase 1: Days 1-14 (This Plan)
```
CoreDNS (simple)
  └─ SoftHSM (software)
      └─ Vault PKI
          └─ Cert-manager
              └─ Service certificates
```

**Status**: Good enough for learning, local dev, demos

### Phase 2: Production Upgrade (Later)
```
BIND9 + DNSSEC
  └─ YubiHSM 2 (hardware)
      └─ Vault PKI (sealed by HSM)
          └─ Cert-manager
              └─ Service certificates (auto-rotated)
```

**When**: After Day 14, before Proxmox deployment

### Phase 3: Full Production (Future)
```
FreeIPA (DNS + LDAP + CA)
  └─ YubiHSM 2 cluster (HA)
      └─ Vault PKI Enterprise
          └─ Multiple cert-manager instances
              └─ Per-service CAs
```

**When**: Production deployment on Proxmox

---

## Success Metrics: Balanced Plan

### Day 4 (Foundation Day)
- [ ] CoreDNS resolving cluster.local and corp.local
- [ ] SoftHSM initialized and Vault using it
- [ ] Vault PKI engine issuing certificates
- [ ] Ansible running basic playbooks
- [ ] Time: 8 hours (4h foundation + 4h Ansible basics)

### Day 5 (Enhanced)
- [ ] Cert-manager installed and configured
- [ ] ClusterIssuer pointing to Vault PKI
- [ ] Test certificate issued successfully
- [ ] Trust chain verified

### Day 7+ (No Rework Needed)
- [ ] All services get certificates automatically
- [ ] No "ignore cert warnings" in demos
- [ ] mTLS works without troubleshooting
- [ ] Can focus on features, not fixing foundations

---

## FAQs

### Q: Is Day 4 too much?
**A**: No, it's split into small chunks:
- 1.5h CoreDNS (simple Helm chart)
- 1.5h SoftHSM setup (straightforward)
- 1h Vault PKI (follow commands)
- 1h Testing & docs
- 4h Ansible basics (condensed from original)

Total: 8 hours (same as original Day 4)

### Q: What if I get stuck on Day 4?
**A**: Foundation services have escape hatches:
- CoreDNS not working? Skip custom zones, use cluster DNS only
- SoftHSM issues? Use Vault dev mode (no HSM)
- Can always fall back to original Day 4 plan

### Q: Do I lose learning value?
**A**: No, you gain:
- Original Day 4: Learn Ansible (rush through, redo later)
- Balanced Day 4: Learn DNS/PKI (use it every day) + Ansible basics
- Day 7: Deep dive Ansible with working foundations

### Q: Can I skip the foundation?
**A**: Yes! This plan is flexible:
- Want original experience? Skip Hours 1-4 on Day 4
- Want foundation? Follow this plan
- Want full production? Spend 2 days on Day 4

---

## Recommendation: Start Balanced Plan on Day 4

Since you've completed Days 1-3 already:

✅ **Day 1-3**: Done (K8s basics, Docker, Terraform)
📍 **Day 4**: Follow balanced plan (Foundation + Ansible basics)
🚀 **Day 5+**: Enjoy having real certificates and DNS working

**Next Step**: Should I create the Day 4 implementation files?
- CoreDNS Helm values
- SoftHSM setup scripts
- Vault PKI initialization
- Ansible playbooks (condensed)

This gives you the best of both worlds:
- Learn by doing (educational value)
- Real foundations (reduce frustration)
- No major rework (production-ready path)
- Same time investment (8 hours/day)

What do you think? Want to proceed with Balanced Day 4? 🎯
