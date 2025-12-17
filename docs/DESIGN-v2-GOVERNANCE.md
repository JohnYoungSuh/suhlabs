# DESIGN-v2-GOVERNANCE: Edge Governance Service Layer

**Version:** 2.0  
**Date:** 2025-12-16  
**Purpose:** Deploy the AI Agent Governance Framework as active K3s services on the edge

---

## Evaluation: Governance Gap Audit

### ❌ Critical Gaps Found

**Governance Framework Reference Exists:**

- ✅ Ansible task `ansible/tasks/ask_governance.yml` - Permission-First API handshake
- ✅ Mock server `scripts/mock_governance_server.py` - Test implementation
- ✅ Documentation references `/home/suhlabs/projects/suhlabs/ai-agent-governance-framework/`

**Missing Active Services:**

- ❌ **No `otel-siem-emitter` K8s Deployment** - Governance framework tools not containerized
- ❌ **No `pki-validator` K8s Service** - Certificate validation runs as manual script only
- ❌ **No Policy Agent** - No service to fetch `risk-catalog.json` from backend
- ❌ **No Sidecar Pattern** - Ollama/AI-Ops-Agent lack governance middleware injection

**Current AI Ops Agent Deployment:**

- File: `cluster/ai-ops-agent/deployment/ai-ops-agent.yaml`
- Containers: Single `agent` container (no sidecars)
- Logs: Written to `/var/log/ai-ops` but not piped through SIEM emitter

---

## Design: The Three-Layer Governance Stack

```
┌─────────────────────────────────────────────────┐
│   Edge Governance Architecture (K3s)            │
├─────────────────────────────────────────────────┤
│                                                  │
│  ┌────────────────────────────────────────┐    │
│  │  Layer 1: Policy Sync (Pull from IDE)  │    │
│  │  ┌──────────────────────────────────┐  │    │
│  │  │  policy-agent CronJob            │  │    │
│  │  │  - Fetches risk-catalog.json     │  │    │
│  │  │  - Stores in ConfigMap           │  │    │
│  │  └──────────────────────────────────┘  │    │
│  └────────────────────────────────────────┘    │
│                    ↓                            │
│  ┌────────────────────────────────────────┐    │
│  │  Layer 2: Governance Sidecars          │    │
│  │  ┌──────────────────────────────────┐  │    │
│  │  │  ai-ops-agent Pod:               │  │    │
│  │  │  ├─ agent (main)                 │  │    │
│  │  │  └─ otel-siem-emitter (sidecar)  │  │    │
│  │  └──────────────────────────────────┘  │    │
│  │  ┌──────────────────────────────────┐  │    │
│  │  │  ollama Pod:                     │  │    │
│  │  │  ├─ ollama (main)                │  │    │
│  │  │  └─ pki-validator (sidecar)      │  │    │
│  │  └──────────────────────────────────┘  │    │
│  └────────────────────────────────────────┘    │
│                    ↓                            │
│  ┌────────────────────────────────────────┐    │
│  │  Layer 3: Blind Telemetry Egress       │    │
│  │  ┌──────────────────────────────────┐  │    │
│  │  │  otel-collector Deployment       │  │    │
│  │  │  - Receives SIEM events          │  │    │
│  │  │  - Encrypts & forwards to S3     │  │    │
│  │  │  (Antigravity IDE never decrypts)│  │    │
│  │  └──────────────────────────────────┘  │    │
│  └────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘
```

---

## Component 1: Policy Agent (Layer 1)

### CronJob: policy-sync

**Purpose:** Fetch the latest governance policies from the IDE-managed GitOps repo.

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: policy-sync
  namespace: governance
spec:
  schedule: "*/15 * * * *" # Every 15 minutes
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: sync
              image: curlimages/curl:latest
              command:
                - /bin/sh
                - -c
                - |
                  # Fetch from IDE-managed S3 bucket or Git repo
                  curl -o /tmp/risk-catalog.json \
                    https://governance.suhlabs.io/policies/risk-catalog.json
                  kubectl create configmap governance-policies \
                    --from-file=/tmp/risk-catalog.json \
                    --dry-run=client -o yaml | kubectl apply -f -
          restartPolicy: OnFailure
```

**Result:** ConfigMap `governance-policies` updated every 15 minutes with latest risk definitions.

---

## Component 2: SIEM Emitter Sidecar (Layer 2)

### Deployment Modification: ai-ops-agent

**Add sidecar container** to `cluster/ai-ops-agent/deployment/ai-ops-agent.yaml`:

```yaml
spec:
  template:
    spec:
      containers:
        - name: agent # Existing container
          # ... existing config
          volumeMounts:
            - name: shared-logs
              mountPath: /var/log/ai-ops

        # NEW: SIEM Emitter Sidecar
        - name: siem-emitter
          image: ghcr.io/johnyoungsuh/otel-siem-emitter:1.0.0
          env:
            - name: OTEL_EXPORTER_OTLP_ENDPOINT
              value: "http://otel-collector.governance:4317"
            - name: LOG_WATCH_PATH
              value: "/var/log/ai-ops/*.log"
          volumeMounts:
            - name: shared-logs
              mountPath: /var/log/ai-ops
              readOnly: true
            - name: policy-config
              mountPath: /etc/governance
              readOnly: true

      volumes:
        - name: shared-logs
          emptyDir: {}
        - name: policy-config
          configMap:
            name: governance-policies
