# CoreDNS Deployment - Lessons Learned

**Date:** 2025-11-13
**Issue:** CoreDNS pods healthy but DNS resolution failing with "connection refused"
**Resolution Time:** ~3 hours of iterative debugging

---

## 🔴 The Problem

DNS queries to `10.96.0.10:53` (kube-dns service) were failing with:
```
nslookup: write to '10.96.0.10': Connection refused
;; connection timed out; no servers could be reached
```

**Symptoms:**
- ✅ CoreDNS pods running and healthy
- ✅ Logs showed zones loaded successfully
- ✅ ConfigMap had correct Corefile
- ❌ DNS queries failing
- ❌ Service endpoints empty

---

## 🔍 Root Cause

**Label Mismatch:** Kubernetes expects DNS pods to be labeled `k8s-app=kube-dns`, but CoreDNS Helm chart defaults to `k8s-app=coredns`.

```bash
# What we deployed (wrong):
kubectl get pods -n kube-system -l k8s-app=coredns
# Shows pods, but kube-dns service can't find them

# What Kubernetes expects:
kubectl get pods -n kube-system -l k8s-app=kube-dns
# Should show DNS pods
```

**Missing Configuration:**
```yaml
# values.yaml was missing:
k8sAppLabelOverride: "kube-dns"
```

---

## 🛠️ How We Debugged It

### 1. **Used netshoot for Network Testing**
```bash
# Launch debug pod in kube-system namespace
kubectl run -it --rm netshoot \
  --image=nicolaka/netshoot \
  --namespace=kube-system \
  -- bash

# Inside netshoot:
dig @10.96.0.10 kubernetes.default.svc.cluster.local
nslookup ns1.corp.local
nc -vzu 10.96.0.10 53  # Test UDP port 53
```

**Result:** Connection refused on port 53

### 2. **Checked Service Configuration**
```bash
kubectl get service coredns -n kube-system -o yaml | grep -A 5 selector
```

**Found:** Service selector looking for specific labels

### 3. **Verified Pod Labels**
```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=coredns --show-labels
```

**Found:** Pods had `k8s-app=coredns` but should have `k8s-app=kube-dns`

### 4. **Checked Service Endpoints**
```bash
kubectl get endpoints coredns -n kube-system
```

**Result:** Empty or mismatched endpoints = service can't route traffic

### 5. **Verified CoreDNS Health**
```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=coredns --tail=50
```

**Found:** No errors, zones loaded correctly, but not receiving queries

---

## ✅ The Fix

### Temporary Fix (Applied During Debugging):
```bash
# Patch pod labels manually
kubectl label pods -n kube-system -l app.kubernetes.io/name=coredns k8s-app=kube-dns --overwrite
```

### Permanent Fix (In values.yaml):
```yaml
# Add to cluster/foundation/coredns/values.yaml
k8sAppLabelOverride: "kube-dns"
```

Then redeploy:
```bash
cd cluster/foundation/coredns
./deploy.sh
```

---

## 📚 What We Learned

### 1. **Labels Matter for Service Routing**
| Component | Purpose |
|-----------|---------|
| **Service Selector** | Uses labels to find backend pods |
| **Pod Labels** | Must match service selector exactly |
| **Endpoints** | Auto-populated when labels match |

If labels don't match → Service has no endpoints → Traffic goes nowhere

### 2. **DNS in Kubernetes Has Legacy Names**
- Original DNS: `kube-dns`
- Current implementation: `CoreDNS`
- **But the label convention stayed:** `k8s-app=kube-dns`

The CoreDNS Helm chart provides `k8sAppLabelOverride` for this compatibility.

### 3. **Troubleshooting DNS Flow**

```
┌─────────────────────────────────────────────────────────┐
│ 1. Test DNS from Inside Cluster                        │
│    kubectl run netshoot --rm -it --image=nicolaka/...  │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│ 2. Check Service IP and Port                           │
│    kubectl get svc kube-dns -n kube-system             │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│ 3. Verify Service Has Endpoints                        │
│    kubectl get endpoints coredns -n kube-system        │
│    → If empty: Label mismatch!                         │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│ 4. Check Pod Labels                                     │
│    kubectl get pods -n kube-system --show-labels       │
│    → Compare to service selector                       │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│ 5. Check Pod Health & Logs                             │
│    kubectl logs -n kube-system -l app.kubernetes.io... │
└─────────────────────────────────────────────────────────┘
```

### 4. **Essential Debug Tools**

| Tool | Use Case | Command |
|------|----------|---------|
| **netshoot** | Network debugging inside cluster | `kubectl run netshoot --rm -it --image=nicolaka/netshoot -- bash` |
| **dig** | DNS query testing | `dig @10.96.0.10 kubernetes.default` |
| **nc** | Port connectivity testing | `nc -vzu 10.96.0.10 53` |
| **kubectl describe** | View events and conditions | `kubectl describe pods -n kube-system` |
| **kubectl logs** | Check application errors | `kubectl logs -n kube-system -l k8s-app=coredns` |

