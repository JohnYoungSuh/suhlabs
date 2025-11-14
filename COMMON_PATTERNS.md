# Common Deployment Patterns
## Reusable Solutions for Infrastructure Deployment

**Purpose**: Quick-reference patterns to copy/paste for common scenarios. Updated as new patterns are discovered.

---

## Pattern: cert-manager Certificate with Wait

**Use Case**: Any pod that mounts a cert-manager certificate

**Problem**: Pod tries to mount secret before cert-manager creates it

**Solution**: Two-layer defense

### Layer 1: Deploy Script
```bash
#!/bin/bash
# Apply Certificate first
kubectl apply -f certificate.yaml

# Wait for Certificate to be ready
echo "Waiting for certificate to be issued..."
until kubectl get certificate mycert -n default -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q "True"; do
  echo "Waiting..."
  sleep 5
done

# Verify secret exists
kubectl get secret mycert-tls -n default

# NOW deploy the pod
kubectl apply -f deployment.yaml
```

### Layer 2: Init Container
```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      initContainers:
      - name: wait-for-certificate
        image: bitnami/kubectl:1.28
        command:
        - sh
        - -c
        - |
          echo "Waiting for certificate mycert to be ready..."
          until kubectl get certificate mycert -n default -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q "True"; do
            sleep 5
          done

      containers:
      - name: app
        volumeMounts:
        - name: tls
          mountPath: /etc/tls

      volumes:
      - name: tls
        secret:
          secretName: mycert-tls
```

**Reference**: `cluster/ai-ops-agent/LESSONS_LEARNED.md`

---

## Pattern: Vault PKI Certificate DNS Names

**Use Case**: Creating Certificate for Vault PKI issuer

**Problem**: Vault rejects certificate due to DNS names not matching allowed_domains

**Solution**: Check role first, use only allowed FQDNs

### Step 1: Check Vault PKI Role
```bash
# Port forward to Vault
kubectl port-forward -n vault svc/vault 8200:8200 &

export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=<your-root-token>

# Check role configuration
vault read pki_int/roles/ai-ops-agent

# Look for:
# - allowed_domains: ["corp.local", "cluster.local"]
# - allow_subdomains: true
# - allow_bare_domains: false
```

### Step 2: Create Certificate with Matching DNS Names
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: myservice-cert
spec:
  # IMPORTANT: Only FQDNs matching allowed_domains
  # Role allows: *.corp.local, *.cluster.local
  commonName: myservice.default.svc.cluster.local
  dnsNames:
    - myservice.default.svc.cluster.local  # ✅ Matches *.cluster.local
    - myservice.corp.local                  # ✅ Matches *.corp.local
    # DO NOT ADD:
    # - myservice                          # ❌ Bare hostname
    # - myservice.default                  # ❌ Not allowed domain
