# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Governance Compliance

**CRITICAL:** This project follows the **Unified AI Agent Governance Framework v3.0**. All AI agents (including Claude Code instances) operating in this repository MUST comply with the framework's rules.

**Framework location:** `/home/suhlabs/projects/suhlabs/ai-agent-governance-framework/UNIFIED-AI-AGENT-GOVERNANCE-FRAMEWORK-v3.0.md`

**Key governance principles applicable to this work:**
- **Namespace scope:** Operations limited to `aiops-substrate` project directory
- **Inspection-first protocol:** Always read before write; list resources before modification
- **Destructive operations:** Require explicit confirmation with impact analysis and rollback plan
- **No assumptions:** When scope or ownership is unclear, ask for clarification
- **Audit trail:** All significant actions should be documented
- **Fail-safe:** Default to deny; escalate with full context when uncertain

## Project Overview

**AIOps Substrate** is a production-grade AI operations platform built with 100% open-source tools. The project implements enterprise DevSecOps practices including infrastructure as code, automated certificate management, CI/CD pipelines, and zero-trust security patterns.

**Key characteristics:**
- Self-hosted infrastructure with zero cloud costs
- Two-tier PKI with automated certificate lifecycle management
- Security-first design with shift-left practices
- Kubernetes-based orchestration (Kind for local, K3s for production)

**Project namespace:** `aiops-substrate` (all operations confined to `/home/suhlabs/projects/suhlabs/aiops-substrate/`)

## Essential Commands

### Cluster Management

```bash
# Create Kind cluster
make kind-up

# Destroy Kind cluster
make kind-down

# Full dev stack (Vault, Ollama, etc.)
make dev-up
make dev-down
```

### Foundation Services Deployment

Foundation services must be deployed in this specific order due to dependencies:

```bash
cd cluster/foundation

# 1. CoreDNS (no dependencies)
cd coredns && ./deploy.sh && cd ..

# 2. SoftHSM (no dependencies)
cd softhsm && ./init-softhsm.sh && cd ..

# 3. Vault PKI (needs SoftHSM for auto-unseal)
cd vault-pki && ./init-vault-pki.sh && cd ..

# 4. Cert-manager (needs CoreDNS + Vault PKI)
cd cert-manager
export VAULT_TOKEN=<your-root-token>
./deploy.sh

# Verify entire foundation stack
cd cluster/foundation && ./verify-all.sh
```

### Infrastructure as Code

```bash
# Terraform (local environment)
make init-local      # Initialize Terraform
make plan-local      # Plan changes
make apply-local     # Apply infrastructure

# Terraform (production)
make init-prod       # Initialize with Proxmox backend
make apply-prod      # Deploy to Proxmox

# Formatting and validation
make tf-fmt          # Format Terraform code
make tf-validate     # Validate configuration
```

### AI Ops Agent

```bash
cd cluster/ai-ops-agent

# Build and deploy
./deploy.sh

# Manual deployment
docker build -t ai-ops-agent:0.1.0 .
kind load docker-image ai-ops-agent:0.1.0
kubectl apply -f k8s/

# Test endpoints
kubectl port-forward svc/ai-ops-agent 8000:8000
curl http://localhost:8000/health
```

### Testing and Verification

```bash
# Run all foundation verification tests (37+ automated tests)
cd cluster/foundation && ./verify-all.sh

# Test specific components
cd cluster/foundation/vault-pki && ./verify-pki.sh
cd cluster/foundation/cert-manager && ./verify-cert-manager.sh

# Test AI agent
make test-ai
```

### Security Scanning

The project includes comprehensive security scanning:

```bash
# CI/CD pipeline runs automatically on push
# Includes: Trivy, Grype, SBOM generation

# Local scanning
cd cluster/ai-ops-agent
./install-scanners.sh  # One-time setup
./scan.sh              # Run all scanners
```

## Architecture Overview

### Three-Layer Stack

```
Application Layer (AI Ops Agent, Services)
    ↓
Certificate Management Layer (cert-manager + Vault PKI)
    ↓
Foundation Layer (CoreDNS, Vault, SoftHSM)
    ↓
Infrastructure Layer (Kubernetes, Terraform, Ansible)
```

### Critical Dependencies

**CoreDNS:**
- Provides service discovery for Kubernetes
- Custom corp.local DNS zone
- Required for cert-manager to resolve Vault service
- Must be deployed first

**SoftHSM:**
- Software HSM for development (use YubiHSM 2 in production)
- Provides PKCS#11 interface for Vault auto-unseal
- Stores Vault master key securely
- Required before Vault can start

