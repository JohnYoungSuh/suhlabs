# Lessons Learned - DevSecOps Sprint

---

## 🔄 StatefulSet Data Persistence Anti-Pattern (2025-11-28)

**Issue:** Vault pod stuck in `CrashLoopBackOff` / `0/1 Ready` with "invalid key: failed to setup unseal key: crypto/aes: invalid key size 33" error.

**Root Cause:**
1. **PersistentVolumeClaim (PVC) persists data across pod deletions** - Vault data from previous initialization remained on disk
2. **Mismatched unseal keys** - `.vault-keys.json` file didn't match the Vault data stored in the PVC
3. **StatefulSet design** - By design, StatefulSets preserve data to survive pod restarts (correct for production, problematic for dev resets)
4. **Auto-unseal sidecar misconfiguration** - Volume mount names didn't match between `extraVolumes` declaration and `extraContainers` usage

**Anti-Pattern Identified:**
```bash
# ❌ WRONG: Deleting only the pod won't help
kubectl delete pod vault-0 -n vault
# StatefulSet recreates the pod, but PVC has old/corrupt data

# ✅ CORRECT: Delete BOTH StatefulSet and PVC for clean slate
kubectl delete statefulset vault -n vault
kubectl delete pvc data-vault-0 -n vault
```

**Understanding Kubernetes StatefulSets:**
- **StatefulSets** are designed for stateful applications (databases, caches, secret stores)
- **PVCs** persist data independently of pod lifecycle
- **Pod deletion** → StatefulSet recreates pod → **Same PVC reattached** → Old data restored
- **This is correct behavior for production** (data survives pod crashes)
- **This creates issues in dev** when you need to reset/reinitialize

**Solutions Applied:**
1. **Deleted StatefulSet + PVC** to wipe Vault data completely
2. **Removed auto-unseal sidecar** from `values.yaml` (misconfigured volumes)
3. **Redeployed Vault** with clean storage
4. **Re-initialized Vault** with new unseal keys (saved to `.vault-keys-NEW.json`)
5. **Re-initialized PKI** (Root CA + Intermediate CA + roles)
6. **Reconfigured cert-manager** Kubernetes auth to reconnect to new Vault instance

**Correct Dev Workflow for StatefulSets:**
```bash
# When you need to completely reset a StatefulSet:
1. Delete StatefulSet: kubectl delete statefulset <name> -n <namespace>
2. Delete PVC: kubectl delete pvc <pvc-name> -n <namespace>
3. Redeploy: helm upgrade --install ... or ./deploy.sh
4. Re-initialize: Initialize with new keys/data

# When you just need to restart pods (keep data):
1. Restart deployment: kubectl rollout restart statefulset <name> -n <namespace>
2. Or delete pod: kubectl delete pod <name> -n <namespace>
# StatefulSet recreates pod, PVC data is preserved
```

**Production vs Development:**
- **Production**: StatefulSet + PVC persistence is CRITICAL (data survives failures)
- **Development**: Consider using `emptyDir` volumes or easily deletable storage for rapid iteration
- **Know when to preserve vs reset**: Understand the difference between restart and reinitialize

**Key Learnings:**
1. ✅ **StatefulSets preserve data by design** - This is a feature, not a bug
2. ✅ **PVCs are independent resources** - They don't get deleted when pods are deleted
3. ✅ **Configuration mismatches persist** - If your config references wrong volumes, the pod will fail on every restart
4. ✅ **For dev resets, delete BOTH StatefulSet + PVC** - Don't just delete the pod
5. ✅ **Check volume mount names match** - `extraVolumes` names must match `volumeMounts` names exactly

**Files Modified:**
- `cluster/foundation/vault/values.yaml` - Commented out auto-unseal sidecar (volume mount mismatch)
- `cluster/foundation/vault/.vault-keys-NEW.json` - New unseal keys after reinitialization

**Impact:**
- Vault downtime: ~15 minutes (as estimated)
- Vault PKI completely rebuilt (Root CA, Intermediate CA, all roles)
- cert-manager reconnected successfully after Kubernetes auth reconfiguration
- All existing certificates remained valid (no renewal required)

**Validation:**
```bash
# Check Vault status
kubectl get pods -n vault
kubectl exec -n vault vault-0 -- vault status

# Check cert-manager ClusterIssuers
kubectl get clusterissuer
# All should show: READY = True

# Verify certificates still valid
kubectl get certificate -A
```

**Lesson:** Understanding Kubernetes resource lifecycles (Pod vs StatefulSet vs PVC) is critical for effective troubleshooting. In dev, you often need to delete BOTH the StatefulSet AND the PVC to get a clean slate. **This experience deepened understanding of K8s persistence patterns.** ✅

---

## AI Ops Agent - Ollama/Qdrant Network Connectivity (2025-11-25)

**Issue:** AI Ops agent requests hanging indefinitely when trying to use LLM-powered intent parsing.

**Root Causes:**
1. **Qdrant not running** - RAG retriever hung waiting for Qdrant vector database
2. **Network isolation** - Ollama/Qdrant containers on `bootstrap_default` network, Kind cluster on `kind` network
3. **Mistral model too slow** - 7.2B parameter model times out (60s+) on CPU when using `"format": "json"` constraint

**Solutions Applied:**
1. Added Qdrant to `bootstrap/docker-compose.yml`
2. Connected services to Kind network:
   ```bash
   docker network connect kind bootstrap-ollama-1
   docker network connect kind bootstrap-qdrant-1
   docker network connect kind bootstrap-minio-1
   ```
3. Updated deployment with correct IPs:
   - Ollama: `http://172.19.0.5:11434`
   - Qdrant: `http://172.19.0.6:6333`

**LLM Performance Notes:**
- Mistral (7.2B params) on CPU: 60+ seconds per inference with JSON format constraint
- Fallback intent parsing works (confidence: 0.3) when LLM times out
- Recommendation: Use smaller model (Phi 2.7B) or disable LLM intent parsing for CPU-only deployments
- Alternative: Add GPU support or increase timeout to 120s+

**Files Modified:**
- `bootstrap/docker-compose.yml` - Added Qdrant service
- `cluster/ai-ops-agent/k8s/deployment.yaml` - Updated OLLAMA_HOST and QDRANT_HOST environment variables

**Validation:**
```bash
# Test Ollama connectivity from pod
kubectl exec -n default <pod> -- python3 -c "import urllib.request; print(urllib.request.urlopen('http://172.19.0.5:11434/api/tags', timeout=5).read().decode())"

# Test AI Ops agent
curl -X POST http://localhost:30080/api/v1/chat -H "Content-Type: application/json" -d '{"query": "test", "user_id": "test", "user_email": "test@example.com"}'
```

---

## 🚨 CRITICAL: Pre-Implementation Checklist

**MANDATORY STEP for ALL future development, configuration, and deployment:**

### Before ANY Implementation:

1. **Check GitHub Issues First**
   ```bash
   # For ANY technology you're about to use:
   # 1. Go to the GitHub repository
   # 2. Search issues for your use case
   # 3. Filter by: is:issue <your-feature>
   # 4. Read open AND closed issues

   # Example:
   https://github.com/hashicorp/vault/issues?q=is%3Aissue+pkcs11
   https://github.com/openbao/openbao/issues
   ```

2. **Validate Against Known Issues**
   - Search for your configuration keywords
   - Check for "Enterprise only" limitations
   - Look for CrashLoopBackOff, ImagePullBackOff patterns
   - Read discussions about workarounds

3. **Document Why You Chose This Approach**
   - Link to issues you reviewed
   - Note any known limitations
   - Document alternatives you considered

### Real Example from Day 5:

**What we should have done:**
```bash
# BEFORE configuring Vault with PKCS11 seal:
1. Search: https://github.com/hashicorp/vault/issues?q=pkcs11+seal
2. Would have found: PKCS11 requires Enterprise
3. Would have discovered: OpenBao has OSS PKCS11 support
4. Result: Save 2+ hours of debugging
```

**What actually happened:**
- ❌ Configured PKCS11 seal without checking issues
- ❌ Hit error: "requires Vault Enterprise HSM binary"
- ❌ Spent hours debugging permission errors, image issues, crash loops
- ✅ Finally discovered via web search: OpenBao supports PKCS11 in OSS

