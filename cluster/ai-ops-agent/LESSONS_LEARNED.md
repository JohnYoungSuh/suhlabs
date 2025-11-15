# Lessons Learned: cert-manager Race Condition

## Problem

**Race Condition**: Deployment tries to mount TLS certificate secret before cert-manager has created it.

### Error Message
```
Warning  FailedMount  33s (x10 over 5m4s)  kubelet
  MountVolume.SetUp failed for volume "tls" : secret "ai-ops-agent-tls" not found

Warning  FailedMount  20s (x2 over 2m50s)  kubelet
  Unable to attach or mount volumes: unmounted volumes=[tls], unattached volumes=[],
  failed to process volumes=[]: timed out waiting for the condition
```

### Timeline of Events

1. **T+0s**: `kubectl apply` creates Certificate, Service, and Deployment simultaneously
2. **T+1s**: Deployment controller creates Pod
3. **T+2s**: Pod tries to mount secret `ai-ops-agent-tls` → **FAILS** (secret doesn't exist yet)
4. **T+3s**: cert-manager processes Certificate resource
5. **T+5s**: cert-manager requests certificate from Vault PKI
6. **T+10s**: Vault signs certificate
7. **T+12s**: cert-manager creates secret `ai-ops-agent-tls`
8. **T+15s**: Pod still failing to mount (kubelet has given up retrying)

### Root Cause

Kubernetes applies resources in parallel. The Deployment is created and starts pods **before** cert-manager has time to:
1. Process the Certificate CRD
2. Request certificate from Vault
3. Create the Secret with the certificate

This creates a race condition where the pod tries to mount a secret that doesn't exist yet.

## Solution

**Two-Layer Defense**:

### Layer 1: Deployment Script Ordering

**Apply Certificate first, wait for it, then apply Deployment:**

```bash
# Step 1: Apply Certificate resource
kubectl apply -f certificate.yaml

# Step 2: Wait for certificate to be ready
until kubectl get certificate ai-ops-agent-cert -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep -q "True"; do
  echo "Waiting for certificate..."
  sleep 5
done

# Step 3: Verify secret exists
kubectl get secret ai-ops-agent-tls

# Step 4: NOW apply deployment (secret is guaranteed to exist)
kubectl apply -f deployment.yaml
```

### Layer 2: Init Container (Defense in Depth)

**Add init container to wait for certificate even if deployment script fails:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ai-ops-agent
spec:
  template:
    spec:
      # Init container waits for certificate before main container starts
      initContainers:
      - name: wait-for-certificate
        image: bitnami/kubectl:latest
        command:
        - sh
        - -c
        - |
          echo "Waiting for certificate ai-ops-agent-cert to be ready..."
          until kubectl get certificate ai-ops-agent-cert -n default -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q "True"; do
            echo "Certificate not ready yet, waiting 5 seconds..."
            sleep 5
          done
          echo "Certificate is ready! Proceeding with pod startup."

      containers:
      - name: ai-ops-agent
        # ... main container ...
        volumeMounts:
        - name: tls
          mountPath: /etc/tls
          readOnly: true

      volumes:
      - name: tls
        secret:
          secretName: ai-ops-agent-tls  # Now guaranteed to exist
```

## Why Both Layers?

**Layer 1 (Script)**:
- Prevents race condition during automated deployments
- Faster - no pod restarts needed
- Better user experience (no confusing error messages)

**Layer 2 (Init Container)**:
- Protects against manual `kubectl apply` (when someone applies deployment directly)
- Works even if Layer 1 is skipped
- Self-healing - pod will eventually start when certificate is ready

## Pattern: Always Wait for cert-manager

**This pattern applies to ANY deployment using cert-manager certificates:**

```yaml
# WRONG - Race condition likely
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: app
        volumeMounts:
        - name: tls
          mountPath: /etc/tls
      volumes:
      - name: tls
        secret:
          secretName: my-app-tls  # May not exist yet!

---
# RIGHT - Init container prevents race
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      initContainers:
      - name: wait-for-certificate
        image: bitnami/kubectl:latest
        command: ['sh', '-c', 'until kubectl get certificate my-cert -o jsonpath="{.status.conditions[?(@.type==\"Ready\")].status}" | grep -q "True"; do sleep 5; done']

      containers:
      - name: app
        volumeMounts:
        - name: tls
          mountPath: /etc/tls
      volumes:
      - name: tls
        secret:
          secretName: my-app-tls  # Now safe to mount
```

## Alternative Solutions

### Option 1: Use optional secret mount (NOT RECOMMENDED)

```yaml
volumes:
- name: tls
  secret:
    secretName: my-app-tls
    optional: true  # Pod starts even if secret doesn't exist
```

**Problem**: Application will start without TLS certificate and may crash or operate insecurely.

### Option 2: Projected volume with default (NOT RECOMMENDED)

```yaml
volumes:
- name: tls
  projected:
    sources:
    - secret:
        name: my-app-tls
        optional: true
```

**Problem**: Same as Option 1 - application may start in degraded state.

### Option 3: External orchestration (OVERKILL)

Use Helm hooks, ArgoCD sync waves, or Flux kustomizations to enforce ordering.

**Problem**: Adds complexity. Init container is simpler and more portable.

## Best Practice: Init Container is the Standard

**✅ Always use init container for cert-manager certificates**

This is the industry-standard pattern because:
- Simple and portable
- Self-documenting (clear intent in YAML)
- Works with any orchestration tool
- No external dependencies
- Handles edge cases automatically

## Cost of This Lesson

**Time wasted debugging**: ~15 minutes per occurrence

**Frustration level**: High - error message is cryptic and doesn't mention cert-manager

**Fix complexity**: Low - once you know the pattern

**Prevented by**: Applying lessons learned from previous deployments (CoreDNS had similar issue with Helm metadata)

## Action Items

- [x] Add init container to AI Ops Agent deployment
- [x] Update deploy.sh to apply certificate first
- [x] Document this pattern in LESSONS_LEARNED.md
- [ ] Create reusable init container snippet
- [ ] Add to deployment checklist: "Does this mount a cert-manager certificate? Add init container!"

## References

- [cert-manager FAQ: Mount secrets in pods](https://cert-manager.io/docs/faq/)
- [Kubernetes Init Containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/)
- [cert-manager Certificate Ready Condition](https://cert-manager.io/docs/usage/certificate/#conditions)

---

**Lesson learned the hard way**: When using cert-manager, ALWAYS wait for certificates before starting pods that mount them.

---

# Lessons Learned: Vault PKI DNS Name Validation

## Problem

**Certificate Request Failed**: Vault refused to sign certificate due to DNS names not matching allowed domains.

### Error Message
```
Warning  SigningError  30m  cert-manager-certificaterequests-issuer-vault
  Vault failed to sign certificate: failed to sign certificate by vault: Error making API request.

URL: POST http://vault.vault.svc.cluster.local:8200/v1/pki_int/sign/ai-ops-agent
Code: 400. Errors:

* subject alternate name ai-ops-agent not allowed by this role
```

### Root Cause

The Vault PKI role `ai-ops-agent` is configured with strict `allowed_domains`:

```bash
# From init-vault-pki.sh
vault write pki_int/roles/ai-ops-agent \
    allowed_domains="corp.local,cluster.local" \
    allow_subdomains=true \
    allow_glob_domains=false \
    allow_bare_domains=false \     # ← Prevents bare hostnames!
    allow_localhost=false
```

This configuration:
- ✅ **Allows**: `*.corp.local` and `*.cluster.local`
- ❌ **Denies**: Bare hostnames, partial domains, anything not matching allowed_domains

The certificate requested:
```yaml
dnsNames:
  - ai-ops-agent                            # ❌ Bare hostname - NOT ALLOWED
  - ai-ops-agent.default                    # ❌ "default" is not an allowed domain
  - ai-ops-agent.default.svc                # ❌ "svc" is not an allowed domain
  - ai-ops-agent.default.svc.cluster.local  # ✅ Valid!
  - ai-ops-agent.corp.local                 # ✅ Valid!
```

**Vault rejected the certificate** because 3 of 5 DNS names violated the role's allowed_domains policy.

## Solution

**Only request DNS names that match Vault PKI role allowed_domains:**

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ai-ops-agent-cert
spec:
  # IMPORTANT: Only FQDNs matching Vault PKI role allowed_domains
  # ai-ops-agent role allows: *.corp.local, *.cluster.local
  commonName: ai-ops-agent.default.svc.cluster.local
  dnsNames:
    - ai-ops-agent.default.svc.cluster.local  # ✅ Subdomain of cluster.local
    - ai-ops-agent.corp.local                  # ✅ Subdomain of corp.local
```

### Why This Matters

**Kubernetes service DNS resolution works in layers:**

```
Short name:        ai-ops-agent              (resolves within same namespace)
Namespace-scoped:  ai-ops-agent.default      (resolves within cluster)
Service FQDN:      ai-ops-agent.default.svc  (resolves within cluster)
Cluster FQDN:      ai-ops-agent.default.svc.cluster.local  (fully qualified)
Corporate domain:  ai-ops-agent.corp.local   (for external access)
```

**For Vault PKI**, only the **fully qualified** names that match allowed_domains are valid:
- ✅ `ai-ops-agent.default.svc.cluster.local` - Matches `*.cluster.local`
- ✅ `ai-ops-agent.corp.local` - Matches `*.corp.local`
- ❌ Short names like `ai-ops-agent` don't match any allowed domain

## Checking Vault PKI Role Configuration

Before creating a Certificate, always check what domains are allowed:

```bash
# Port forward to Vault
kubectl port-forward -n vault svc/vault 8200:8200 &

export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=<your-root-token>

# Check role configuration
vault read pki_int/roles/ai-ops-agent
```

**Key fields to check:**
- `allowed_domains` - List of allowed domain suffixes
- `allow_subdomains` - Can request subdomains (*.example.com)
- `allow_bare_domains` - Can request bare domain (example.com)
- `allow_glob_domains` - Can use wildcards (*.*.example.com)
- `allow_localhost` - Can request localhost
- `allow_any_name` - Can request any name (dangerous!)

## Pattern: Match Certificate DNS Names to Vault PKI Role

**Before requesting a certificate:**

1. **Check Vault PKI role allowed_domains**
   ```bash
   vault read pki_int/roles/<role-name>
   ```

2. **Design DNS names that match**
   - Use full FQDNs ending in allowed domains
   - Avoid bare hostnames unless `allow_bare_domains=true`
   - Avoid partial domains that don't match allowed_domains

3. **Test with a single DNS name first**
   ```yaml
   dnsNames:
     - myservice.corp.local  # Start with one valid name
   ```

4. **Expand after success**
   ```yaml
   dnsNames:
     - myservice.corp.local
     - myservice.default.svc.cluster.local
   ```

## Common Mistakes

### Mistake 1: Including Short Hostnames

```yaml
# WRONG - Short hostname doesn't match allowed_domains
dnsNames:
  - myservice  # ❌ No domain suffix
  - myservice.corp.local  # ✅ Valid
```

### Mistake 2: Partial Kubernetes Domains

```yaml
# WRONG - Partial domains don't match allowed_domains
dnsNames:
  - myservice.default        # ❌ "default" is not an allowed domain
  - myservice.default.svc    # ❌ "svc" is not an allowed domain
  - myservice.default.svc.cluster.local  # ✅ Valid - matches *.cluster.local
```

### Mistake 3: Assuming All Kubernetes DNS Names Work

```yaml
# WRONG - Not all Kubernetes DNS resolution paths are valid for Vault
dnsNames:
  - myservice                # ❌ Bare hostname
  - myservice.default        # ❌ Not in allowed_domains
  - myservice.default.svc    # ❌ Not in allowed_domains
```

**Correct**: Only use **fully qualified** names matching allowed_domains:
```yaml
dnsNames:
  - myservice.default.svc.cluster.local  # ✅ Matches *.cluster.local
```

## Debugging Tips

### Check Certificate Status

```bash
# Describe certificate for detailed errors
kubectl describe certificate ai-ops-agent-cert

# Look for signing errors
kubectl get certificaterequest
kubectl describe certificaterequest <name>
```

### Check cert-manager Logs

```bash
# View cert-manager logs for Vault errors
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager | grep -i vault

# Look for "not allowed by this role" errors
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager | grep "not allowed"
```

### Test Manually with Vault CLI

```bash
# Test certificate request manually
vault write pki_int/sign/ai-ops-agent \
    common_name="ai-ops-agent.default.svc.cluster.local" \
    alt_names="ai-ops-agent,ai-ops-agent.default" \
    ttl="720h"

# If it fails, Vault will tell you which DNS name is not allowed
```

## Prevention Checklist

When creating certificates for Vault PKI:

- [ ] Check Vault PKI role allowed_domains
- [ ] Verify allow_subdomains, allow_bare_domains settings
- [ ] Only use FQDNs matching allowed_domains in dnsNames
- [ ] Avoid bare hostnames unless explicitly allowed
- [ ] Test certificate request manually first
- [ ] Check cert-manager logs after applying Certificate

## Best Practices

### 1. Document Allowed Domains in Certificate YAML

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: myservice-cert
spec:
  # IMPORTANT: PKI role 'myservice' allows: *.corp.local, *.cluster.local
  # Do NOT add bare hostnames or partial domains
  commonName: myservice.corp.local
  dnsNames:
    - myservice.corp.local
    - myservice.default.svc.cluster.local
```

### 2. Create Restrictive PKI Roles

```bash
# Good: Restrictive role for production services
vault write pki_int/roles/production \
    allowed_domains="prod.corp.local" \
    allow_subdomains=true \
    allow_bare_domains=false \
    allow_glob_domains=false

# Bad: Overly permissive role
vault write pki_int/roles/permissive \
    allow_any_name=true  # ❌ Dangerous!
```

### 3. Test Before Deploying

```bash
# Create test certificate first
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-cert
  namespace: default
spec:
  secretName: test-tls
  issuerRef:
    name: vault-issuer-ai-ops
    kind: ClusterIssuer
  commonName: test.corp.local
  dnsNames:
    - test.corp.local
  duration: 1h
EOF

# Wait and check
kubectl get certificate test-cert
kubectl describe certificate test-cert
```

## Cost of This Lesson

**Time wasted debugging**: ~20 minutes

**Frustration level**: High - should have checked PKI role configuration first

**Fix complexity**: Low - just remove invalid DNS names

**Prevented by**: Reading the Vault PKI role configuration before creating Certificate

## Related Issues

This is similar to:
- **CoreDNS Helm metadata** - Stricter validation in newer versions
- **cert-manager RBAC** - Explicit permissions required for Kubernetes 1.24+
- **Certificate mount race** - Another preventable issue

**Pattern**: Always check prerequisites and constraints BEFORE applying manifests.

## References

- [Vault PKI Roles](https://developer.hashicorp.com/vault/api-docs/secret/pki#create-update-role)
- [cert-manager Certificate DNS Names](https://cert-manager.io/docs/usage/certificate/#creating-certificate-resources)
- [Kubernetes DNS for Services](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)

---

**Lesson learned (again!)**: Always validate DNS names against Vault PKI role allowed_domains before requesting certificates.
