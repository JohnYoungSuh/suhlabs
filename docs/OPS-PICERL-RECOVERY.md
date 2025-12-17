# OPS-PICERL-RECOVERY: Disaster Recovery & Restore Procedures

**Document Type:** Operations - PICERL Phase: Recovery  
**Version:** 1.0 | **Last Updated:** 2025-12-16  
**Audience:** Operators, SREs, Disaster Recovery Teams

> 👤 **Quick Navigation:**  
> Operators → [Jump to Restore Protocol](#runbook-r1-antigravity-restore-protocol)  
> Management → [Jump to RTO/RPO](#policy-recovery-objectives)  
> Security → See [SECURITY-PICERL-RECOVERY](SECURITY-PICERL-RECOVERY.md)

---

## 📊 At-a-Glance (30 seconds)

**Purpose:** Restore the Family Privacy Hub appliance to operational state after hardware failure or data loss.

**TL;DR - Recovery Strategy:**

1. **Virtual Fault Tolerance:** K3s self-heals pods (automatic, no action needed)
2. **Antigravity Restore:** IDE orchestrates full appliance rebuild (~30 min)
3. **User-Controlled Decryption:** Backup keys never leave edge

```mermaid
graph LR
    FAIL[Hardware Failure] --> NEW[Fresh Hardware]
    NEW --> IDE[AI IDE: Generate<br/>K3s Bootstrap]
    IDE --> SKEL[Skeleton Infrastructure<br/>No Data]
    SKEL --> USER[User Provides<br/>Decryption Key]
    USER --> RESTIC[Restic Restore<br/>ON Edge]
    RESTIC --> LIVE[✅ System Operational]

    style FAIL fill:#FF5252
    style NEW fill:#FFA726
    style IDE fill:#FF9800
    style USER fill:#66BB6A
    style LIVE fill:#4CAF50
```

**Recovery Time:** ~30 minutes | **Data Loss:** Zero (if backups current)

---

## 🚀 Quick Start (Emergency Response)

### Failure Type Decision Tree

```
What failed?
├─ Single pod crashed
│  └─ Wait 30s → K3s auto-restarts (no action needed)
│
├─ Service misconfigured
│  └─ Ask IDE: "Regenerate homeassistant config"
│
├─ Drive failure (data intact on other drives)
│  └─ Replace drive → Longhorn rebalances (HA only)
│
└─ Complete hardware failure
   └─ FULL RESTORE PROTOCOL (see below)
```

### Emergency Contact Card

**Before calling support:**

- [ ] Backup key accessible? (USB drive, password manager)
- [ ] New/replacement hardware available?
- [ ] S3 backup bucket accessible? (test: `restic snapshots`)
- [ ] IDE SSH access to new appliance?

**Data Needed:**

- Last known good backup ID
- Hardware serial number (for HA config)
- Network configuration (static IP)

---

## 📋 Policy (Intent - WHY)

### 1. Recovery Objective Policy

**Intent:** Minimize data loss and downtime while maintaining privacy.

**Targets:**

```
RTO (Recovery Time Objective): 30 minutes
RPO (Recovery Point Objective): 6 hours
Data Loss Tolerance: Zero critical data
```

**Non-Negotiable:**

- User controls decryption keys (never escrowed)
- IDE orchestrates but never decrypts
- Backup verification monthly (automated test restore)

### 2. Virtual Fault Tolerance Policy

**Intent:** OS/software is disposable, data is sacred.

**Principles:**

- Hardware failures don't require bare-metal recovery
- K3s self-heals at pod level
- Full rebuilds use IDE-generated configs (reproducible)
- No "snowflake" configurations

### 3. Backup Retention Policy

**Intent:** Balance storage cost with recovery needs.

**Retention Schedule:**

```
Hourly snapshots:   Keep 24 (1 day)
Daily snapshots:    Keep 30 (1 month)
Weekly snapshots:   Keep 12 (3 months)
Monthly snapshots:  Keep 12 (1 year)
```

**Estimated Storage:**

- Tier 1 (Basic): ~500GB total backups
- Tier 2 (Standard): ~1.5TB total backups

---

## ⚙️ Standards (Mandatory - MUST)

### Backup Infrastructure Standards

| Component       | Requirement                         | Validation          |
| --------------- | ----------------------------------- | ------------------- |
| **Backup Tool** | Restic v0.16+                       | `restic version`    |
| **Encryption**  | AES-256, user-controlled key        | `restic cat config` |
| **Repository**  | S3-compatible (Backblaze B2, MinIO) | `restic snapshots`  |
| **Frequency**   | Every 6 hours minimum               | Cron: `0 */6 * * *` |
| **Testing**     | Monthly restore drill               | Automated test job  |

### Restore Validation Standards

| Check                    | Requirement             | Command                    |
| ------------------------ | ----------------------- | -------------------------- |
| **K3s Health**           | All system pods Running | `kubectl get pods -A`      |
| **Data Integrity**       | Restic verify passes    | `restic check --read-data` |
| **Service Access**       | All URLs respond 200    | `curl https://home.lan`    |
| **Certificate Validity** | All certs valid >7 days | `kubectl get certificate`  |

---

## 💡 Guidelines (Best Practices - SHOULD)

### Pre-Disaster Preparation

**Monthly Drills:**

1. Spin up test VM
2. Run full restore to test VM
3. Verify all services start
4. Document restore time
5. Update runbooks if needed

**Backup Validation:**

```bash
# Weekly: Quick snapshot check
restic snapshots | tail -10

# Monthly: Full data integrity check
restic check --read-data-subset=10%
```

**Documentation:**

- Keep printed copy of this runbook (power outage scenario)
- Store backup key in 2+ locations (USB + password manager)
- Document custom configurations (non-standard network, VLANs)

### Recovery Optimization

**Parallel Restoration (HA setups):**

```bash
# Node 1: Restore control plane
# Node 2: Restore simultaneously (saves time)
restic restore latest --target=/mnt/data &
ssh node2 "restic restore latest --target=/mnt/data" &
```

**Selective Restoration:**

```bash
# Only restore critical services first
restic restore latest \
  --include /mnt/data/homeassistant \
  --include /mnt/data/vault \
  --target=/mnt/data
```

---

## 📖 Procedures (Restore Runbooks)

### Runbook R1: Antigravity Restore Protocol (Full DR)

**Scenario:** Complete hardware failure - rebuilding from scr

atch  
**Estimated Time:** 30-45 minutes  
**Prerequisites:** Fresh Ubuntu installation, backup key accessible

#### Phase 1: IDE-Guided Initialization (10 min)

1. **Boot fresh hardware** with Ubuntu 22.04 LTS
2. **Open IDE** and request restore:

   ```
   USER: "Restore my family appliance to 192.168.1.10"
   ```

3. **IDE generates K3s bootstrap script:**

   ```bash
   # IDE creates this script dynamically
   export K3S_VERSION="v1.28.5+k3s1"
   curl -sfL https://get.k3s.io | sh -s - server \
     --cluster-init \
     --disable traefik \
     --disable servicelb
   ```

4. **IDE SSH connects and executes:**

   ```bash
   ssh admin@192.168.1.10 "bash -s" < bootstrap.sh
   ```

5. **Verify K3s cluster ready:**
   ```bash
   kubectl get nodes
   # familyhub   Ready   control-plane   2m
   ```

#### Phase 2: Deploy Skeleton Infrastructure (5 min)

**IDE applies structure (no data):**

```bash
# Namespaces
kubectl create namespace homeassistant
kubectl create namespace jellyfin
kubectl create namespace vault

# Empty PVCs
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: homeassistant-data
  namespace: homeassistant
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 50Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: jellyfin-media
  namespace: jellyfin
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 4Ti
EOF
```

**Status:** Infrastructure exists, pods crash (no data yet)

#### Phase 3: User-Controlled Data Restore (15-20 min)

**IDE prompts for backup key:**

```
IDE: I need your backup decryption key to restore data.
     This key NEVER leaves your machine.

     Provide via:
     1. USB drive: /media/backup-key.txt
     2. Secure paste (I'll write to /tmp/key.txt locally)
     3. Password manager: Copy and paste
```

**User provides key via SSH:**

```bash
# User SSHs to appliance directly
ssh admin@192.168.1.10

# User creates key file locally
echo "your-backup-key-here" > /tmp/restic-key.txt
chmod 600 /tmp/restic-key.txt
```

**IDE runs restoration script ON the appliance (not in IDE):**

```bash
# This executes LOCALLY - IDE never sees the key
export RESTIC_REPOSITORY="s3:s3.us-west-000.backblazeb2.com/familyhub-backups"
export AWS_ACCESS_KEY_ID="your-b2-key-id"
export AWS_SECRET_ACCESS_KEY="your-b2-secret-key"

# Restore latest snapshot
restic restore latest \
  --target /mnt/data \
  --password-file /tmp/restic-key.txt

# Secure cleanup
shred -u /tmp/restic-key.txt
```

**Progress monitoring:**

```bash
# IDE shows progress (reads stdout, not the key)
restoring [homeassistant] 45.2GB / 50GB (90%)
restoring [jellyfin] 1.2TB / 4TB (30%)
```

#### Phase 4: Service Resurrection (5 min)

**After data restored:**

1. **K3s detects volumes ready:**

   ```bash
   kubectl get pvc -A
   # All show STATUS: Bound
   ```

2. **Deploy service manifests:**

   ```bash
   kubectl apply -f homeassistant.yaml
   kubectl apply -f jellyfin.yaml
   kubectl apply -f frigate.yaml
   ```

3. **Wait for pods to start:**

   ```bash
   kubectl wait --for=condition=ready pod \
     -l app=homeassistant -n homeassistant \
     --timeout=300s
   ```

4. **Verify services accessible:**
   ```bash
   curl https://home.lan/health
   # {"status":"healthy"}
   ```

**Recovery Complete!** User accesses services as before.

---

### Runbook R2: Selective Service Restore

**Scenario:** Only one service needs restoration (e.g., Home Assistant config corruption)

```bash
# 1. Stop the service
kubectl scale deployment/homeassistant -n homeassistant --replicas=0

# 2. Restore only that service's data
restic restore latest \
  --include /mnt/data/homeassistant \
  --target /mnt/data \
  --password-file /run/secrets/restic-key

# 3. Restart service
kubectl scale deployment/homeassistant -n homeassistant --replicas=1

# 4. Verify
kubectl logs -f deployment/homeassistant -n homeassistant
```

---

### Runbook R3: Backup Verification (Monthly Drill)

**Purpose:** Ensure backups are restorable

```bash
# 1. Create test namespace
kubectl create namespace restore-test

# 2. Mount test volume
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: restore-test
  namespace: restore-test
spec:
  containers:
  - name: tester
    image: ubuntu:22.04
    command: ["/bin/sleep", "3600"]
    volumeMounts:
    - name: test-data
      mountPath: /restore
  volumes:
  - name: test-data
    emptyDir: {}
EOF

# 3. Restore to test volume
kubectl exec -it restore-test -n restore-test -- bash
restic restore latest --target /restore --password-file=$KEY

# 4. Verify data integrity
ls -lah /restore
# Check critical files exist

# 5. Cleanup
kubectl delete namespace restore-test
```

**Document results:** Update `docs/RESTORE-TEST-RESULTS.md`

---

## 💻 Implementation (Automated Scripts)

### Automated Backup Script

**Location:** `/usr/local/bin/backup-appliance.sh`

```bash
#!/bin/bash
set -euo pipefail

# Restic backup script
RESTIC_REPOSITORY="s3:s3.us-west-000.backblazeb2.com/familyhub-backups"
RESTIC_PASSWORD_FILE="/run/secrets/restic-key"
BACKUP_PATHS="/mnt/data"

# Pre-backup: Database snapshots
kubectl exec -n homeassistant deployment/homeassistant -- \
  sqlite3 /config/home-assistant_v2.db ".backup /config/backup.db"

# Run backup
restic backup $BACKUP_PATHS \
  --tag "$(date +%Y-%m-%d)" \
  --exclude "*.tmp" \
  --exclude "*.log"

# Cleanup old snapshots (per retention policy)
restic forget \
  --keep-hourly 24 \
  --keep-daily 30 \
  --keep-weekly 12 \
  --keep-monthly 12 \
  --prune

# Verify backup integrity (10% sample)
restic check --read-data-subset=10%

# Send metrics
curl -X POST http://prometheus-pushgateway:9091/metrics/job/backup \
  --data-binary @<(cat <<EOF
backup_duration_seconds $(date +%s)
backup_size_bytes $(restic stats latest --json | jq '.total_size')
EOF
)
```

**Cron schedule:**

```cron
# Run every 6 hours
0 */6 * * * /usr/local/bin/backup-appliance.sh
```

---

## 📚 Deep Dive (Advanced Topics)

<details>
<summary>Multi-Site Disaster Recovery (Geographic Redundancy)</summary>

**Scenario:** Primary site destroyed (fire, flood)

**Architecture:**

```
Primary Site (Home)
  ├─ K3s Cluster
  ├─ Local Backups (USB)
  └─ Offsite Backup (Backblaze B2)
      └─ Cross-Region Replication

Secondary Site (Cloud VM)
  ├─ Standby K3s Cluster
  └─ Reads from same B2 bucket
```

**Failover Process:**

1. User accesses secondary site URL
2. Secondary cluster pulls configs from GitOps
3. Restores data from B2 (same bucket)
4. User provides decryption key
5. Services start on secondary site

**RTO:** 1 hour (cloud provisioning + restore)

</details>

<details>
<summary>Point-in-Time Recovery (Ransomware)</summary>

**Scenario:** Crypto-locker encrypted files

```bash
# 1. List snapshots before incident
restic snapshots --compact

# 2. Find last good snapshot
restic snapshots | grep "2025-12-15"
# abc123def 2025-12-15 14:00:00

# 3. Restore specific snapshot
restic restore abc123def --target /mnt/data

# 4. Verify integrity before bringing online
restic check --read-data

# 5. Start services
kubectl apply -f services/
```

**Key:** Backups are immutable append-only (ransomware can't encrypt)

</details>

---

## 🔗 Cross-References

**Next Steps:**

- **Operational Monitoring:** [OPS-PICERL-IDENTIFICATION](OPS-PICERL-IDENTIFICATION.md)
- **Security Recovery:** [SECURITY-PICERL-RECOVERY](SECURITY-PICERL-RECOVERY.md) (breach scenarios)

**Related Docs:**

- Setup Guide: [OPS-PICERL-PREPARATION](OPS-PICERL-PREPARATION.md)
- Antigravity Architecture: [ANTIGRAVITY-ARCHITECTURE](ANTIGRAVITY-ARCHITECTURE.md)

---

**Document Status:** ✅ Complete - Ready for disaster recovery operations