**Vault PKI:**
- Two-tier CA hierarchy (Root CA + Intermediate CA)
- Root CA: 10-year, 4096-bit RSA, offline in production
- Intermediate CA: 5-year, 2048-bit RSA, online operations
- Three PKI roles: ai-ops-agent (30d), kubernetes (90d), cert-manager (90d)
- Provides certificates for all services

**cert-manager:**
- Automates certificate issuance and renewal
- Integrates with Vault PKI via ClusterIssuers
- Issues certificates with 30-day lifetime, auto-renews at day 20
- Requires both CoreDNS (for Vault service resolution) and Vault PKI (for certificate issuance)

### Service Dependency Order

Critical: Services must be deployed in this order:
1. CoreDNS (provides DNS resolution)
2. SoftHSM (provides HSM for Vault)
3. Vault (needs SoftHSM for auto-unseal)
4. Vault PKI (needs Vault running)
5. cert-manager (needs DNS + Vault PKI)
6. Application services (need cert-manager for TLS)

## Code Organization

```
aiops-substrate/
├── cluster/                    # Kubernetes resources
│   ├── foundation/            # Foundation services (CoreDNS, Vault, SoftHSM)
│   │   ├── coredns/          # DNS with corp.local zone
│   │   ├── softhsm/          # HSM for Vault auto-unseal
│   │   ├── vault/            # Vault deployment
│   │   ├── vault-pki/        # PKI initialization scripts
│   │   └── cert-manager/     # Certificate automation
│   └── ai-ops-agent/         # AI Ops FastAPI service
│       ├── ai_ops_agent/     # Python package (models, intent, RAG, MCP)
│       ├── k8s/              # Kubernetes manifests
│       └── main.py           # FastAPI application
├── infra/                     # Terraform infrastructure
│   ├── local/                # Kind cluster configuration
│   ├── proxmox/              # Production Proxmox VMs
│   └── modules/              # Reusable Terraform modules
├── ansible/                   # Ansible automation
│   ├── playbooks/            # Verification and deployment playbooks
│   └── inventory/            # Environment inventories
├── bootstrap/                 # Bootstrap configuration
│   ├── kind-cluster.yaml     # Kind cluster spec
│   └── docker-compose.yml    # Local service stack
├── .github/workflows/         # CI/CD pipelines
│   ├── cd.yml                # Main deployment pipeline
│   ├── security-scan.yml     # Security scanning
│   └── sbom.yml              # SBOM generation
└── docs/                      # Documentation
    ├── DAY-*.md              # Daily progress summaries
    ├── lessons-learned.md    # Critical lessons and debugging guides
    └── *-GUIDE.md            # Component-specific guides
```

## Critical Patterns

### Pre-Implementation Checklist (Framework Required)

**MANDATORY per Governance Framework Section 1:** Always check GitHub issues before implementing:

1. **Search GitHub issues first:**
   - Go to the technology's GitHub repository
   - Search issues: `is:issue <your-feature>`
   - Read both open AND closed issues
   - Look for "Enterprise only" or "requires X edition" limitations

2. **Validate against known issues:**
   - Search for configuration keywords
   - Check for CrashLoopBackOff, ImagePullBackOff patterns
   - Look for discussions about workarounds

3. **Document your research:**
   - Link to issues reviewed in code comments
   - Note known limitations in commit messages
   - Document alternatives considered in design docs

**Example from this project:** Vault PKCS#11 seal requires Enterprise edition (discovered after 2+ hours of debugging). OpenBao provides OSS alternative. This pattern is documented in `docs/lessons-learned.md:1-59`.

**Time savings:** 15 minutes research vs 2+ hours debugging wrong approach = 105 minutes saved per component.

### Certificate Management Pattern

All services get automatic TLS certificates via cert-manager:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-service-cert
spec:
  secretName: my-service-tls
  duration: 720h        # 30 days
  renewBefore: 240h     # Renew at day 20
  issuerRef:
    name: vault-issuer-ai-ops
    kind: ClusterIssuer
  commonName: my-service.corp.local
  dnsNames:
    - my-service
    - my-service.default.svc.cluster.local
```

Certificate is automatically mounted in pod as a secret volume.

### Secret Management Pattern

Use Vault for all secrets, not Kubernetes secrets:

```bash
# Write secret to Vault
vault kv put secret/myapp/config api_key="secret123"

# Read in application
vault kv get -field=api_key secret/myapp/config
```

Never commit secrets to git. Use .env.example templates.

### Deployment Script Pattern (Framework Pattern 1 & 2)

**Per Framework Section 17:** All deployment scripts follow this pattern:

```bash
#!/bin/bash
set -euo pipefail  # Pattern 1: Fail Fast - exit on error, undefined vars, pipe failures