### 5. **Key Kubernetes Debugging Commands**

```bash
# Check if service selector matches pod labels
kubectl get svc <service-name> -o yaml | grep selector -A 5
kubectl get pods -l <label-selector> --show-labels

# Verify service has backend pods
kubectl get endpoints <service-name>

# Test connectivity from inside cluster
kubectl run test-pod --rm -it --image=nicolaka/netshoot -- bash

# Check pod readiness probes
kubectl describe pod <pod-name> | grep -A 10 "Conditions:"

# View recent events
kubectl get events -n kube-system --sort-by='.lastTimestamp'
```

---

## 🚨 Common DNS Issues in Kubernetes

### Issue 1: Empty Endpoints
**Symptom:** Service exists but no endpoints
**Cause:** Pod labels don't match service selector
**Fix:** Verify labels match: `kubectl get svc <name> -o yaml` vs `kubectl get pods --show-labels`

### Issue 2: Connection Refused
**Symptom:** `nslookup`/`dig` fails with connection refused
**Cause:** No pods behind the service (empty endpoints)
**Fix:** Check endpoints, fix label mismatch

### Issue 3: Zone File Errors
**Symptom:** CoreDNS logs show "no such file or directory"
**Cause:** Wrong file path in Corefile
**Fix:** Verify mount path matches Corefile reference

### Issue 4: Corefile Syntax Errors
**Symptom:** CoreDNS won't start, logs show syntax errors
**Cause:** Invalid zone configuration
**Fix:** Validate Corefile syntax, check for invalid schemes

### Issue 5: Immutable Field Errors
**Symptom:** Helm upgrade fails with "field is immutable"
**Cause:** Trying to change Deployment selector
**Fix:** Delete and redeploy (or use blue-green strategy)

---

## 🎯 Best Practices Going Forward

### 1. **Always Validate Labels Match Selectors**
```bash
# Before deploying, check values.yaml will create correct labels
helm template coredns coredns/coredns -f values.yaml | grep -A 5 "k8s-app"
```

### 2. **Test DNS Immediately After Deployment**
```bash
# Quick DNS health check
kubectl run dns-test --rm -it --image=busybox:1.36 -- nslookup kubernetes.default
```

### 3. **Use netshoot for In-Cluster Debugging**
Keep this handy:
```bash
alias netshoot='kubectl run -it --rm netshoot --image=nicolaka/netshoot -- bash'
```

### 4. **Check Endpoints First When Service Fails**
Before diving into logs:
```bash
kubectl get endpoints <service-name> -n <namespace>
```
Empty endpoints = label mismatch 99% of the time

### 5. **Validate Helm Chart Defaults**
Always check official values.yaml for:
- Label override options (`k8sAppLabelOverride`)
- Service name customization
- Compatibility settings

---

## 📋 Troubleshooting Checklist

When DNS fails in Kubernetes:

- [ ] 1. Can you reach the DNS service IP from inside a pod?
  ```bash
  kubectl run netshoot --rm -it --image=nicolaka/netshoot -- dig @10.96.0.10 kubernetes.default
  ```

- [ ] 2. Does the DNS service have endpoints?
  ```bash
  kubectl get endpoints -n kube-system
  ```

- [ ] 3. Do pod labels match the service selector?
  ```bash
  kubectl get svc coredns -n kube-system -o jsonpath='{.spec.selector}'
  kubectl get pods -n kube-system --show-labels | grep coredns
  ```

- [ ] 4. Are the DNS pods running and ready?
  ```bash
  kubectl get pods -n kube-system -l k8s-app=kube-dns
  ```

- [ ] 5. Any errors in CoreDNS logs?
  ```bash
  kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50
  ```

- [ ] 6. Is the Corefile syntactically correct?
  ```bash
  kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}'
  ```

- [ ] 7. Are zone files mounted correctly?
  ```bash
  kubectl logs -n kube-system -l k8s-app=kube-dns | grep -i "zone\|file"
  ```

---

## 🔗 References

- [Kubernetes DNS Debugging](https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/)
- [CoreDNS Helm Chart](https://github.com/coredns/helm)
- [CoreDNS Troubleshooting](https://coredns.io/manual/toc/#troubleshooting)
- [netshoot - Network Troubleshooting Container](https://github.com/nicolaka/netshoot)

---

## 💡 Key Takeaway

**When DNS fails, check endpoints first.** Empty endpoints = label mismatch. This single check would have saved us hours of debugging.

```bash
# The one command that would have pointed us to the issue immediately:
kubectl get endpoints coredns -n kube-system
```

---

**Status:** Resolved ✅
**Next Time:** Always set `k8sAppLabelOverride: "kube-dns"` when deploying CoreDNS in Kubernetes
