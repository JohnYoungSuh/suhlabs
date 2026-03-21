# OPS-PICERL-ERADICATION: Troubleshooting & Maintenance

**Document Type:** Operations - PICERL Phase: Eradication  
**Version:** 1.0 | **Last Updated:** 2025-12-16  
**Audience:** Operators, Support Engineers, On-Call Teams

> 👤 **Quick Navigation:**  
> Emergency → [Jump to Common Issues](#runbook-e1-common-service-failures)  
> Maintenance → [Jump to Update Procedures](#procedures-system-maintenance)

---

## 📊 At-a-Glance

**Purpose:** Fix bugs, troubleshoot issues, and perform routine maintenance to keep services healthy.

**Common Issue Response Times:**

- Service Down: < 5 minutes
- Performance Degradation: < 30 minutes
- Non-Critical Bugs: < 24 hours

---

## 🚀 Quick Start

### Troubleshooting Decision Tree

```
Is a service down?
├─ Home Assistant not responding
│  └─ Runbook E1-HA
├─ Jellyf in won't start
│  └─ Runbook E1-Jellyfin
├─ Frigate camera offline
│  └─ Runbook E1-Frigate
└─ K3s control plane issue
   └─ Runbook E2
```

---

## 📋 Policy

### 1. Root Cause Analysis Policy

**Intent:** Fix problems permanently, not just symptoms.

**Requirements:**

- Document RCA for all P1/P2 incidents
- Update runbooks after each incident
- Share learnings in OPS-LESSONS.md

### 2. Change Management Policy

**Intent:** Minimize risk during maintenance.

**Rules:**

- Test updates in dev environment first
- Maintenance windows: Sundays 2-6 AM
- Rollback plan required for all changes
- No production changes without approval

---

## ⚙️ Standards

### Bug Severity Levels

| Severity          | Response Time | Examples                             |
| ----------------- | ------------- | ------------------------------------ |
| **P1 - Critical** | 15 min        | Service completely down, data loss   |
| **P2 - High**     | 2 hours       | Degraded performance, partial outage |
| **P3 - Medium**   | 1 day         | Minor bugs, cosmetic issues          |
| **P4 - Low**      | 1 week        | Feature requests, enhancements       |

---

## 📖 Procedures

### Runbook E1: Common Service Failures

#### E1-HA: Home Assistant Won't Start

**Symptoms:** Pod crash loop, 404 errors

**Diagnosis:**

```bash
# Check pod status
kubectl get pods -n homeassistant

# Check logs
kubectl logs -f deployment/homeassistant -n homeassistant --tail=100

# Common errors:
# - "Database locked" → Corruption
# - "Permission denied" → PVC mount issue
# - "Config error" → YAML syntax
```

**Fix:**

```bash
# 1. Check config syntax
kubectl exec -it deployment/homeassistant -n homeassistant -- \
  ha core check

# 2. If database locked, restart pod
kubectl delete pod -l app=homeassistant -n homeassistant

# 3. If PVC issue, check mount
kubectl describe pvc homeassistant-data -n homeassistant

# 4. Restore from backup (last resort)
# See OPS-PICERL-RECOVERY.md Runbook R2
```

#### E1-Jellyfin: Transcoding Failed

**Symptoms:** "Playback error", stuttering video

**Fix:**

```bash
# Check hardware transcoding
kubectl exec -it deployment/jellyfin -n jellyfin -- \
  /usr/lib/jellyfin-ffmpeg/vainfo

# Should show: Intel Quick Sync devices

# If missing:
# 1. Check device passthrough
kubectl get pod -n jellyfin -o yaml | grep devices

# Should have:
# devices:
# - /dev/dri:/dev/dri

# 2. Restart with correct device mount
kubectl apply -f cluster/ai-ops-agent/deployment/jellyfin.yaml
```

#### E1-Frigate: Camera Offline

**Symptoms:** "Camera unavailable" in UI

**Fix:**

```bash
# 1. Test camera RTSP stream
ffmpeg -i rtsp://camera-ip:554/stream -frames:v 1 test.jpg

# 2. Check Frigate config
kubectl exec -it deployment/frigate -n frigate -- \
  cat /config/config.yml

# 3. Check logs for connection errors
kubectl logs deployment/frigate -n frigate | grep -i error

# 4. Restart Frigate
kubectl rollout restart deployment/frigate -n frigate
```

### Runbook E2: K3s Control Plane Issues

**Symptoms:** `kubectl` commands hang, pods stuck Pending

**Fix:**

```bash
# 1. Check K3s service
sudo systemctl status k3s

# 2. Check control plane pods
kubectl get pods -n kube-system

# 3. Restart K3s (if needed)
sudo systemctl restart k3s

# 4. Verify cluster health
kubectl get nodes
kubectl get componentstatuses
```

### Runbook E3: Disk Space Management

**Symptoms:** "No space left on device" errors

**Fix:**

```bash
# 1. Find largest consumers
du -sh /* | sort -hr | head -20

# 2. Clean up logs
journalctl --vacuum-time=7d

# 3. Clean up old container images
kubectl exec -n kube-system -it $(kubectl get pod -n kube-system -l component=kube-apiserver -o name | head -1) -- \
  crictl rmi --prune

# 4. Clean up Longhorn snapshots (if HA)
kubectl delete volumesnapshot --all

# 5. Rotate Restic backups
restic forget --keep-daily 7 --keep-weekly 4 --prune
```

### Runbook E4: Storage and Secrets Edge Cases (Production)

#### E4-Vault: Auto-Unseal Failures in Production

**Symptoms:** Vault pods are running but not ready (`0/1`); applications fail to retrieve secrets. K3s events show Readiness probe failed.

**Diagnosis:**
1. Execute into the active Vault pod: `kubectl exec -n vault vault-0 -- vault status`
2. If `Sealed` is `true`, the auto-unseal mechanism (e.g., AWS KMS, transit, YubiHSM) failed.
3. Check Vault logs for KMS connectivity errors: `kubectl logs -n vault vault-0 | grep -i 'core: unseal'`

**Fix:**
```bash
# 1. Fallback to manual unseal with recovery keys (if Raft auto-unseal is completely unreachable)
kubectl exec -n vault vault-0 -- vault operator unseal <Recovery-Key-1>
kubectl exec -n vault vault-0 -- vault operator unseal <Recovery-Key-2>
kubectl exec -n vault vault-0 -- vault operator unseal <Recovery-Key-3>

# 2. Check KMS connectivity from within the cluster
# Ensure egress traffic from internal Vault nodes to KMS endpoints is not blocked by NetworkPolicies
```

#### E4-Longhorn: Replica Rebuilds & Degraded Volumes

**Symptoms:** Longhorn UI shows warning state. `kubectl get volumes -n longhorn-system` shows degraded volumes.

**Diagnosis:**
Usually caused by a preempted node or temporary IO disruption. Longhorn automatically flags replicas as `ERR` and drops them.

**Fix:**
```bash
# 1. Automatic Rebuild: Longhorn will automatically start rebuilding a replica on another available node. Wait for the sync to complete.
# 2. If rebuilding is stuck, access the Longhorn UI via port-forward:
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80

# 3. In the UI, navigate to the Volume, manually delete the `ERR` replica, and click "Replenish Replicas".
# 4. For chronic degradation, verify disk IO limits or Node scheduling constraints.
```

---

## 💻 Implementation

### System Maintenance Schedule

```bash
# Weekly: Sunday 2 AM
0 2 * * 0 /usr/local/bin/weekly-maintenance.sh

# Monthly: First Sunday 3 AM
0 3 1-7 * 0 [ "$(date +\%u)" = 7 ] && /usr/local/bin/monthly-maintenance.sh
```

**weekly-maintenance.sh:**

```bash
#!/bin/bash
set -euo pipefail

# 1. Update system packages
sudo apt update && sudo apt upgrade -y

# 2. Clean up logs
journalctl --vacuum-time=30d

# 3. Restart services for patches
kubectl rollout restart deployment -n homeassistant
kubectl rollout restart deployment -n jellyfin

# 4. Verify health
kubectl get pods -A
```

---

## 📚 Deep Dive

<details>
<summary>Vault Unsealing Issues</summary>

**Problem:** Vault sealed after reboot

```bash
# Check Vault status
kubectl exec -n vault vault-0 -- vault status

# Unseal (requires 3 of 5 keys)
kubectl exec -n vault vault-0 -- vault operator unseal <key1>
kubectl exec -n vault vault-0 -- vault operator unseal <key2>
kubectl exec -n vault vault-0 -- vault operator unseal <key3>
```

**Permanent Fix:** Configure YubiHSM auto-unseal (production)

</details>

---

**Document Status:** ✅ Complete