echo "Deploying component..."

# Pattern 4: Defensive prerequisite validation
kubectl cluster-info || { echo "Cluster not ready"; exit 1; }

# Pattern 2: Deploy dependencies first
kubectl apply -f certificate.yaml

# Pattern 2: Wait for dependency readiness before deploying dependent
kubectl wait --for=condition=ready certificate/my-cert --timeout=120s

# Now safe to deploy application
kubectl apply -f deployment.yaml

# Wait for ready
kubectl wait --for=condition=ready pod -l app=myapp --timeout=120s

# Verify
kubectl get pods -l app=myapp

echo "✓ Deployment complete"
```

**Anti-pattern (Framework Section 20.2):** ❌ `kubectl apply -f .` (deploying all resources simultaneously causes race conditions)

### AI Ops Agent Integration

The AI Ops Agent is a conversational infrastructure automation service:

```python
# Intent-based automation
POST /api/v1/chat
{
  "query": "Create an email address for user@example.com",
  "user_id": "admin",
  "mfa_enabled": true
}

# Response includes parsed intent, execution plan, and MCP policy checks
# RAG retrieves relevant context from Qdrant vector DB
# Ansible/Terraform execute the automation
```

Key components:
- `ai_ops_agent/intent/`: Natural language → Intent parsing
- `ai_ops_agent/rag/`: Context retrieval from vector DB
- `ai_ops_agent/mcp/`: Policy enforcement (security, compliance)
- `ai_ops_agent/ml/`: ML logging for continuous improvement

## Testing Approach

### Foundation Services Verification

Run comprehensive verification suite (37+ tests):

```bash
cd cluster/foundation
./verify-all.sh
```

Tests include:
- DNS resolution (cluster.local + corp.local)
- Vault status and seal state
- SoftHSM token and slots
- PKI CA chain validation
- Certificate issuance and renewal
- cert-manager CRDs and controllers

### Integration Testing

Test service-to-service connectivity:

```bash
# DNS → Vault
kubectl run -it test --image=busybox:1.36 --rm --restart=Never -- \
  nslookup vault.vault.svc.cluster.local

# Vault → PKI (certificate issuance)
vault write pki_int/issue/ai-ops-agent \
  common_name="test.corp.local" \
  ttl="24h"

# cert-manager → Vault → Application
kubectl apply -f test-certificate.yaml
kubectl wait --for=condition=ready certificate/test-cert --timeout=60s
```

### CI/CD Pipeline

GitHub Actions CD pipeline runs on every push:
- Python tests (pytest)
- Security scanning (Trivy for vulnerabilities)
- SBOM generation (Syft for CycloneDX/SPDX)
- Docker image build and push to ghcr.io
- Security findings appear in GitHub Security tab

## Development Environment

### Prerequisites

- Docker or Podman
- kubectl
- kind (for local Kubernetes)
- Terraform
- Ansible
- Vault CLI
- Helm
- Make

### VS Code Workspace

Project includes `suhlabs.code-workspace` with recommended extensions:
- Kubernetes
- Terraform
- Ansible
- Python
- YAML

### Local Development Flow

```bash
# 1. Create cluster
make kind-up

# 2. Deploy foundation
cd cluster/foundation
./verify-all.sh

# 3. Deploy AI agent
cd ../ai-ops-agent
./deploy.sh

# 4. Develop
kubectl port-forward svc/ai-ops-agent 8000:8000
# Edit code, rebuild, redeploy

