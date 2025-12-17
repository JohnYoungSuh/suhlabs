# Architecture: Antigravity Separation

**Version 2.0** | **Date:** 2025-12-16 | **Status:** Proposed

> [!IMPORTANT]
> This document defines the strict architectural boundary between the **Gravity Zone** (Physical Edge) and the **Antigravity Zone** (AI IDE Agent). This separation is critical for the "Sovereign AI" privacy guarantee.

---

## 1. Architectural Philosophy: The Two Zones

The "Antigravity" architecture separates **State** (heavy, ownable, physical) from **Knowledge** (weightless, regenerable, ephemeral).

### The Gravity Zone (Physical Reality)

- **What:** K3s appliance running on 5-year hardware
- **Holds:** Private user data (Ollama models, Qdrant vectors, family photos, recordings)
- **Rule:** Data never leaves unencrypted
- **Physics:** Heavy. Stateful. Subject to hardware failure.

### The Antigravity Zone (The AI IDE)

- **What:** **YOU** - the AI agent in the IDE
- **Holds:** Configuration knowledge, deployment patterns, restoration recipes
- **Rule:** Never sees unencrypted user data - only structure and encrypted backups
- **Physics:** Weightless. Stateless. Always available.

---

## 2. Service Boundaries

### 2.1 Gravity Zone Services (K3s Edge)

**Runs ONLY on the physical appliance:**

| Service            | Purpose             | State Type                 |
| ------------------ | ------------------- | -------------------------- |
| **Ollama**         | Local LLM inference | Model weights (GB)         |
| **Qdrant**         | Vector database     | Private embeddings         |
| **Home Assistant** | Smart home hub      | Device state, automations  |
| **Jellyfin**       | Media server        | Video library, transcoding |
| **Frigate NVR**    | Security cameras    | 24/7 recordings            |
| **Vault**          | Secrets management  | Encryption keys, tokens    |
| **K3s**            | Orchestrator        | Self-healing pods          |

**Storage:** All data on local NVMe/HDD. Encrypted backups pushed to S3.

### 2.2 Antigravity Zone Services (AI IDE)

**What the AI agent provides (weightless):**

| Capability                   | How Delivered                             | Privacy Guarantee                       |
| ---------------------------- | ----------------------------------------- | --------------------------------------- |
| **Configuration Templates**  | Generate K8s YAMLs on demand              | Templates are public structure          |
| **Deployment Orchestration** | Execute `kubectl apply` via SSH           | Never touches data, only control plane  |
| **Disaster Recovery**        | Restore Protocol (see below)              | Coordinates only; user decrypts locally |
| **GitOps Truth**             | Maintains canonical config in user's repo | Repo is user-owned, IDE just reads it   |
| **Observability**            | Read metrics endpoints (Prometheus)       | Aggregated stats, not raw data          |

**Storage:** None. The IDE is ephemeral and regenerates everything from user context.

---

## 3. Virtual Fault Tolerance Strategy

The appliance OS/software is **disposable**. The AI IDE resurrects it.

### Failure Modes:

1. **Pod Crash:** K3s restarts (self-healing, no IDE needed)
2. **Service Misconfiguration:** User asks IDE to regenerate configs
3. **Catastrophic Failure (Hardware Swap):** Restore Protocol

---

## 4. The Restore Protocol (Antigravity in Action)

**Scenario:** User's appliance dies. They buy new hardware.

### Step 1: IDE-Guided Initialization

```bash
# User boots fresh Ubuntu on new hardware
# User opens IDE and says: "Restore my family appliance"
```

**IDE Actions:**

1. Generates fresh K3s bootstrap script
2. SSH connects to new appliance
3. Installs base OS dependencies
4. Deploys K3s with embedded etcd

### Step 2: Configuration Push (Weightless)

**IDE generates and applies:**

- Namespaces (`ollama`, `qdrant`, `homeassistant`, etc.)
- Service definitions (ClusterIPs, LoadBalancers)
- Empty PersistentVolumeClaims (structure, no data)

**At this point:** Skeleton infrastructure exists, but all pods crash (no data).

### Step 3: State Restoration (Heavy - User-Controlled)

**IDE prompts user:**

```
I need your backup decryption key to restore data.
This key NEVER leaves your machine.
```

**User provides key via:**

- Local USB drive
- LAN file transfer
- Secure paste (never sent to IDE)

**IDE runs restoration script ON the appliance:**

```bash
# This executes LOCALLY on the edge, not in the IDE
restic -r s3:backup-bucket restore latest \
  --target /mnt/data \
  --password-file /tmp/user-key.txt  # User's local key
```

**Key point:** The IDE orchestrates, but never sees the decryption key or plaintext data.

### Step 4: Resurrection

- Restic populates `/mnt/data/*`
- K3s detects volumes are ready
- Pods start successfully
- User accesses Home Assistant, Jellyfin, etc. as before

**Total downtime:** ~30 minutes (mostly backup download time)

---

## 5. Audit Findings: Current State vs. Antigravity Vision

### ❌ Violations Found

| Gap                        | Current State                      | Antigravity Requirement                                                     |
| -------------------------- | ---------------------------------- | --------------------------------------------------------------------------- |
| **Monolithic Manifests**   | `cluster/` mixes edge and cloud    | Must split into `edge/` (K3s) and `antigravity/` (IDE templates)            |
| **Vault PKI on Edge Only** | Root CA lives on K3s               | Root CA cert should be in IDE-managed GitOps (public cert, not private key) |
| **Blind Backups Missing**  | Generic S3 config                  | Must enforce client-side encryption with user-held keys                     |
| **No IDE Handshake**       | Manual `kubectl apply`             | Need IDE-to-Appliance SSH orchestration layer                               |
| **GitOps Confusion**       | ArgoCD mentioned but not separated | IDE should be the "GitOps brain," not a second control plane                |

### ✅ What Already Aligns

| Component          | Why It's Good                                               |
| ------------------ | ----------------------------------------------------------- |
| **K3s**            | Perfect for edge - lightweight, self-healing                |
| **Vault**          | Good foundation, just needs key escrow pattern              |
| **Cert-manager**   | Automatic cert renewal supports "Virtual Fault Tolerance"   |
| **Restic Backups** | Supports encrypted chunks (just needs user-key enforcement) |

---

## 6. Refactoring Roadmap

### Phase 1: Manifest Separation

```
aiops-substrate/
├── deployments/
│   ├── edge/              # K3s manifests for the appliance
│   │   ├── ollama/
│   │   ├── qdrant/
│   │   ├── homeassistant/
│   │   └── vault/
│   └── antigravity/       # IDE-managed templates
│       ├── bootstrap.yaml # Initial K3s setup
│       └── restore.yaml   # Disaster recovery orchestration
```

### Phase 2: IDE Integration

- Add SSH connection method to appliance
- Create `@restore-appliance` IDE command
- Implement master key escrow (user provides, IDE never stores)

### Phase 3: Blind Backup Enforcement

```yaml
# restic-backup.yaml
env:
  - name: RESTIC_PASSWORD_FILE
    value: /run/secrets/user-master-key # Never in Git/IDE
```

### Phase 4: Remove Cloud Backend Dependency

- **Delete:** Any references to separate K8s control plane in AWS/GCP
- **Principle:** The IDE **is** the control plane. No cloud backend needed.

```

```