```

**Flow:**

1. AI Ops Agent writes decisions to `/var/log/ai-ops/decisions.log`
2. SIEM Emitter sidecar tails the log
3. Emitter reads `risk-catalog.json` from mounted ConfigMap
4. Emitter tags events with risk scores
5. Emitter sends to OpenTelemetry Collector

---

## Component 3: PKI Validator Sidecar

### Deployment Modification: ollama

**Add sidecar** to `cluster/ai-ops-agent/deployment/ollama.yaml`:

```yaml
spec:
  template:
    spec:
      containers:
        - name: ollama # Existing
          # ... existing config

        # NEW: PKI Validator Sidecar
        - name: pki-validator
          image: ghcr.io/johnyoungsuh/pki-validator:1.0.0
          command:
            - /bin/sh
            - -c
            - |
              # Run validation every 60 seconds
              while true; do
                python3 /app/validate_pki.py \
                  --vault-addr http://vault.vault:8200 \
                  --policy-file /etc/governance/risk-catalog.json \
                  --emit-to otel-collector.governance:4317
                sleep 60
              done
          volumeMounts:
            - name: policy-config
              mountPath: /etc/governance
```

**Function:** Continuously validates Vault PKI certificates against governance policy.

---

## Component 4: OpenTelemetry Collector (Layer 3)

### Deployment: otel-collector

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-collector
  namespace: governance
spec:
  replicas: 1
  selector:
    matchLabels:
      app: otel-collector
  template:
    metadata:
      labels:
        app: otel-collector
    spec:
      containers:
        - name: collector
          image: otel/opentelemetry-collector-contrib:0.91.0
          ports:
            - containerPort: 4317 # OTLP gRPC
            - containerPort: 4318 # OTLP HTTP
          volumeMounts:
            - name: config
              mountPath: /etc/otel
      volumes:
        - name: config
          configMap:
            name: otel-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-config
  namespace: governance
data:
  config.yaml: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
    processors:
      batch: {}
    exporters:
      file:
        path: /var/log/otel/siem-events.jsonl
      # Future: S3 exporter with client-side encryption
    service:
      pipelines:
        logs:
          receivers: [otlp]
          processors: [batch]
          exporters: [file]
```

**Privacy:** Logs are encrypted before leaving the edge. Antigravity IDE sees only aggregated metrics, not raw data.

---

## Component 5: Containerization Plan

### Dockerfile: otel-siem-emitter

```dockerfile
FROM python:3.11-slim
WORKDIR /app

# Copy governance framework scripts
COPY ai-agent-governance-framework/scripts/otel_siem_emitter.py /app/
COPY ai-agent-governance-framework/risk-catalog.json /app/defaults/

RUN pip install opentelemetry-api opentelemetry-sdk opentelemetry-exporter-otlp

ENTRYPOINT ["python3", "/app/otel_siem_emitter.py"]
```

### Dockerfile: pki-validator

```dockerfile
FROM python:3.11-slim
WORKDIR /app

COPY ai-agent-governance-framework/scripts/pki_validator.py /app/
COPY ai-agent-governance-framework/scripts/vault_api.py /app/

RUN pip install hvac opentelemetry-api

ENTRYPOINT ["python3", "/app/pki_validator.py"]
```

---

## Implementation Roadmap

### Phase 1: Containerization (Week 1)

- [ ] Create `otel-siem-emitter` Docker image
- [ ] Create `pki-validator` Docker image
- [ ] Publish to `ghcr.io/johnyoungsuh/`

### Phase 2: K3s Deployment (Week 2)

- [ ] Deploy `policy-sync` CronJob
- [ ] Create `governance` namespace
- [ ] Deploy OpenTelemetry Collector
- [ ] Test with mock governance server

### Phase 3: Sidecar Injection (Week 3)

- [ ] Update `ai-ops-agent.yaml` with SIEM sidecar
- [ ] Update `ollama.yaml` with PKI validator sidecar
- [ ] Verify shared volume logging

### Phase 4: Integration Testing (Week 4)

- [ ] Trigger AI decision → Verify SIEM emission
- [ ] Expire Vault cert → Verify PKI alert
- [ ] Update policy → Verify CronJob sync

---

## Privacy Guarantee

**Antigravity IDE Role:**

- Provides policy definitions (public structure)
- Receives encrypted SIEM events (aggregated metrics only)
- NEVER decrypts edge telemetry

**User Data Protection:**

- All governance runs on the edge
- Logs encrypted at rest (Vault)
- S3 uploads client-side encrypted
- Decryption keys user-controlled