# 5. Clean up
make kind-down
```

## Security Considerations

### Development vs Production

**Current setup is for DEVELOPMENT:**
- ⚠️ SoftHSM (software keys, not hardware)
- ⚠️ Root CA online (should be air-gapped)
- ⚠️ Simple passwords for demos
- ⚠️ No audit logging

**Production requires:**
- ✓ YubiHSM 2 or AWS CloudHSM
- ✓ Root CA offline on air-gapped machine
- ✓ Strong random passwords (16+ chars)
- ✓ Comprehensive audit logging to SIEM
- ✓ Dual control for sensitive operations
- ✓ Regular key rotation
- ✓ Disaster recovery procedures

### Security Best Practices

1. **Short certificate lifetimes** - 30 days forces automation
2. **Least privilege** - Each service gets its own PKI role with domain restrictions
3. **Defense in depth** - Multiple security layers (network policies, mTLS, RBAC)
4. **Audit everything** - Enable Vault audit logging in production
5. **Secrets in Vault** - Never in environment variables or Kubernetes secrets
6. **Non-root containers** - All containers run as UID 1000+
7. **Read-only root filesystem** - Where possible
8. **Security scanning** - Trivy scans on every build

## Working with Claude Code (Governance Framework Workflow)

### Standard Operating Procedure

**Per Framework Section 21:** Follow this workflow for all tasks:

**Phase 1: Inspection (Always Read-Only First)**
1. Identify current environment and verify namespace (`aiops-substrate`)
2. List relevant resources (files, deployments, certificates, etc.)
3. Read existing configurations before proposing changes
4. Check current state vs desired state

**Phase 2: Planning**
5. Propose action and classify risk level (safe/medium/high)
6. Identify dependencies and prerequisites
7. Assess impact and blast radius
8. For destructive operations: prepare rollback plan

**Phase 3: Validation**
9. For medium/high-risk operations: describe dry-run approach
10. Confirm operations are idempotent (can be safely repeated)
11. Verify namespace boundaries (staying in project directory)

**Phase 4: Execution**
12. Execute approved actions
13. Verify expected outcome
14. Document changes in commit messages

**Phase 5: Escalation (when needed)**
- Scope is ambiguous or ownership unclear → Ask user for clarification
- Operation is destructive beyond routine → Request explicit confirmation
- Cross-namespace or cross-project operation needed → Seek approval

**Example escalation:**
```
🔔 Escalation Required

Operation: Delete 50 old Docker images
Risk: Medium (frees disk space but images cannot be recovered)
Affected: /var/lib/docker/overlay2/ (estimated 15GB)
Rollback: Images can be rebuilt from Dockerfile, but takes ~10 minutes

Proceed? (yes/no)
```

## Troubleshooting Guide

### Common Issues

**ImagePullBackOff:**
- Verify image exists: `docker images | grep <image>`
- Load into cluster: `kind load docker-image <image>`
- Check image pull policy in deployment

**Certificate not issued:**
```bash
# Check certificate status
kubectl describe certificate <name>

# Check cert-manager logs
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager

# Verify Vault connectivity
kubectl exec -n cert-manager <pod> -- nc -zv vault.vault.svc.cluster.local 8200
```

**Vault sealed:**
```bash
# Check seal status
kubectl exec -n vault vault-0 -- vault status

# If sealed, check SoftHSM auto-unseal
kubectl logs -n vault vault-0 | grep -i pkcs11
```

**DNS not resolving:**
```bash
# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=coredns

# Test from pod
kubectl run -it test --image=busybox:1.36 --rm -- nslookup kubernetes.default
```

**Pod crashes/CrashLoopBackOff:**
```bash
# Check recent logs
kubectl logs <pod> --previous

# Check events
kubectl describe pod <pod>

# Common causes:
# - Missing environment variables
# - Cannot connect to dependencies
# - Certificate not ready
```

### Debugging Process (Inspection-First Protocol)

**Per Framework Section 7.1:** All operations begin with read-only inspection:

1. **Check pod status:** `kubectl get pods -A` (read-only)
2. **View events:** `kubectl describe pod <name>` (read-only)
3. **Read logs:** `kubectl logs <pod> --previous` (read-only)
4. **List resources:** `kubectl get all -n <namespace>` (read-only)
5. **Check dependencies:** Verify DNS, Vault, certificates (read-only queries)
6. **Identify blast radius:** What will be affected by changes?
7. **Review GitHub issues:** Search for error messages (framework-required)
8. **Check lessons-learned.md:** Known issues and solutions
9. **THEN propose modification** (only after inspection complete)

**For interactive debugging:**
- `kubectl exec -it <pod> -- /bin/sh` (proceed with caution, changes inside pod are ephemeral)

**Framework rule:** Never assume - always inspect current state before making changes.

## Important Files

- `Makefile` - All common operations
- `cluster/foundation/verify-all.sh` - Master verification script
- `docs/lessons-learned.md` - Critical lessons and known issues
- `.github/workflows/cd.yml` - CI/CD pipeline
- `cluster/ai-ops-agent/main.py` - AI agent application entry point
- `cluster/foundation/README.md` - Foundation services architecture

## References

- Main README: `README.md` - Project overview and quick start
- Foundation: `cluster/foundation/README.md` - CoreDNS, Vault, SoftHSM architecture
- AI Agent: `cluster/ai-ops-agent/README.md` - FastAPI service details
- Cert-manager: `cluster/foundation/cert-manager/README.md` - Certificate automation
- Lessons: `docs/lessons-learned.md` - Known issues and debugging
- Sprint plan: `docs/14-DAY-SPRINT.md` - Development roadmap

## Project Status

- ✅ Days 1-6 Complete: Foundation + CI/CD
- 🔄 Day 7: Week 1 integration
- 📅 Days 8-14: mTLS, LLM integration, monitoring, production hardening

## Governance Framework Compliance

### Prohibited Operations (Framework Tier 3 - Always Deny)

**Per Framework Section 7.4 & 23:** The following operations are NEVER allowed:

❌ **Root deletion:** `rm -rf /` or equivalent root filesystem deletion
❌ **Recursive deletion without file list:** `rm -rf *` without explicit path and confirmation
❌ **Credential exposure:** Echo/cat/print passwords, API keys, secrets, or tokens to stdout
❌ **Audit log modification:** Delete, truncate, or modify audit logs
❌ **Policy bypass:** Skip, bypass, or disable governance/validation checks
❌ **Privilege escalation without approval:** sudo, su -, chmod +s without explicit user approval
❌ **Cross-project operations:** Modifications outside `/home/suhlabs/projects/suhlabs/aiops-substrate/`
❌ **Hardcoded credentials:** Never put secrets in code, even temporarily

### Required Before Destructive Operations

**Per Framework Section 7.2:** Before ANY destructive action, provide:

1. **Scope confirmation:** Display exact resources to be affected
2. **Impact analysis:** Estimate blast radius and dependencies
3. **Idempotency check:** Confirm operation can be safely retried
4. **Rollback plan:** Document recovery procedure
5. **Human confirmation:** Wait for explicit approval

**Example:**
```
📋 Destructive Operation Analysis

