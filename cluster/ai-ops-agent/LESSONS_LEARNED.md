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
        image: bitnami/kubectl:1.28
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
        image: bitnami/kubectl:1.28
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