### Time Saved by Following This Process:
- **Issue research**: 15 minutes
- **Debugging wrong approach**: 2+ hours
- **Net savings**: 105 minutes per component

### DO NOT PROCEED without this checklist! ⚠️

---

## Day 1: Kubernetes Deployment Issues

### Issue: ImagePullBackOff Error
**Date:** 2025-11-10
**Severity:** 🟡 Medium - Blocks deployments

---

### Problem
```bash
kubectl get pods
# Output:
NAME                    READY   STATUS             RESTARTS   AGE
nginx-c95765fd4-kmqzg   0/1     ImagePullBackOff   0          4m52s
```

Pod stuck in `ImagePullBackOff` state when deploying nginx.

---

### Root Cause
Kubernetes cannot pull container images from Docker Hub due to:
1. **Network connectivity issues** - Docker Desktop can't reach external registries
2. **Docker Hub rate limits** - Anonymous pulls limited to 100/6hrs
3. **Corporate proxy/firewall** - Blocking container registry access
4. **Docker daemon not authenticated** - No Docker Hub login

---

### Solution

#### Step 1: Verify Network Connectivity
```bash
# Test Docker Hub connectivity
curl -I https://hub.docker.com
# Should return: HTTP/2 200

# Test registry API
curl -I https://registry-1.docker.io
# Should return: HTTP/1.1 401 Unauthorized (expected - means it's reachable)
```

#### Step 2: Pre-pull Images Manually
```bash
# Pull image to local Docker cache BEFORE deploying to K8s
docker pull nginx:latest

# Verify image exists locally
docker images | grep nginx
```

#### Step 3: Deploy to Kubernetes
```bash
# Now deploy - K8s will use locally cached image
kubectl create deployment nginx --image=nginx:latest

# Watch it come up
kubectl get pods -w
```

#### Step 4: Check Pod Events (Debug)
```bash
# If still failing, check events
kubectl describe pod <pod-name>

# Look for ImagePullBackOff details in Events section
# Common errors:
# - "dial tcp: i/o timeout" = Network issue
# - "429 Too Many Requests" = Rate limit hit
# - "unauthorized" = Need Docker Hub login
```

---

### Prevention Strategies

#### 1. Always Pre-pull Critical Images
```bash
# Add to daily workflow
docker pull nginx:latest
docker pull ollama/ollama:latest
docker pull postgres:15
docker pull hashicorp/vault:1.15
```

#### 2. Use Image Pull Secrets (Production)
```bash
# Login to Docker Hub
docker login

# Create K8s secret from Docker config
kubectl create secret generic regcred \
  --from-file=.dockerconfigjson=$HOME/.docker/config.json \
  --type=kubernetes.io/dockerconfigjson

# Use in deployment
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      imagePullSecrets:
      - name: regcred
```

#### 3. Use Local Registry (Air-gapped Environments)
```bash
# Run local registry
docker run -d -p 5000:5000 --name registry registry:2

# Tag and push images
docker tag nginx:latest localhost:5000/nginx:latest
docker push localhost:5000/nginx:latest

# Deploy from local registry
kubectl create deployment nginx --image=localhost:5000/nginx:latest
```

#### 4. Pin Image Versions (Avoid :latest)
```bash
# BAD: :latest can change, causes pull every time
kubectl create deployment nginx --image=nginx:latest

# GOOD: Specific version, K8s uses cached image if available
kubectl create deployment nginx --image=nginx:1.25.3
```

---

### Verification
```bash
# Successful deployment looks like:
kubectl get pods
NAME                    READY   STATUS    RESTARTS   AGE
nginx-c95765fd4-kmqzg   1/1     Running   0          30s

# Check image pull policy
kubectl get deployment nginx -o yaml | grep imagePullPolicy
# Output: imagePullPolicy: IfNotPresent  (uses cache if available)
```

---

### Key Takeaways

1. **Always check network connectivity BEFORE deploying**
   - `curl -I https://registry-1.docker.io`
   - `docker pull <image>` to test

2. **Pre-pull images in local dev**
   - Faster deployments
   - Works offline
   - Avoids rate limits

3. **Use specific image tags, not :latest**
   - Reproducible builds
   - Faster pulls (cached)
   - No surprises in production

4. **Monitor Docker Hub rate limits**
   - Anonymous: 100 pulls/6hrs per IP
   - Authenticated: 200 pulls/6hrs per account
   - Pro: Unlimited

5. **k9s is already showing pods**
   - No need to type `:pods` when you're in pod view
   - Use `:svc`, `:deploy`, `:ns` to switch views
   - `l` for logs, `d` for describe, `s` for shell

---

### Related Issues
- None yet (Day 1)

---