Action: Delete unused Kubernetes deployments
Scope: 3 deployments in 'default' namespace:
  - old-app-v1 (last active: 30 days ago)
  - test-deployment (no pods running)
  - legacy-service (0 replicas)

Impact: Minimal - no active pods, can be recreated from manifests
Dependencies: None (services already deleted)
Idempotent: Yes - kubectl delete is idempotent
Rollback: Manifests available in git at cluster/archive/

Proceed with deletion? (yes/no)
```

### Environment Variable Anti-Pattern

**Per Framework Section 8.2 & 20.1:** Environment variables MUST be declared in orchestration manifests, never generated at runtime.

❌ **WRONG (Tier 3 violation):**
```bash
# entrypoint.sh
export DATABASE_URL="postgres://user:pass@localhost/db"
python app.py
```

✅ **CORRECT (Framework compliant):**
```yaml
# docker-compose.yml or k8s deployment.yaml
services:
  app:
    environment:
      DATABASE_URL: ${DATABASE_URL}  # Declared in manifest
```

### File Operations Scope

**Per Framework Section 9.1:** File operations restricted to:

✅ **Allowed:**
- `/home/suhlabs/projects/suhlabs/aiops-substrate/` (project directory)
- `/tmp/aiops-substrate-*` (temporary files with namespace prefix)
- Declared volume mounts in Kubernetes manifests

❌ **Prohibited:**
- Modifications outside project directory
- System directories (`/etc`, `/usr`, `/var` unless explicitly mounted)
- Other projects or user home directories

### Secrets Management

**Per Framework Section 10:** All secrets MUST be retrieved from approved stores:

✅ **Approved secret stores:**
- HashiCorp Vault (primary for this project)
- Kubernetes Secrets (with encryption at rest via cert-manager)
- AWS Secrets Manager (for production on AWS)

❌ **Prohibited:**
- Secrets in code or comments
- Secrets in environment variables (except orchestration-managed)
- Secrets in logs or stdout
- Secrets in git (even in history)

### Pre-Flight Checklist for Claude Code

Before taking any action in this repository:

- [ ] Verify I'm working in `/home/suhlabs/projects/suhlabs/aiops-substrate/` namespace
- [ ] Inspect current state (read-only) before proposing changes
- [ ] For file operations: List affected files before deletion/modification
- [ ] For destructive operations: Provide impact analysis and rollback plan
- [ ] For configuration changes: Verify changes are in manifest files, not runtime
- [ ] Check GitHub issues if implementing new technology/feature
- [ ] When uncertain: Ask user for clarification (never assume)
- [ ] Document significant changes in commit messages

**When in doubt:** Escalate with full context. Never assume.

---

**Governance Attestation:**
- Framework Version: v3.0.0
- Framework Location: `/home/suhlabs/projects/suhlabs/ai-agent-governance-framework/UNIFIED-AI-AGENT-GOVERNANCE-FRAMEWORK-v3.0.md`
- Namespace: `aiops-substrate`
- Compliance: MANDATORY