```

**Reference**: `cluster/ai-ops-agent/LESSONS_LEARNED.md`

---

## Pattern: Kubernetes 1.24+ Service Account Token RBAC

**Use Case**: cert-manager authenticating with Vault on Kubernetes 1.24+

**Problem**: cert-manager can't create service account tokens for Vault auth

**Solution**: Add ClusterRole for token creation

```yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cert-manager-vault-token-access
rules:
- apiGroups: [""]
  resources: ["serviceaccounts/token"]
  verbs: ["create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cert-manager-vault-token-access
roleRef:
  kind: ClusterRole
  name: cert-manager-vault-token-access
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  name: cert-manager
  namespace: cert-manager
```

**Reference**: cert-manager issue #6673

---

## Pattern: Helm Chart Metadata for Kubernetes 1.24+

**Use Case**: Adopting existing resources with Helm on Kubernetes 1.24+

**Problem**: Helm can't adopt resources without explicit metadata

**Solution**: Add required labels and annotations

```yaml
# For Helm charts
customLabels:
  app.kubernetes.io/managed-by: Helm

customAnnotations:
  meta.helm.sh/release-name: myrelease
  meta.helm.sh/release-namespace: mynamespace
```

**Reference**: `cluster/foundation/coredns/LESSONS_LEARNED.md`

---

## Pattern: Service Selector Debugging

**Use Case**: Service not routing traffic to pods

**Problem**: Service selector doesn't match pod labels

**Solution**: Systematic validation

### Check 1: Compare Labels
```bash
# Get service selector
kubectl get svc myservice -o jsonpath='{.spec.selector}'

# Get pod labels
kubectl get pods -l app=myapp --show-labels

# They must match exactly!
```

### Check 2: Verify Endpoints
```bash
# Service endpoints should show pod IPs
kubectl get endpoints myservice

# If empty, selector mismatch
# If has IPs, service is working
```

### Check 3: Test from Within Cluster
```bash
# Use debug pod
kubectl run -it --rm debug --image=nicolaka/netshoot -- bash

# Test service DNS
nslookup myservice.namespace.svc.cluster.local

# Test service connectivity
curl http://myservice.namespace.svc.cluster.local:port
```

**Reference**: `cluster/foundation/coredns/LESSONS_LEARNED.md`

---

## Pattern: Deployment Order with Dependencies

**Use Case**: Deploying resources with dependencies

**Anti-Pattern**: Apply everything at once
```bash
kubectl apply -f .  # ❌ Race conditions
```

**Best Practice**: Apply in dependency order
```bash
# 1. Namespace and RBAC
kubectl apply -f namespace.yaml
kubectl apply -f rbac.yaml

# 2. Secrets and ConfigMaps
kubectl apply -f secrets.yaml
kubectl apply -f configmaps.yaml

# 3. Certificates (if using cert-manager)
kubectl apply -f certificates.yaml
kubectl wait --for=condition=Ready certificate/mycert --timeout=120s

# 4. StatefulSets and PVCs
kubectl apply -f statefulset.yaml
kubectl wait --for=condition=Ready pod -l app=myapp --timeout=120s

# 5. Services
kubectl apply -f service.yaml

# 6. Deployments
kubectl apply -f deployment.yaml
kubectl rollout status deployment/myapp

# 7. Ingress (last)
kubectl apply -f ingress.yaml
```

---

## Pattern: Pre-Deployment Validation Checklist

**Use Case**: Before deploying ANYTHING

```bash
#!/bin/bash
# Pre-deployment validation script

echo "=== Pre-Deployment Validation ==="

# 1. Check prerequisites
echo "Checking prerequisites..."
kubectl get namespace mynamespace || { echo "Namespace missing"; exit 1; }

# 2. Validate YAML syntax
echo "Validating YAML..."
kubectl apply --dry-run=client -f deployment.yaml

# 3. Check for required secrets
echo "Checking secrets..."
kubectl get secret mysecret -n mynamespace || { echo "Secret missing"; exit 1; }

# 4. Validate resource quotas
echo "Checking resource quotas..."
kubectl describe resourcequota -n mynamespace

# 5. Check for conflicts
echo "Checking for existing resources..."
kubectl get deployment myapp -n mynamespace && { echo "Deployment already exists"; exit 1; }

# 6. Validate selectors
echo "Validating selectors..."
# (Add selector validation logic)

echo "✅ Pre-deployment validation passed!"
```

---

## Pattern: Incremental Testing

**Use Case**: Testing complex deployments

**Bad**: Deploy everything, debug when it breaks
```bash
kubectl apply -f .
# ❌ 50 resources created, good luck debugging
```

**Good**: Test incrementally
```bash
# Step 1: Single pod with minimal config
kubectl run test --image=myimage --dry-run=client -o yaml > test.yaml
# Edit to minimal configuration
kubectl apply -f test.yaml
kubectl logs test
# Verify it works

# Step 2: Add one feature at a time
# Add volume mount → test
# Add environment variables → test
# Add resource limits → test
# Add health probes → test

# Step 3: Convert to full deployment
# Now you know each component works
kubectl apply -f deployment.yaml
```

---

## Pattern: Documentation Before Implementation

**Use Case**: Planning any infrastructure change

**Template**:
```markdown
# Change Proposal: [Feature Name]

## Objective
What are we trying to achieve?

## Current State
How does it work now?

## Proposed State
How will it work after this change?

## Prerequisites
- [ ] Vault is running and unsealed
- [ ] cert-manager is installed
- [ ] Namespace exists

## Dependencies
- Service A must be deployed first
- Certificate must be issued before pod starts

## Risks
1. Risk: Pod fails to start
   - Mitigation: Use init container to wait for dependencies

2. Risk: DNS names not allowed by Vault
   - Mitigation: Check Vault PKI role first

## Validation Plan
1. Test certificate issuance manually
2. Test pod startup with minimal config
3. Test with full configuration
4. Test failure scenarios

## Rollback Plan
If deployment fails:
1. Delete deployment: kubectl delete -f deployment.yaml
2. Check logs: kubectl logs -l app=myapp
3. Fix issue and retry

## Success Criteria
- [ ] Certificate issued (kubectl get certificate)
- [ ] Pod running (kubectl get pods)
- [ ] Service accessible (curl http://service:port)
```

---

## Pattern: Error Message Investigation

**Use Case**: Debugging Kubernetes errors

**Process**:

### 1. Get Full Error Context
```bash
# Don't just look at pod status
kubectl get pods

# Get full event history
kubectl describe pod mypod

# Get container logs
kubectl logs mypod
kubectl logs mypod --previous  # Previous container

# Get events in namespace
kubectl get events --sort-by='.lastTimestamp'
```

### 2. Search Documentation
```bash
# Copy exact error message
# Search in official docs
# Search in GitHub issues
# Search in Stack Overflow

# Example:
# Error: "subject alternate name ai-ops-agent not allowed"
# → Search "vault pki allowed domains"
# → Find official docs on allowed_domains configuration
```

### 3. Validate Assumptions
```bash
# Don't assume configuration is correct
# Check actual values

# Example:
vault read pki_int/roles/ai-ops-agent
# See what's actually configured, not what you think
```

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Apply Without Testing
```bash
# ❌ BAD
git commit -m "Add deployment"
git push
kubectl apply -f deployment.yaml
# Hope it works

# ✅ GOOD
kubectl apply --dry-run=client -f deployment.yaml
kubectl apply -f deployment.yaml
kubectl wait --for=condition=available deployment/myapp
kubectl logs -l app=myapp
# Verify it actually works
```

### Anti-Pattern 2: Ignore Warnings
```bash
# ❌ BAD
kubectl apply -f deployment.yaml
# Warning: spec.selector is immutable
# "It's just a warning, probably fine"

# ✅ GOOD
# If there's a warning, investigate
# Warnings often indicate future problems
```

### Anti-Pattern 3: Fix-Forward Without Understanding
```bash
# ❌ BAD
# Error occurs
# Try random fixes until it works
# Don't understand why it works

# ✅ GOOD
# Error occurs
# Understand root cause
# Fix the root cause
# Document why it happened
# Update patterns to prevent recurrence
```

### Anti-Pattern 4: Assume Documentation is Wrong
```bash
# ❌ BAD
# "The docs say to do X, but I'll try Y"
# (Wastes time when Y doesn't work)

# ✅ GOOD
# Follow documentation exactly first
# If it doesn't work, THEN investigate why
# Document discrepancy if docs are actually wrong
```

---

## Quick Commands Reference

### Certificate Debugging
```bash
# Check certificate status
kubectl get certificate mycert -o wide

# Check certificate request
kubectl get certificaterequest

# Check cert-manager logs
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager | grep mycert

# Describe for detailed error
kubectl describe certificate mycert
```

### Service Debugging
```bash
# Check service
kubectl get svc myservice

# Check endpoints (should show pod IPs)
kubectl get endpoints myservice

# Check service selector
kubectl get svc myservice -o jsonpath='{.spec.selector}'

# Check pod labels
kubectl get pods --show-labels -l app=myapp
```

### Vault PKI Commands
```bash
# Check role configuration
vault read pki_int/roles/myservice

# Test certificate signing
vault write pki_int/sign/myservice \
  common_name="test.corp.local" \
  ttl="1h"

# List roles
vault list pki_int/roles
```

---

## Next Patterns to Add

As we encounter new scenarios, add patterns for:

- [ ] Blue-green deployments
- [ ] Canary deployments
- [ ] Database migrations
- [ ] Zero-downtime updates
- [ ] Disaster recovery
- [ ] Monitoring and alerting
- [ ] GitOps workflows
- [ ] Multi-cluster deployments

---

**Last Updated**: Session 1, November 2024
**Usage**: Copy patterns as needed, adapt to your use case
**Contribution**: Add new patterns as you discover them