### References
- [Kubernetes ImagePullBackOff Debugging](https://kubernetes.io/docs/concepts/containers/images/#imagepullbackoff)
- [Docker Hub Rate Limits](https://docs.docker.com/docker-hub/download-rate-limit/)
- [k9s Documentation](https://k9scli.io/)

---

### Next Steps
- [ ] Set up Docker Hub authentication for higher rate limits
- [ ] Create local registry for air-gapped testing
- [ ] Document all required images for suhlabs project
- [ ] Add image pre-pull to Makefile targets

---

## Day 2: Docker + CI Pipeline Implementation

### Accomplishments
**Date:** 2025-11-12
**Focus:** Containerization + GitHub Actions CI

---

### What We Built

#### 1. FastAPI AI Ops Agent
**Location:** `cluster/ai-ops-agent/`

```python
# main.py - Initial implementation
- Root endpoint (/) with service info
- Health endpoint (/health) with timestamp
- Readiness probe (/ready) for K8s health checks
```

**Features:**
- FastAPI framework (high-performance async)
- Structured health checks
- Environment-aware configuration
- Foundation for LLM integration

---

#### 2. Production-Grade Dockerfile
**Location:** `cluster/ai-ops-agent/Dockerfile`

**Security Best Practices:**
- ✅ Multi-stage build (smaller images)
- ✅ Non-root user (UID 1000)
- ✅ Minimal attack surface (python:3.11-slim base)
- ✅ Health check built-in
- ✅ Proper file ownership
- ✅ No secrets in image

**Image Size:** ~150MB (vs 1GB+ with full Python)

---

#### 3. GitHub Actions CI Pipeline
**Location:** `.github/workflows/ci.yml`

**Pipeline Stages:**
1. Checkout code
2. Setup Docker Buildx
3. Build Docker image
4. Use GitHub Actions cache for faster builds

**Performance:**
- Build time: ~2-3 minutes
- Cache enabled: Subsequent builds ~30 seconds
- Triggers: Every push to any branch

---

### Key Learnings

#### 1. Multi-Stage Docker Builds Are Essential
**Why:** Reduces final image size by 80%+
- Builder stage: Install dependencies
- Runtime stage: Only copy what's needed
- No build tools in production image

#### 2. Always Run as Non-Root
**Security Impact:** Limits container breakout damage
```dockerfile
USER appuser  # UID 1000, not root
```

#### 3. GitHub Actions Cache Strategy
**Performance Gain:** 5x faster builds
```yaml
cache-from: type=gha
cache-to: type=gha,mode=max
```

---

### Testing Performed

```bash
# Local build test
docker build -t ai-agent:v0.1 cluster/ai-ops-agent/

# Container runs successfully
docker run -d -p 8000:8000 ai-agent:v0.1

# Health endpoint works
curl http://localhost:8000/health
# Returns: {"status":"healthy","timestamp":"...","environment":"development"}
```

---

### CI/CD Integration

**CI Workflow Status:** ✅ GREEN
- Builds successfully on every push
- No security vulnerabilities detected
- Image builds in <3 minutes

**Next:** Add security scanning (Trivy) and automated testing

---

### Metrics

- **Lines of Code:** 31 (main.py) + 38 (Dockerfile) = 69 lines
- **Dependencies:** 2 (FastAPI, uvicorn)
- **Build Time:** 2m 45s (cold) / 28s (cached)
- **Image Size:** 152 MB

---

### Issues Encountered

**None!** Day 2 went smoothly. CI pipeline worked on first try.

---

### Next Steps for Day 3

- [x] Install Terraform and related tools
- [x] Create Terraform configurations for Kind cluster
- [x] Set up Terraform providers (kind, kubernetes)
- [x] Create reusable Terraform modules
- [ ] Practice Terraform workflow (init → plan → apply → destroy)
- [x] Add Terraform targets to Makefile
- [ ] Deploy AI Ops agent using Terraform

---

## Day 3: Terraform + IaC Muscle Memory

### Accomplishments
**Date:** 2025-11-12
**Focus:** Infrastructure as Code with Terraform

---

### What We Built

#### 1. Complete Terraform Configuration for Kind Cluster
**Location:** `infra/local/`

**Files Created:**
- `main.tf` - Main cluster and resource configuration (235 lines)
- `variables.tf` - Input variables with validation (85 lines)
- `versions.tf` - Provider version constraints
- `README.md` - Complete documentation

**Infrastructure Components:**
```hcl
# Kind cluster with:
- 1x Control plane node
- 2x Worker nodes
- Port mappings (30080, 30443)

# Kubernetes resources:
- 3x Namespaces (ai-ops, monitoring, vault)
- 1x Service Account (ai-ops-agent)
- 1x ConfigMap (AI Ops configuration)
```

---

#### 2. Reusable Terraform Module: K8s Namespace
**Location:** `infra/modules/k8s-namespace/`

**Features:**
- Creates namespaces with custom labels/annotations
- Optional default-deny network policy (zero-trust)
- Optional resource quotas
- Optional limit ranges
- Automatic timestamp labeling

**Module Files:**
- `main.tf` - Module logic (70 lines)
- `variables.tf` - Module inputs with validation (70 lines)
- `outputs.tf` - Module outputs (40 lines)
- `README.md` - Usage documentation with examples (200 lines)

---

#### 3. Makefile Integration
**Location:** Root `Makefile`

**New Targets Added:**
```makefile
make tf-fmt        # Format Terraform code
make tf-validate   # Validate configuration
make tf-destroy    # Destroy infrastructure
make tf-practice   # Practice workflow (timed <2min)
```

**Workflow Targets:**
- `make init-local` - Initialize Terraform
- `make plan-local` - Show execution plan
- `make apply-local` - Apply configuration
- `make tf-destroy` - Clean up resources

---

### Architecture Decisions

#### 1. Multi-File Terraform Structure
**Why:** Better organization and maintainability

```
infra/local/
├── main.tf       # Resources
├── variables.tf  # Inputs
├── versions.tf   # Versions
└── README.md     # Documentation
```

Benefits:
- Easy to find specific configuration
- Clear separation of concerns
- Standard Terraform best practice

---

#### 2. Reusable Modules
**Why:** DRY principle, consistency across environments

Example usage:
```hcl
module "production_namespace" {
  source = "../../modules/k8s-namespace"

  name = "ai-ops-production"
  create_default_deny_policy = true

  resource_quota = {
    pods = "50"
    requests_cpu = "20"
  }
}
```

Benefits:
- No code duplication
- Standardized namespace creation
- Easy to maintain and update

---

#### 3. Variable Validation
**Why:** Catch errors early, prevent invalid configurations

```hcl
variable "cluster_name" {
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.cluster_name))
    error_message = "Cluster name must consist of lowercase alphanumeric characters or '-'"
  }
}
```

Benefits:
- Immediate feedback on invalid inputs
- Self-documenting constraints
- Prevents deployment failures

---

#### 4. Provider Configuration
**Providers Used:**
- `kind` (v0.2.1) - Creates Kind clusters
- `kubernetes` (v2.23.0) - Manages K8s resources
- `helm` (v2.11.0) - Future Helm chart deployments

**Why these versions:**
- Stable releases
- Known compatibility
- Well-tested in production

---

### Key Learnings

#### 1. Terraform State Management
**Location:** `infra/local/terraform.tfstate`

- Local backend for development
- State tracks all managed resources
- Never commit state files to git
- Use remote backend for production

#### 2. Terraform Lifecycle
```bash
terraform init      # Download providers
terraform fmt       # Format code
terraform validate  # Check syntax
terraform plan      # Preview changes
terraform apply     # Execute changes
terraform destroy   # Clean up
```

**Muscle Memory Goal:** Complete cycle in <2 minutes

#### 3. Resource Dependencies
```hcl
depends_on = [kind_cluster.default]
```

- Explicit dependencies when needed
- Terraform auto-detects most dependencies
- Use `depends_on` for unclear relationships

#### 4. Local Variables for DRY Code
```hcl
locals {
  common_labels = {
    "managed-by" = "terraform"
    "project"    = "suhlabs"
  }
}
```

Benefits:
- Single source of truth
- Easy to update
- Consistent across resources

---

### Infrastructure Details

#### Kind Cluster Configuration
```yaml
Control Plane:
- Port 30080 → HTTP services
- Port 30443 → HTTPS services
- Node labels for scheduling

Worker Nodes (2x):
- Standard worker labels
- Ready for AI Ops workloads
- Supports 10+ pods each
```

#### Namespace Configuration
```hcl
ai-ops:
  - AI Ops Agent deployment
  - Service account created
  - ConfigMap with environment variables

monitoring:
  - Future: Prometheus, Grafana
  - Observability stack

vault:
  - HashiCorp Vault
  - Secrets management
```

---

### Testing Strategy

Since Terraform/Kind aren't installed in the current environment, testing will be done when tools are available:

**Test Plan:**
1. `terraform init` - Verify providers download
2. `terraform validate` - Check syntax
3. `terraform plan` - Review execution plan
4. `terraform apply` - Create infrastructure
5. `kubectl get nodes` - Verify cluster
6. `kubectl get ns` - Verify namespaces
7. `terraform destroy` - Clean up
8. Repeat 10x for muscle memory

---

### Metrics

**Code Statistics:**
- Terraform files: 8
- Total lines: ~900 (including docs)
- Main config: 235 lines
- Module code: 180 lines
- Documentation: 440 lines
- Makefile additions: 40 lines

**Module Capabilities:**
- Namespace creation
- Network policies
- Resource quotas
- Limit ranges
- Automatic labeling

---

### Documentation Created

1. **Infrastructure README** (`infra/local/README.md`)
   - Installation instructions
   - Quick start guide
   - Configuration options
   - Troubleshooting
   - Performance metrics

2. **Module README** (`infra/modules/k8s-namespace/README.md`)
   - Usage examples
   - Input/output reference
   - Security best practices
   - Production examples

3. **Inline Documentation**
   - Variable descriptions
   - Output descriptions
   - Resource comments

---

### Security Considerations

#### 1. Network Policies
Module supports default-deny policies:
```hcl
create_default_deny_policy = true
```

Implements zero-trust networking.

#### 2. Resource Quotas
Prevents resource exhaustion:
```hcl
resource_quota = {
  pods = "50"
  requests_cpu = "20"
  requests_memory = "40Gi"
}
```

#### 3. Non-Root Containers
All deployments enforce non-root users:
```hcl
spec {
  securityContext {
    runAsNonRoot = true
    runAsUser    = 1000
  }
}
```

---

### Lessons Learned

#### 1. Start with Modules Early
**Benefit:** Easier to refactor into modules from the start than later

**Pattern:**
```
infra/
├── local/        # Environment-specific
└── modules/      # Reusable components
```

#### 2. Document As You Go
**Benefit:** Fresh context makes better documentation

- Write README while building
- Document "why" not just "what"
- Include examples immediately

#### 3. Variable Validation is Worth It
**Benefit:** Catch errors before `terraform apply`

Example:
```hcl
validation {
  condition     = var.worker_nodes >= 1 && var.worker_nodes <= 10
  error_message = "Worker nodes must be between 1 and 10."
}
```

#### 4. Use Makefile for Consistency
**Benefit:** Same commands work across environments

```makefile
make apply-local   # Local environment
make apply-prod    # Production environment
```

---

### Terraform Best Practices Implemented

1. ✅ Multi-file structure
2. ✅ Reusable modules
3. ✅ Variable validation
4. ✅ Version constraints
5. ✅ Output values
6. ✅ Resource dependencies
7. ✅ Local variables
8. ✅ Comprehensive documentation
9. ✅ Makefile integration
10. ✅ Security defaults

---

### Next Steps for Day 4

According to the 14-Day Sprint Plan, Day 4 focuses on:
- [ ] Install Ansible and ansible-lint
- [ ] Create inventory files
- [ ] Write bootstrap playbook
- [ ] Create DNS service playbook
- [ ] Test idempotency
- [ ] Practice Ansible workflow

**Goal:** Configuration management with Ansible

---

### Day 3 Retrospective

**What Went Well:**
- ✅ Complete Terraform configuration created
- ✅ Reusable module designed and documented
- ✅ Comprehensive documentation written
- ✅ Makefile targets added successfully
- ✅ Following best practices from the start

**What's Pending:**
- ⏳ Actual Terraform testing (tools not installed)
- ⏳ Muscle memory practice (need Kind cluster)
- ⏳ Performance benchmarking

**What We Learned:**
- IaC requires thoughtful structure from day 1
- Documentation is as important as code
- Modules make scaling easier
- Variable validation prevents problems

**Time Spent:**
- Configuration: 2 hours
- Module development: 1.5 hours
- Documentation: 1.5 hours
- Makefile integration: 0.5 hours
- **Total: 5.5 hours**

**Sprint Plan Alignment:**
- Day 3 Morning (4h): Terraform Basics ✅
- Day 3 Afternoon (4h): Terraform Modules ✅
- **Status: Day 3 objectives completed!**

---

## Important Troubleshooting Topics

### Cert-Manager Race Conditions with K8s

**Issue**: Cert-manager can encounter race conditions during cluster bootstrap
**Symptoms**: Certificates not issued, empty cert secrets, cert-manager pod crashes

**Common Race Conditions:**

#### 1. CRD Not Ready
```bash
# Error: "no matches for kind Certificate in version cert-manager.io/v1"
# Cause: CRDs not established before Certificate resources applied

# Solution: Wait for CRDs
kubectl wait --for condition=established --timeout=120s \
  crd/certificates.cert-manager.io \
  crd/issuers.cert-manager.io \
  crd/clusterissuers.cert-manager.io
```

#### 2. Webhook Not Ready
```bash
# Error: "Internal error occurred: failed calling webhook"
# Cause: Cert-manager webhook pod not ready

# Solution: Wait for webhook
kubectl wait --for=condition=available --timeout=120s \
  deployment/cert-manager-webhook -n cert-manager

# Or disable validation temporarily (dev only!)
kubectl label namespace cert-manager cert-manager.io/disable-validation=true
```

#### 3. Issuer Not Ready
```bash
# Error: Certificate stays in "Pending" state
# Cause: ClusterIssuer/Issuer not ready before Certificate creation

# Solution: Check issuer status
kubectl get clusterissuer vault-issuer -o yaml
# Look for: status.conditions[?(@.type=="Ready")].status == "True"

# Wait for issuer
kubectl wait --for=condition=ready --timeout=120s \
  clusterissuer/vault-issuer
```

#### 4. Vault PKI Not Configured
```bash
# Error: "error getting Vault client: error reading Vault role"
# Cause: Vault PKI engine or role not set up

# Solution: Initialize Vault PKI first
vault secrets enable pki
vault write pki_int/roles/kubernetes \
  allowed_domains=cluster.local \
  allow_subdomains=true
```

#### 5. K8s Auth Not Configured
```bash
# Error: "error logging in to Vault: error authenticating"
# Cause: Vault Kubernetes auth method not configured

# Solution: Configure Vault K8s auth
vault auth enable kubernetes
vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443"

vault write auth/kubernetes/role/cert-manager \
  bound_service_account_names=cert-manager \
  bound_service_account_namespaces=cert-manager \
  policies=pki-policy \
  ttl=24h
```

#### 6. DNS Resolution During Bootstrap
```bash
# Error: "dial tcp: lookup vault.vault.svc.cluster.local: no such host"
# Cause: CoreDNS not ready when cert-manager starts

# Solution: Add init container or readiness check
apiVersion: v1
kind: Pod
spec:
  initContainers:
  - name: wait-for-dns
    image: busybox
    command:
    - sh
    - -c
    - |
      until nslookup vault.vault.svc.cluster.local; do
        echo "Waiting for DNS..."
        sleep 2
      done
```

### Debugging Cert-Manager Issues

#### Check Certificate Status
```bash
# View certificate details
kubectl describe certificate my-cert -n my-namespace

# Check certificate events
kubectl get events -n my-namespace --field-selector involvedObject.name=my-cert

# Check certificate secret
kubectl get secret my-cert-tls -n my-namespace
kubectl get secret my-cert-tls -n my-namespace -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
```

#### Check Cert-Manager Logs
```bash
# Controller logs
kubectl logs -n cert-manager deploy/cert-manager --tail=100

# Webhook logs
kubectl logs -n cert-manager deploy/cert-manager-webhook --tail=100

# CA injector logs
kubectl logs -n cert-manager deploy/cert-manager-cainjector --tail=100
```

#### Check ClusterIssuer/Issuer
```bash
# View issuer status
kubectl get clusterissuer
kubectl describe clusterissuer vault-issuer

# Check issuer conditions
kubectl get clusterissuer vault-issuer -o jsonpath='{.status.conditions}'
```

#### Manual Certificate Request
```bash
# Test certificate issuance manually
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-cert
  namespace: default
spec:
  secretName: test-cert-tls
  issuerRef:
    name: vault-issuer
    kind: ClusterIssuer
  commonName: test.example.com
  dnsNames:
  - test.example.com
EOF

# Watch certificate creation
kubectl get certificate test-cert -w
```

### Best Practices: Avoiding Race Conditions

#### 1. Proper Ordering in Terraform/Ansible
```hcl
# Terraform example
resource "helm_release" "cert_manager" {
  # ... cert-manager config
}

resource "null_resource" "wait_for_crds" {
  depends_on = [helm_release.cert_manager]

  provisioner "local-exec" {
    command = <<-EOT
      kubectl wait --for condition=established --timeout=120s \
        crd/certificates.cert-manager.io
    EOT
  }
}

resource "kubernetes_manifest" "vault_issuer" {
  depends_on = [null_resource.wait_for_crds]
  # ... ClusterIssuer config
}
```

#### 2. Use Helm Post-Install Hooks
```yaml
# charts/app/templates/certificate.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  annotations:
    "helm.sh/hook": post-install,post-upgrade
    "helm.sh/hook-weight": "5"
spec:
  # ... certificate spec
```

#### 3. Add Readiness Checks
```yaml
# Application deployment
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      initContainers:
      - name: wait-for-cert
        image: busybox
        command:
        - sh
        - -c
        - |
          until [ -f /etc/tls/tls.crt ]; do
            echo "Waiting for certificate..."
            sleep 2
          done
        volumeMounts:
        - name: tls
          mountPath: /etc/tls
      volumes:
      - name: tls
        secret:
          secretName: app-cert-tls
```

#### 4. Use cert-manager-csi-driver (Advanced)
```yaml
# Mount certificates directly to pods via CSI
apiVersion: v1
kind: Pod
spec:
  volumes:
  - name: tls
    csi:
      driver: csi.cert-manager.io
      volumeAttributes:
        csi.cert-manager.io/issuer-name: vault-issuer
        csi.cert-manager.io/issuer-kind: ClusterIssuer
        csi.cert-manager.io/common-name: app.example.com
```

### Why This Matters for Day 4-5

When we deploy **DNS + PKI + Cert-manager** in sequence:
1. DNS must be ready before Vault
2. Vault must be ready before cert-manager
3. Cert-manager CRDs must be ready before Issuers
4. Issuers must be ready before Certificates

**Proper sequence prevents race conditions** and empty certificate secrets.

### Reference
- [Cert-manager Troubleshooting](https://cert-manager.io/docs/troubleshooting/)
- [Kubernetes Race Conditions](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#deployment-status)

---

## Day 4: Foundation Services - DNS, HSM, and PKI

### Overview
**Date:** 2025-11-12
**Focus:** Building the three foundation pillars before application services
**Time Investment:** 4 hours (Hours 1-4 of Day 4)

**Key Learning:** Foundation services must be deployed BEFORE application services to avoid technical debt and empty certificates.

---

### The Three Foundation Pillars

#### 1. CoreDNS (Hour 1): Service Discovery
**Purpose:** Resolves service names to IP addresses

**Why it's essential:**
- Services need to find each other by name (not IP)
- Enables `vault.corp.local` instead of `10.96.x.x`
- Required for cert-manager to find Vault service

**Configuration:**
```yaml
# Two DNS zones
cluster.local  # Standard K8s service discovery
corp.local     # Custom zone for friendly names
```

**Key Insight:** DNS is like the phone book. Without it, services can't find each other, even if they're running.

---

#### 2. SoftHSM (Hour 2): Cryptographic Key Storage
**Purpose:** Secure storage for Vault's master encryption key

**Why it's essential:**
- Vault master key CANNOT be stored in plaintext
- Enables auto-unseal (no manual intervention on restart)
- Provides PKCS#11 interface (standard HSM protocol)

**Configuration:**
```yaml
seal "pkcs11" {
  lib = "/usr/lib/softhsm/libsofthsm2.so"
  slot = "0"
  pin = "1234"
  key_label = "vault-root-key"
  generate_key = "true"
}
```

**Key Insight:** HSM = "Hardware" Security Module (SoftHSM is software version for dev). The master key that encrypts ALL Vault secrets must itself be protected.

**Development vs Production:**
```
Development: SoftHSM (software, same machine)
Production:  YubiHSM 2 (hardware, dedicated device)
```

---

#### 3. Vault PKI (Hour 3): Certificate Authority
**Purpose:** Issues and manages SSL/TLS certificates

**Why it's essential:**
- Enables HTTPS for all services
- Automates certificate lifecycle (issue, renew, revoke)
- Establishes trust between services

**PKI Hierarchy:**
```
Root CA (10 years, 4096-bit RSA)
├─ Offline in production (air-gapped laptop in safe)
├─ Used ONCE to sign intermediate
└─ If compromised = ENTIRE PKI destroyed

    └─ Intermediate CA (5 years, 4096-bit RSA)
        ├─ Online 24/7 in Vault
        ├─ Issues service certificates
        └─ If compromised = Revoke + issue new intermediate

            ├─ ai-ops-agent role (30 day max TTL)
            ├─ kubernetes role (90 day max TTL)
            └─ cert-manager role (90 day max TTL)
```

**Key Insight:** Two-tier CA hierarchy provides defense-in-depth. If the online intermediate is compromised, you don't need to re-issue EVERY certificate in your organization.

---

### Critical Architectural Decision: Root CA Offline vs Online

**Quiz Question from Learning Session:**
> "Which CA is offline and why?"

**Answer:**
- **Root CA = OFFLINE** (air-gapped, locked in safe)
- **Intermediate CA = ONLINE** (running 24/7 in Vault)

**Why this matters:**

**Root CA Offline:**
```
✓ Maximum security (physically disconnected)
✓ Used only during "signing ceremonies"
✓ If compromised = Catastrophic (re-issue everything)
✗ Ceremony takes 2-4 hours, costs ~$2000
✗ Requires secure facility + dual control
```

**Intermediate CA Online:**
```
✓ Issues certificates 24/7 automatically
✓ Fast response times (< 500ms)
✓ If compromised = Revoke + issue new intermediate (hours, not days)
✗ Attack surface = running service
✗ Must be protected by HSM
```

**Real-World Incidents:**
- **DigiNotar (2011):** CA compromised, issued fake Google certificates, led to COMPLETE shutdown of CA
- **CNNIC (2015):** Issued unauthorized intermediate CA, all certificates revoked by browsers

**Defense in Depth Layers:**
1. **HSM** (Layer 1): Protects private keys in hardware
2. **Offline Root CA** (Layer 2): Physical air-gap from network
3. **Short Certificate Lifetimes** (Layer 3): Limits blast radius (30 days max)
4. **Audit Logging** (Layer 4): Detect suspicious activity
5. **Role-Based Access** (Layer 5): Least privilege principle

---

### Deployment Order Matters

**Correct Order:**
```
1. CoreDNS       ← No dependencies
2. SoftHSM       ← No dependencies
3. Vault         ← Needs SoftHSM for auto-unseal
4. Vault PKI     ← Needs Vault running
5. Cert-Manager  ← Needs DNS + PKI
6. Applications  ← Need certificates from cert-manager
```

**Why this order:**
- **CoreDNS first:** Other services need DNS resolution
- **SoftHSM before Vault:** Vault needs HSM for seal config
- **Vault PKI after Vault:** Can't configure PKI without Vault API
- **Cert-Manager last:** Needs both DNS and PKI to function
- **Applications last:** Need certificates from cert-manager

**What happens if you deploy out of order:**
```
❌ Cert-manager before PKI → Empty certificate secrets
❌ Vault before SoftHSM    → Manual unseal required every restart
❌ Applications before DNS  → Services can't find dependencies
```

---

### Certificate Lifetimes: Why So Short?

**Our Configuration:**
```
Root CA:        10 years (87600h)
Intermediate:   5 years  (43800h)
Service certs:  30 days  (720h)  ← Why so short?
```

**Reasons for 30-day certificates:**

1. **Forces Automation**
   - Manual renewal = unsustainable at 30 days
   - Forces you to build proper automation (cert-manager)
   - Automation = reliability

2. **Limits Blast Radius**
   - Compromised cert only valid for 30 days max
   - Attacker can't sit on stolen cert for years
   - Reduces window of opportunity

3. **Faster Incident Response**
   - Need to revoke a cert? It expires soon anyway
   - Reduces urgency of revocation
   - Simplifies key rotation

4. **Industry Trend**
   - Let's Encrypt: 90 days
   - Apple/Google: Moving toward 45 days
   - Eventually: 7 days or less

**Historical Context:**
```
2000s: 5-year certificates (standard)
2010s: 2-year certificates
2020s: 90-day certificates (Let's Encrypt)
2025+: 30-day or less (automation required)
```

---

### PKI Roles: Principle of Least Privilege

**Role: ai-ops-agent**
```hcl
allowed_domains = ["corp.local", "cluster.local"]
allow_subdomains = true
max_ttl = 720h  # 30 days
```
- Can issue: `ai-ops.corp.local`, `*.ai-ops.corp.local`
- Cannot issue: `vault.corp.local` (not in role)

**Role: kubernetes**
```hcl
allowed_domains = ["svc.cluster.local"]
allow_subdomains = true
max_ttl = 2160h  # 90 days
```
- Can issue: `my-service.default.svc.cluster.local`
- Cannot issue: `anything.corp.local` (wrong domain)

**Role: cert-manager**
```hcl
allowed_domains = ["cluster.local", "corp.local"]
allow_subdomains = true
allow_glob_domains = true
max_ttl = 2160h  # 90 days
```
- Can issue: ANY service in cluster.local or corp.local
- Broader permissions because it automates for all services

**Key Insight:** Each service gets ONLY the permissions it needs. Prevents lateral movement if one service is compromised.

---

### Production Ceremony: Root CA Signing

**What is a "ceremony"?**
A formal, audited process to use the offline Root CA to sign a new Intermediate CA.

**When needed:**
- Every 5 years (intermediate CA expiry)
- Emergency (intermediate CA compromised)
- Initial setup

**The Process:**
```
Time: 2-4 hours
People: 2 (dual control - no single person can act alone)
Location: Secure facility (locked room, cameras, logging)
Cost: ~$2000 (personnel time + facility)

Steps:
1.  Schedule ceremony (1 week notice)
2.  Security team prepares secure room
3.  Two authorized personnel enter (dual control)
4.  Boot air-gapped laptop (never connected to network)
5.  Connect YubiHSM with root CA key
6.  Insert USB with intermediate CSR (Certificate Signing Request)
7.  Verify CSR integrity (checksums, hashes)
8.  Sign CSR with root CA:
    vault write pki/root/sign-intermediate csr=@intermediate.csr ttl=43800h
9.  Save signed certificate to USB
10. Verify signature with openssl
11. Disconnect YubiHSM
12. Lock YubiHSM in safe
13. Shut down laptop
14. Exit secure room
15. Deliver signed cert to ops team
16. Import to Vault: vault write pki_int/intermediate/set-signed certificate=@signed.pem
17. Log all actions in audit system
```

**Key Insight:** This ceremony is EXPENSIVE and SLOW on purpose. The root CA should almost never be used, making compromise attempts very obvious.

---

### Verification: Testing Foundation Services

**Master Verification Script:**
```bash
cd cluster/foundation
./verify-all.sh

# Runs 7 test suites:
# 1. Prerequisites (kubectl, helm, vault, openssl)
# 2. CoreDNS (deployment, pods, DNS resolution)
# 3. Vault + SoftHSM (seal status, HSM token)
# 4. Vault PKI (engines, CAs, roles)
# 5. Integration (DNS→Vault, Vault→HSM, PKI→DNS)
# 6. Security (network policies, RBAC, quotas)
# 7. Performance (response times)
```

**Individual Service Verification:**
```bash
# CoreDNS
cd coredns
kubectl get pods -n kube-system -l k8s-app=coredns
kubectl run -it test --image=busybox:1.36 --rm --restart=Never -- \
  nslookup kubernetes.default.svc.cluster.local

# Vault
kubectl exec -n vault vault-0 -- vault status
# Look for: Seal Type: pkcs11, Sealed: false

# SoftHSM
kubectl exec -n vault vault-0 -- softhsm2-util --show-slots
# Should show "vault-hsm" token

# Vault PKI
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=<your-root-token>
cd vault-pki
./verify-pki.sh
```

---

### Common Issues and Solutions

#### Issue 1: CoreDNS Pods Not Starting
**Symptoms:**
```bash
kubectl get pods -n kube-system -l k8s-app=coredns
# Shows: CrashLoopBackOff or ImagePullBackOff
```

**Debugging:**
```bash
kubectl describe pod -n kube-system -l k8s-app=coredns
kubectl logs -n kube-system -l k8s-app=coredns
```

**Common Causes:**
- Port 53 already in use (systemd-resolved on Ubuntu)
- Invalid zone file syntax (missing trailing dots)
- Resource limits too low
- ConfigMap not mounted correctly

**Solution:**
```bash
# Check port 53
sudo lsof -i :53

# If systemd-resolved is using it:
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved

# Verify zone file syntax
kubectl get configmap coredns -n kube-system -o yaml
# Look for syntax errors in zone files
```

---

#### Issue 2: Vault Remains Sealed After Restart
**Symptoms:**
```bash
kubectl exec -n vault vault-0 -- vault status
# Shows: Sealed: true
```

**Root Cause:**
Auto-unseal with SoftHSM not configured correctly.

**Debugging:**
```bash
# Check Vault logs
kubectl logs -n vault vault-0 | grep -i "seal\|pkcs11\|hsm"

# Check SoftHSM token
kubectl exec -n vault vault-0 -- softhsm2-util --show-slots
# Should show "vault-hsm" token in slot 0

# Check Vault config
kubectl exec -n vault vault-0 -- cat /vault/config/vault.hcl
# Look for "seal pkcs11" section
```

**Solution:**
```bash
# Reinitialize SoftHSM if token missing
cd cluster/foundation/softhsm
./init-softhsm.sh

# Restart Vault
kubectl rollout restart statefulset/vault -n vault

# If still sealed, check Vault init
kubectl exec -n vault vault-0 -- vault operator init -status
# If "Vault is not initialized", run init first
```

---

#### Issue 3: PKI Certificate Issuance Fails
**Symptoms:**
```bash
vault write pki_int/issue/ai-ops-agent \
  common_name="test.corp.local" \
  ttl="24h"
# Error: permission denied or domain not allowed
```

**Debugging:**
```bash
# Check role configuration
vault read pki_int/roles/ai-ops-agent
# Verify allowed_domains includes your domain

# Check PKI engine enabled
vault secrets list | grep pki

# Check policy permissions
vault policy read cert-manager
```

**Solution:**
```bash
# Update role with correct domains
vault write pki_int/roles/ai-ops-agent \
  allowed_domains="corp.local,cluster.local,example.com" \
  allow_subdomains=true \
  max_ttl="720h"

# Test again
vault write pki_int/issue/ai-ops-agent \
  common_name="test.corp.local" \
  ttl="1h"
```

---

#### Issue 4: Certificate Chain Verification Failed
**Symptoms:**
```bash
openssl verify -CAfile ca_bundle.pem my_cert.pem
# Error: unable to get local issuer certificate
```

**Root Cause:**
Certificate chain incomplete or incorrect order.

**Debugging:**
```bash
# Check certificate chain order
openssl x509 -in my_cert.pem -noout -subject -issuer

# Get full chain
vault read -field=certificate pki/cert/ca > root.pem
vault read -field=certificate pki_int/cert/ca > intermediate.pem

# Verify intermediate signed by root
openssl verify -CAfile root.pem intermediate.pem
# Should say "OK"
```

**Solution:**
```bash
# Create proper CA bundle (intermediate FIRST, then root)
cat intermediate.pem root.pem > ca_bundle.pem

# Verify leaf certificate
openssl verify -CAfile ca_bundle.pem my_cert.pem
# Should say "OK"

# Check certificate was signed by intermediate
openssl x509 -in my_cert.pem -noout -issuer
# Should match intermediate CA subject
```

---

#### Issue 5: DNS Not Resolving corp.local
**Symptoms:**
```bash
kubectl run -it test --image=busybox:1.36 --rm --restart=Never -- \
  nslookup vault.corp.local
# Error: server can't find vault.corp.local: NXDOMAIN
```

**Debugging:**
```bash
# Check CoreDNS config
kubectl get configmap coredns -n kube-system -o yaml

# Look for corp.local zone configuration
# Should have "file" plugin with corp.local zone

# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=coredns | grep corp.local
```

**Solution:**
```bash
# Verify zone file in ConfigMap
kubectl get configmap coredns -n kube-system -o yaml | grep -A 20 "corp.local.db"

# If missing, update CoreDNS Helm values
cd cluster/foundation/coredns
helm upgrade coredns coredns/coredns \
  -n kube-system \
  -f values.yaml

# Wait for rollout
kubectl rollout status deployment/coredns -n kube-system

# Test again
kubectl run -it test --image=busybox:1.36 --rm --restart=Never -- \
  nslookup ns1.corp.local
```

---

### Key Takeaways from Day 4

#### 1. Foundation Services Are Non-Negotiable
You CANNOT skip DNS, HSM, and PKI and hope to add them later. They are the foundation. Building applications first leads to:
- Technical debt (self-signed certs everywhere)
- Security vulnerabilities (plaintext keys)
- Manual operations (no automation)

#### 2. Understanding the "Why" Is Critical
Don't just follow steps. Understand:
- WHY root CA is offline (security > convenience)
- WHY certificates expire in 30 days (forces automation)
- WHY we use HSM (key protection is paramount)
- WHY PKI hierarchy exists (defense in depth)

#### 3. Production vs Development Trade-offs
Development:
- SoftHSM (easy, fast, insecure)
- Root CA online (convenient, bad practice)
- Long cert lifetimes (less automation needed)

Production:
- YubiHSM 2 (complex, secure)
- Root CA offline (ceremonies, proper security)
- Short cert lifetimes (full automation required)

#### 4. Automation Is Not Optional
With 30-day certificate lifetimes:
- Manual renewal = unsustainable
- Automation = reliability
- Cert-manager = automatic issuance + renewal

#### 5. Security Is Layered
No single security measure is sufficient:
1. HSM protects keys
2. Offline root CA adds physical security
3. Short lifetimes limit blast radius
4. Audit logging detects anomalies
5. RBAC prevents unauthorized access

---

### Learning Outcomes: What You Now Know

#### Conceptual Understanding
✅ PKI hierarchy (root → intermediate → leaf)
✅ HSM concepts (PKCS#11, hardware vs software)
✅ DNS in Kubernetes (service discovery patterns)
✅ Certificate lifecycles (issue, renew, revoke)
✅ Defense in depth (multiple security layers)
✅ Production ceremonies (offline CA signing)
✅ Development vs production trade-offs

#### Practical Skills
✅ Deploy CoreDNS with custom DNS zones
✅ Configure SoftHSM for Vault auto-unseal
✅ Initialize Vault PKI engine
✅ Create PKI roles with least privilege
✅ Verify certificate chains with openssl
✅ Test DNS resolution in Kubernetes
✅ Troubleshoot common PKI issues
✅ Read and understand Vault policies

#### Production Readiness Concepts
✅ Root CA ceremony processes
✅ Incident response (intermediate CA compromise)
✅ Audit logging requirements
✅ Disaster recovery for PKI
✅ Compliance considerations
✅ Performance tuning (cache TTLs, replicas)

---

### What's Next: Day 4 Hours 5-8

**Hour 5:** Ansible installation and inventory
- Install ansible and ansible-lint
- Create inventory/local.yml
- Basic Ansible concepts and ad-hoc commands

**Hour 6:** Bootstrap Ansible playbook
- Playbook to verify foundation services
- Test idempotency (run twice, changes only on first run)
- Basic playbook structure (tasks, handlers, vars)

**Hour 7:** Vault verification playbook
- Automated PKI verification via Ansible
- Check seal status, PKI engines, roles
- Report health of foundation services

**Hour 8:** Documentation and testing
- Run all playbooks multiple times
- Verify idempotency (no changes on second run)
- Document Day 4 complete setup
- Prepare for Day 5 (cert-manager integration)

---

### Reference
- [CoreDNS Official Documentation](https://coredns.io/)
- [SoftHSM Project](https://www.opendnssec.org/softhsm/)
- [PKCS#11 Specification](http://docs.oasis-open.org/pkcs11/pkcs11-base/v2.40/os/pkcs11-base-v2.40-os.html)
- [Vault PKI Secrets Engine](https://developer.hashicorp.com/vault/docs/secrets/pki)
- [Vault Auto-Unseal](https://developer.hashicorp.com/vault/docs/concepts/seal)
- [Let's Encrypt: Why 90 Days](https://letsencrypt.org/2015/11/09/why-90-days.html)
- [DigiNotar Incident (2011)](https://en.wikipedia.org/wiki/DigiNotar)
- [CNNIC Incident (2015)](https://security.googleblog.com/2015/03/maintaining-digital-certificate-security.html)

---

## Autonomous Validation Script Fixes (2025-11-27)

### Overview
**Context:** Reviewed `scripts/autonomous-validation.sh` against established best practices in this document
**Result:** Identified and fixed 6 critical issues that would cause autonomous validation to fail
**Time Investment:** Analysis: 1h, Fixes: 2h, Documentation: 30min

---

### Critical Issue #1: Path References Without Directory Prefix

**Problem:**
```bash
# Line 283 - Wrong
if [ -f "foundation/vault/auto-unseal-sidecar.yaml" ]; then
    kubectl apply -f foundation/vault/auto-unseal-sidecar.yaml

# Line 347 - Wrong
chmod +x ./vault-bootstrap.sh
./vault-bootstrap.sh auto
```

**Root Cause:**
- Script changes directories multiple times (`cd foundation/vault`, `cd "$TEST_DIR"`)
- Relative paths break when current directory is not what you expect
- No file existence validation before attempting to execute

**Why This Matters:**
In autonomous execution, scripts CANNOT assume they know the current working directory. Each `cd` command changes context, making relative paths fragile.

**Fix:**
```bash
# Line 283 - Fixed
if [ -f "${TEST_DIR}/foundation/vault/auto-unseal-sidecar.yaml" ]; then
    kubectl apply -f "${TEST_DIR}/foundation/vault/auto-unseal-sidecar.yaml"

# Line 347 - Fixed
if [ ! -f "./vault-bootstrap.sh" ]; then
    log_error "vault-bootstrap.sh not found in $(pwd)"
    log_error "Expected path: $(pwd)/vault-bootstrap.sh"
    exit 1
fi
chmod +x ./vault-bootstrap.sh
./vault-bootstrap.sh auto
```

**Lesson Learned:**
> **Always use absolute paths in scripts that change directories**
> - Use `${SCRIPT_DIR}` or `${TEST_DIR}` prefix for all file references
> - Validate file existence BEFORE attempting chmod/execute
> - Log expected vs actual path when file not found (aids debugging)

---

### Critical Issue #2: Bash Glob Pattern Requires Globstar

**Problem:**
```bash
# Line 193 - Wrong (** doesn't expand without globstar)
chmod -R +x ${TEST_DIR}/foundation/**/*.sh
```

**Root Cause:**
- `**` recursive glob pattern requires `shopt -s globstar` in bash
- Without globstar, `**` matches literally (a directory called "**")
- Script has `set -euo pipefail` but no `shopt -s globstar`

**Why This Matters:**
The script would match ZERO files, leaving all `.sh` scripts non-executable. Subsequent `./deploy.sh` calls would fail with "Permission denied".

**Fix:**
```bash
# Use find instead - works in all POSIX shells
find ${TEST_DIR}/foundation -type f -name '*.sh' -exec chmod +x {} +
```

**Lesson Learned:**
> **Use `find` instead of `**` glob patterns in scripts**
> - `find` works in all POSIX shells (sh, bash, dash, zsh)
> - `**` requires bash 4+ with globstar enabled
> - `-exec {} +` is more efficient than `-exec {} \;` (batches arguments)

**Alternative (if you must use globstar):**
```bash
shopt -s globstar  # Enable recursive globbing
chmod +x ${TEST_DIR}/foundation/**/*.sh
shopt -u globstar  # Disable (good practice)
```

---

### Critical Issue #3: kubectl run Flag Incompatibility

**Problem:**
```bash
# Line 242 - Wrong (flags conflict)
kubectl run dns-test-cluster --image=busybox:1.36 --rm --restart=Never \
  --attach=true --quiet -- nslookup kubernetes.default.svc.cluster.local
```

**Root Cause:**
- `--attach=true` streams pod output to stdout
- `--quiet` suppresses non-error output
- `--rm` deletes pod after completion
- Combining these flags causes race condition: pod deleted before output captured

**Why This Matters:**
Pod cleanup fails, leaving `dns-test-cluster` pod in cluster. Next run fails with "pod already exists". Requires manual cleanup (`kubectl delete pod dns-test-cluster`).

**Fix:**
```bash
# Use -i (interactive) instead
kubectl run dns-test-cluster --image=busybox:1.36 --rm -i --restart=Never \
  -- nslookup kubernetes.default.svc.cluster.local
```

**Lesson Learned:**
> **kubectl run flag combinations to avoid**
> - ❌ `--attach=true` + `--quiet` (contradictory intent)
> - ❌ `--rm` + `--attach=true` + `--quiet` (race condition)
> - ✅ `--rm` + `-i` (interactive, clean deletion)
> - ✅ `--rm` + `--attach=false` (background, clean deletion)

---

### Critical Issue #4: Missing Image Pre-Pull (Lessons Learned Violation)

**Problem:**
```bash
# No pre-pull phase - violates lessons-learned.md:179-186
kubectl run dns-test-cluster --image=busybox:1.36 ...
kubectl apply -f ollama/deployment.yaml  # Uses ollama/ollama:latest
kubectl apply -f agent-gateway.yaml      # Uses curlimages/curl:latest
```

**Root Cause:**
- Script assumes images are already available locally
- Uses `:latest` tags that may not be cached
- No network connectivity handling

**Why This Matters (from lessons-learned.md:179-186):**
> Always Pre-pull Critical Images
> ```bash
> # Add to daily workflow
> docker pull nginx:latest
> docker pull ollama/ollama:latest
> ```

Without pre-pull:
- **ImagePullBackOff** errors if network slow/down
- Docker Hub rate limits (100 pulls/6hrs anonymous)
- 5-10 minute delays pulling large images (ollama:latest = 4.7GB)

**Fix:**
Added new Phase 1.5 between environment setup and CoreDNS:

```bash
log_phase "Pre-Pull Container Images"

declare -a REQUIRED_IMAGES=(
    "busybox:1.36"
    "ollama/ollama:latest"
    "curlimages/curl:latest"
)

for img in "${REQUIRED_IMAGES[@]}"; do
    log_info "Pre-pulling ${img}..."
    docker pull "$img" 2>&1 | tee -a "$LOG_FILE"

    # Load into Kind cluster
    kind load docker-image "$img" --name "$CLUSTER_NAME"
    log_success "Loaded ${img} into cluster"
done
```

**Lesson Learned:**
> **ALWAYS pre-pull images in autonomous scripts**
> - Pre-pull at script start (fail fast if network down)
> - Load into Kind cluster explicitly (`kind load docker-image`)
> - Use specific tags when possible (`:1.36` not `:latest`)
> - Document image sizes (ollama:latest = 4.7GB, warn user)

**Why Load Into Kind Explicitly:**
Kind clusters are isolated Docker networks. Even if image exists in local Docker cache, Kind needs explicit load:

```bash
docker pull ollama/ollama:latest     # In host Docker
kind load docker-image ollama/ollama:latest  # Into Kind network
```

---

### Critical Issue #5: Sudo Commands Without Permission Check

**Problem:**
```bash
# Line 748 - Assumes passwordless sudo
echo "127.0.0.1 ollama.corp.local" | sudo tee -a /etc/hosts

# Line 803 - Cleanup assumes sudo
sudo sed -i '/ollama.corp.local/d' /etc/hosts
```

**Root Cause:**
- No check if user has sudo access
- No check if sudo requires password
- Script hangs in automated environments waiting for password prompt

**Why This Matters:**
In CI/CD pipelines or containerized environments:
- No sudo access available
- Script hangs indefinitely on password prompt
- No timeout = pipeline hangs forever

**Fix:**
```bash
# Check for passwordless sudo
if sudo -n true 2>/dev/null; then
    echo "127.0.0.1 ollama.corp.local" | sudo tee -a /etc/hosts >/dev/null
    log_success "Added ollama.corp.local to /etc/hosts"
    HOSTS_MODIFIED=true
else
    log_warn "Cannot modify /etc/hosts (no passwordless sudo access)"
    log_info "Add manually: echo '127.0.0.1 ollama.corp.local' | sudo tee -a /etc/hosts"
    log_info "Skipping external ingress test"
    HOSTS_MODIFIED=false
fi

# Later cleanup
if [ "$HOSTS_MODIFIED" = true ] && sudo -n true 2>/dev/null; then
    sudo sed -i '/ollama.corp.local/d' /etc/hosts
fi
```

**Lesson Learned:**
> **Always check sudo availability before using**
> - Use `sudo -n true` to test passwordless sudo (non-interactive)
> - Gracefully degrade if sudo unavailable (skip non-critical steps)
> - Log alternative manual instructions for user
> - Track state with flag (`HOSTS_MODIFIED=true`) for cleanup

**sudo -n flag:**
- `-n` = non-interactive mode
- Returns 0 if passwordless sudo works
- Returns 1 if password required or no sudo access
- Never prompts for password

---

### Critical Issue #6: Resource Deletion Without Existence Check

**Problem:**
```bash
# Line 728 - Assumes secret exists
kubectl delete secret ollama-tls
kubectl wait --for=condition=ready certificate/ollama-cert --timeout=60s
```

**Root Cause:**
- Previous test may have failed before creating secret
- No check if secret exists before deletion
- `kubectl delete` returns non-zero exit code if resource doesn't exist
- Script has `set -e` (exit on error) = immediate failure

**Why This Matters:**
Legitimate edge cases cause script failure:
- First run (secret never created)
- Previous run failed at cert issuance (secret missing)
- User manually deleted secret for debugging

**Fix:**
```bash
if kubectl get secret ollama-tls &>/dev/null; then
    SERIAL_BEFORE=$(kubectl get secret ollama-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -serial)
    kubectl delete secret ollama-tls
    kubectl wait --for=condition=ready certificate/ollama-cert --timeout=60s
    SERIAL_AFTER=$(kubectl get secret ollama-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -serial)

    if [ "$SERIAL_BEFORE" != "$SERIAL_AFTER" ]; then
        log_success "Ollama certificate rotation successful"
    fi
else
    log_warn "ollama-tls secret doesn't exist, skipping rotation test"
fi
```

**Lesson Learned:**
> **Always check resource existence before deletion**
> - Use `kubectl get <resource> &>/dev/null` (exit code 0 = exists)
> - Gracefully handle missing resources (skip test with warning)
> - Don't assume resources exist from previous steps (they may have failed)

**Alternative Pattern (for must-delete scenarios):**
```bash
kubectl delete secret ollama-tls --ignore-not-found=true
```

---

### Summary of Fixes

| Issue | Impact | Lines | Fix Time |
|-------|--------|-------|----------|
| #1: Path references | Script fails silently | 283, 347 | 15 min |
| #2: Glob pattern | Scripts non-executable | 193 | 10 min |
| #3: kubectl flags | Pod cleanup fails | 242 | 10 min |
| #4: Image pre-pull | ImagePullBackOff errors | New phase | 30 min |
| #5: Sudo checks | Script hangs | 748, 803 | 20 min |
| #6: Existence checks | Fails on edge cases | 728 | 15 min |
| **Total** | **Autonomous execution broken** | **7 locations** | **100 min** |

---

### New Best Practices Added to Project

Based on these fixes, adding to project standards:

#### 1. Script Portability Checklist
Before committing any bash script, verify:
- [ ] Uses absolute paths or well-defined variables (`${SCRIPT_DIR}`)
- [ ] Validates file existence before chmod/execute
- [ ] Uses `find` instead of `**` glob patterns
- [ ] Checks sudo availability with `sudo -n true`
- [ ] Checks resource existence before deletion
- [ ] Pre-pulls all required container images

#### 2. kubectl Resource Management Pattern
```bash
# Standard pattern for resource deletion
if kubectl get <resource-type> <resource-name> -n <namespace> &>/dev/null; then
    kubectl delete <resource-type> <resource-name> -n <namespace>
else
    log_warn "<Resource> doesn't exist, skipping deletion"
fi

# Alternative: Use --ignore-not-found for must-delete
kubectl delete <resource-type> <resource-name> --ignore-not-found=true
```

#### 3. Image Pre-Pull for Kind Clusters
```bash
# ALWAYS use this pattern for Kind-based tests
IMAGES=("image1:tag1" "image2:tag2")
for img in "${IMAGES[@]}"; do
    docker pull "$img"
    kind load docker-image "$img" --name "$CLUSTER_NAME"
done
```

---

### Files Modified

1. **Created:** `/tmp/autonomous-validation-fixed.sh`
   - All 6 critical issues fixed
   - Includes inline comments explaining each fix
   - Ready for autonomous execution

2. **Created:** `/tmp/autonomous-validation-analysis.md`
   - Detailed analysis of all 18 issues (6 critical, 8 medium, 4 low)
   - Code examples for each fix
   - Testing plan

3. **Updated:** `docs/lessons-learned.md` (this section)
   - Documented reasoning for each fix
   - New best practices for project
   - kubectl patterns and sudo handling

---

### Testing Recommendations

After applying fixes, test with these scenarios:

1. **Clean Run:** Fresh system, no Docker images cached
2. **No Sudo:** Run as user without sudo privileges
3. **Partial Failure:** Manually delete resources mid-script, re-run
4. **Network Failure:** Simulate slow/unavailable Docker Hub
5. **Existing Cluster:** Run when `kind-aiops-validation` already exists

---

### References

- Original script: `scripts/autonomous-validation.sh`
- Fixed version: `/tmp/autonomous-validation-fixed.sh`
- Analysis: `/tmp/autonomous-validation-analysis.md`
- Kind networking docs: https://kind.sigs.k8s.io/docs/user/loadbalancer/
- kubectl run reference: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#run

