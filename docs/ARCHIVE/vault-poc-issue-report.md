# Vault POC Issue Report

**Cluster:** kind-aiops-dev (POC)
**Date:** 2025-11-27
**Status:** 🔴 SEALED - Vault is not operational

---

## Current Status

### Vault Pod
```
NAME      READY   STATUS    RESTARTS   AGE
vault-0   0/1     Running   3          6d21h
```

**Issues:**
- ✅ Pod is Running
- ❌ Pod is NOT Ready (0/1)
- ⚠️  Has restarted 3 times
- ⚠️  Last restart: 3h49m ago

### Vault Seal Status
```
Seal Type:       shamir
Initialized:     true
Sealed:          true  ⚠️ PROBLEM
Total Shares:    1
Threshold:       1
Unseal Progress: 0/1
```

**Exit Code:** 2 (indicates sealed state)

### Readiness Probe
```
Warning: Readiness probe failed: 3,067 times over 3h49m
```

Vault readiness probe checks `vault status`, which returns exit code 2 when sealed.

---

## Root Cause Analysis

### Why Vault is Sealed

1. **No Auto-Unseal Sidecar**
   - StatefulSet has only 1 container: `vault`
   - No auto-unseal sidecar container configured
   - Expected: 2 containers (vault + auto-unseal)

2. **Node Restart / Pod Restart**
   - Vault seals itself on restart (security feature)
   - Last restart: 3h49m ago (likely when dev box rebooted)
   - Without auto-unseal, stays sealed indefinitely

3. **Missing Auto-Unseal Configuration**
   - ConfigMap for auto-unseal script: NOT FOUND
   - Auto-unseal sidecar in StatefulSet: NOT CONFIGURED
   - Manual unseal required after every restart

### What EXISTS (Good News)

✅ **Unseal keys are available:**
   - Kubernetes Secret: `vault-unseal-keys` (exists in vault namespace)
   - Local file: `.vault-keys.json` (exists, 7 days old)

✅ **Vault is initialized:**
   - Don't need to run `vault operator init` again
   - Just need to unseal

---

## Impact

### Services Affected

All services depending on Vault are broken:

1. **Cert-Manager** ❌
   - Cannot issue certificates
   - ClusterIssuers cannot authenticate to Vault
   - All Certificate resources stuck in "Pending"

2. **Vault PKI** ❌
   - Cannot read certificates
   - Cannot issue new certificates
   - PKI roles inaccessible

3. **Secrets Management** ❌
   - Applications cannot retrieve secrets
   - Vault KV engine inaccessible

4. **Kubernetes Auth** ❌
   - Service accounts cannot authenticate
   - Vault policies cannot be applied

### Blast Radius

**Severity:** 🔴 HIGH
- All PKI-dependent services: DOWN
- All secret-dependent applications: DOWN
- Certificate rotation: BLOCKED
- New deployments requiring secrets: BLOCKED

---

## Immediate Fix (Manual Unseal)

### Option 1: Quick Unseal (Manual - 2 minutes)

```bash
# 1. Get unseal key
cd /home/suhlabs/projects/suhlabs/aiops-substrate/cluster/foundation/vault
UNSEAL_KEY=$(jq -r '.unseal_keys_b64[0]' .vault-keys.json)

# 2. Unseal Vault
kubectl exec -n vault vault-0 -- vault operator unseal "$UNSEAL_KEY"

# 3. Verify
kubectl exec -n vault vault-0 -- vault status
# Should show: Sealed: false

# 4. Check pod becomes ready
kubectl get pods -n vault vault-0
# Should show: 1/1 Ready
```

**Pros:** Fast, fixes issue immediately
**Cons:** Will seal again on next restart

### Option 2: Permanent Fix (Auto-Unseal - 30 minutes)

Deploy auto-unseal sidecar to prevent future sealing:

```bash
cd /home/suhlabs/projects/suhlabs/aiops-substrate/cluster/foundation/vault

# 1. Check if auto-unseal config exists
ls -la auto-unseal-sidecar.yaml

# 2. If it exists, apply it
kubectl apply -f auto-unseal-sidecar.yaml

# 3. Update StatefulSet to include sidecar
# (Requires editing vault Helm values and redeploying)

# 4. Create unseal keys secret if not properly formatted
kubectl create secret generic vault-unseal-keys \
  -n vault \
  --from-literal=unseal_key_0="$(jq -r '.unseal_keys_b64[0]' .vault-keys.json)" \
  --dry-run=client -o yaml | kubectl apply -f -
```

**Pros:** Vault auto-unseals on restart
**Cons:** Requires Helm chart modification

---

## Long-Term Solution

### Problem
Per your earlier comment: "dev environment is restarted, constraint is that I can't have my dev box up all the time"

### Solution Options

**Already discussed in docs/ENVIRONMENT-STRATEGY-ANALYSIS.md:**

1. **Option 1: Deploy auto-unseal to POC** (Quick win, 1-2 hours)
   - Add sidecar container to Vault StatefulSet
   - Sidecar checks every 10s, unseals if sealed
   - Survives pod/node restarts

2. **Option 2: Migrate POC to Proxmox** (Long-term, 2-3 days)
   - POC runs on always-on Proxmox VM
   - Never seals due to restarts
   - Kind stays for validation (ephemeral tests)

3. **Option 3: Accept manual unseal** (Current state)
   - Unseal manually after dev box restart
   - Document procedure
   - Keep .vault-keys.json handy

**Recommended:** Option 1 (auto-unseal) for POC cluster

---

## Related Documentation

- Visual environment indicators: `docs/VISUAL-ENVIRONMENT-INDICATORS.md`
- Environment strategy: `docs/ENVIRONMENT-STRATEGY-ANALYSIS.md`
- Lessons learned: `docs/lessons-learned.md` (lines 1466-1502)

---

## Action Items

### Immediate (Now)
1. ⚠️  Manually unseal Vault (2 minutes)
2. ✅ Verify cert-manager resumes issuing certificates
3. ✅ Verify services can retrieve secrets

### Short-Term (This Week)
1. 🔧 Deploy auto-unseal sidecar to POC cluster
2. 📝 Test Vault survives pod restart
3. 📊 Add monitoring alert for Vault seal status

### Long-Term (Next Sprint)
1. 🏗️  Consider Proxmox migration for POC
2. 📖 Document unseal procedure in runbook
3. 🧪 Chaos test: reboot node, verify auto-unseal works

---

## Quick Reference

**Unseal Command:**
```bash
cd /home/suhlabs/projects/suhlabs/aiops-substrate/cluster/foundation/vault
kubectl exec -n vault vault-0 -- vault operator unseal "$(jq -r '.unseal_keys_b64[0]' .vault-keys.json)"
```

**Check Status:**
```bash
kubectl exec -n vault vault-0 -- vault status
```

**Expected Output (Unsealed):**
```
Sealed: false  ✅
```
