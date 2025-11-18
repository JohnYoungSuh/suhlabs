# Family Name Variable Management

## Overview

The `$family_name` variable is the **primary identifier** for multi-tenant family instances across the entire suhlabs infrastructure. It follows these rules:

- **IT Ops**: Always use `$family_name` (lowercase, alphanumeric, hyphens only)
- **AI Ops/Sec Bot**: Use `$preferred_name` when talking to customers (display name)
- **Internal Systems**: Always reference `$family_name` for namespacing, tagging, isolation

---

## Variable Definitions

### `$family_name`
- **Format**: Lowercase alphanumeric + hyphens (e.g., `smith`, `garcia-family`)
- **Purpose**: IT ops identifier, namespace isolation, resource naming
- **Usage**: All internal infrastructure, Kubernetes resources, Vault paths, metrics tags
- **Example**: `smith` → `photoprism-smith` namespace, `photos.smith.family` domain

### `$preferred_name`
- **Format**: Any display name (e.g., "The Smith Family", "García Family Photos")
- **Purpose**: Customer-facing display in UI and AI bot conversations
- **Usage**: AI Ops bot greetings, email notifications, UI headers
- **Example**: "Hi, The Smith Family! Your photo storage is at 85%..."

---

## Where `$family_name` Must Be Set

### 1. **Kubernetes Resources** (Multi-Tenancy Isolation)

#### Namespace
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: photoprism-$family_name
  labels:
    app: photoprism
    family: $family_name
    managed-by: ai-ops-agent
```

**Files to Update:**
- `services/photoprism/kubernetes/00-namespace.yaml`
- Make it a template with `$family_name` placeholder

#### Storage (PVCs)
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: minio-photos-$family_name
  namespace: photoprism-$family_name
  labels:
    family: $family_name
spec:
  resources:
    requests:
      storage: 1Ti
```

**Files to Update:**
- `services/photoprism/kubernetes/01-storage.yaml`
- PVC names: `mariadb-data-$family_name`, `minio-photos-$family_name`, `photoprism-cache-$family_name`

#### Deployments & StatefulSets
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: photoprism-$family_name
  namespace: photoprism-$family_name
  labels:
    family: $family_name
spec:
  selector:
    matchLabels:
      app: photoprism
      family: $family_name
  template:
    metadata:
      labels:
        family: $family_name
```

**Files to Update:**
- `services/photoprism/kubernetes/02-minio.yaml`
- `services/photoprism/kubernetes/03-mariadb.yaml`
- `services/photoprism/kubernetes/04-photoprism.yaml`

#### Services
```yaml
apiVersion: v1
kind: Service
metadata:
  name: photoprism-$family_name
  namespace: photoprism-$family_name
  labels:
    family: $family_name
```

**Files to Update:**
- All service definitions in kubernetes/*.yaml

#### Ingress (Domain Routing)
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: photoprism-$family_name
  namespace: photoprism-$family_name
  labels:
    family: $family_name
  annotations:
    cert-manager.io/cluster-issuer: "vault-issuer"
spec:
  tls:
  - hosts:
    - photos.$family_name.family
    - minio.photos.$family_name.family
    secretName: photoprism-$family_name-tls
  rules:
  - host: photos.$family_name.family
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: photoprism-$family_name
            port:
              number: 2342
```

**Files to Update:**
- `services/photoprism/kubernetes/05-ingress.yaml`

#### ConfigMaps & Secrets
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: photoprism-config-$family_name
  namespace: photoprism-$family_name
  labels:
    family: $family_name
data:
  PHOTOPRISM_SITE_URL: "https://photos.$family_name.family"
  PHOTOPRISM_SITE_TITLE: "$preferred_name Photos"  # Customer-facing
```

**Files to Update:**
- `services/photoprism/kubernetes/04-photoprism.yaml` (ConfigMap section)
- All secrets in kubernetes/*.yaml

---

### 2. **DNS & Domain Management**

#### Domain Structure
```
Primary Domain:       photos.$family_name.family
MinIO Console:        minio.photos.$family_name.family
Authelia SSO:         auth.$family_name.family
```

**Files to Update:**
- `cluster/ai-ops-agent/ai_ops_agent/domain/__init__.py`
  - `configure_dns()` method already uses `family_name` parameter ✅
- `services/photoprism/kubernetes/05-ingress.yaml`

#### DNS A Records (Auto-configured during onboarding)
```python
dns_records = [
    {
        "type": "A",
        "name": f"photos.{family_name}.family",
        "value": ingress_ip,
        "ttl": 300
    },
    {
        "type": "A",
        "name": f"minio.photos.{family_name}.family",
        "value": ingress_ip,
        "ttl": 300
    },
    {
        "type": "A",
        "name": f"auth.{family_name}.family",
        "value": ingress_ip,
        "ttl": 300
    }
]
```

**Already Implemented:**
- ✅ `cluster/ai-ops-agent/ai_ops_agent/domain/__init__.py:configure_dns()`

---

### 3. **Vault (Secrets Management)**

#### Secret Paths
```
Vault Path Structure:
secret/photoprism/$family_name/minio
secret/photoprism/$family_name/mariadb
secret/photoprism/$family_name/admin
secret/photoprism/$family_name/authelia
```

**Files to Create/Update:**
- Update deployment script to use Vault with family-specific paths
- `services/photoprism/deploy.sh` - Add Vault secret creation

#### Example Vault Commands
```bash
# Store MinIO credentials per family
vault kv put secret/photoprism/$family_name/minio \
  rootUser=minio-$family_name \
  rootPassword=$generated_password

# Store PhotoPrism admin password
vault kv put secret/photoprism/$family_name/admin \
  password=$admin_password \
  email=$contact_email
```

**Files to Update:**
- `services/photoprism/deploy.sh`
- Add Vault integration section
- Create `services/photoprism/scripts/setup-vault-secrets.sh`

---

### 4. **Monitoring & Observability**

#### Prometheus Metrics Labels
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: photoprism-storage-alerts-$family_name
  namespace: photoprism-$family_name
  labels:
    family: $family_name
spec:
  groups:
  - name: photoprism-storage-$family_name
    rules:
    - alert: PhotoPrismStorageHigh
      expr: |
        (
          sum(kubelet_volume_stats_used_bytes{
            namespace="photoprism-$family_name",
            persistentvolumeclaim="minio-photos-$family_name"
          })
          / sum(kubelet_volume_stats_capacity_bytes{
            namespace="photoprism-$family_name",
            persistentvolumeclaim="minio-photos-$family_name"
          })
        ) * 100 > 80
      labels:
        severity: warning
        family: $family_name
        family_facing: "true"
      annotations:
        summary: "Storage alert for $preferred_name"  # Customer-facing
        ai_ops_message: |
          📊 Hi $preferred_name! Your PhotoPrism storage is at {{ $value }}% capacity...
```

**Files to Update:**
- `services/photoprism/monitoring/storage-alerts.yaml`
- Make it a template with `$family_name` and `$preferred_name` placeholders

#### ServiceMonitor
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: photoprism-$family_name
  namespace: photoprism-$family_name
  labels:
    family: $family_name
spec:
  selector:
    matchLabels:
      app: photoprism
      family: $family_name
```

**Files to Update:**
- `services/photoprism/monitoring/storage-alerts.yaml`

---

### 5. **AI Ops Agent**

#### Onboarding State Storage
```python
# Store onboarding state with family_name as key
state = OnboardingState(
    session_id=session_id,
    family_name=user_input.lower().strip(),  # IT ops identifier
    preferred_name=user_input,                # Customer-facing name
    current_step=OnboardingStep.CHECK_DOMAIN
)
```

**Files Already Using:**
- ✅ `cluster/ai-ops-agent/ai_ops_agent/onboarding/__init__.py`

#### Intent Mappings
```yaml
provision:
  onboard:
    photoprism:
      default_vars:
        family_name: null  # REQUIRED: Collected during onboarding
        preferred_name: null  # OPTIONAL: Display name for customer
        domain: "photos.$family_name.family"
```

**Files Already Updated:**
- ✅ `cluster/ai-ops-agent/config/intent-mappings.yaml`

#### Conversational Messages
```python
# AI Ops Bot uses preferred_name when talking to customers
message = f"""
👋 Hi {state.preferred_name}! Welcome to PhotoPrism.

I'm setting up your family photo library at:
🌐 https://photos.{state.family_name}.family

This will take about 15 minutes...
"""
```

**Files to Update:**
- `cluster/ai-ops-agent/ai_ops_agent/onboarding/__init__.py`
- Replace hardcoded "What's your family name?" with variable usage

---

### 6. **Deployment Scripts**

#### deploy.sh Template Variables
```bash
#!/bin/bash
# PhotoPrism Deployment Script for K3s

FAMILY_NAME="${FAMILY_NAME:-}"
PREFERRED_NAME="${PREFERRED_NAME:-$FAMILY_NAME}"
DOMAIN="${DOMAIN:-photos.$FAMILY_NAME.family}"

# Validate family_name is set
if [ -z "$FAMILY_NAME" ]; then
    echo "Error: FAMILY_NAME environment variable required"
    exit 1
fi

# Create namespace with family_name
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: photoprism-$FAMILY_NAME
  labels:
    family: $FAMILY_NAME
EOF
```

**Files to Update:**
- `services/photoprism/deploy.sh`
- Accept `$FAMILY_NAME` as required parameter
- Template all resources with `$FAMILY_NAME`

---

### 7. **Authelia (SSO/LDAP)**

#### Authelia Configuration per Family
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: authelia-config-$family_name
  namespace: authelia
  labels:
    family: $family_name
data:
  configuration.yml: |
    default_redirection_url: https://photos.$family_name.family

    session:
      domain: $family_name.family

    access_control:
      rules:
        - domain: photos.$family_name.family
          policy: two_factor
          subject:
            - "group:$family_name"
```

**Files to Update:**
- `services/photoprism/kubernetes/06-authelia.yaml`
- Create per-family Authelia instances OR
- Create shared Authelia with multi-domain support (recommended)

---

### 8. **Logging & Audit Trails**

#### Log Structured Fields
```json
{
  "timestamp": "2025-11-18T10:30:00Z",
  "level": "INFO",
  "service": "photoprism",
  "family_name": "smith",
  "preferred_name": "The Smith Family",
  "action": "photo_upload",
  "user": "admin",
  "message": "User uploaded 50 photos"
}
```

**Files to Update:**
- PhotoPrism deployment should inject `FAMILY_NAME` env var
- Structured logging middleware in AI Ops agent

---

### 9. **Billing & Usage Tracking** (Future)

#### Resource Tagging
```yaml
tags:
  managed_by: "ai-ops-agent"
  service: "photoprism"
  family: $family_name
  billing_entity: $family_name
  environment: "production"
```

**Usage:**
- Tag all cloud resources (if using cloud storage)
- Track storage usage per family
- Calculate costs per family for billing

---

### 10. **Database Multi-Tenancy** (MariaDB)

#### Database per Family
```sql
-- Create database with family_name
CREATE DATABASE photoprism_$family_name;

-- Create user with family_name
CREATE USER 'photoprism_$family_name'@'%'
  IDENTIFIED BY '$generated_password';

-- Grant permissions
GRANT ALL PRIVILEGES ON photoprism_$family_name.*
  TO 'photoprism_$family_name'@'%';
```

**Files to Update:**
- `services/photoprism/kubernetes/03-mariadb.yaml`
- Add init script to create per-family databases
- Or use separate MariaDB instance per family (current approach is better for isolation)

---

## Implementation Checklist

### High Priority (Required for Onboarding)
- [ ] Template `services/photoprism/kubernetes/*.yaml` with `$family_name` placeholders
- [ ] Update `services/photoprism/deploy.sh` to accept `FAMILY_NAME` parameter
- [ ] Update AI Ops agent to use `$preferred_name` in customer messages
- [ ] Configure Vault secret paths with `$family_name`
- [ ] Update Prometheus alerts with `$family_name` labels

### Medium Priority (Required for Production)
- [ ] Create deployment template engine (Jinja2/Helm/Kustomize)
- [ ] Implement multi-tenant Authelia or per-family instances
- [ ] Add `family` label to all Kubernetes resources
- [ ] Configure structured logging with `family_name` field
- [ ] Update backup scripts to backup per-family resources

### Low Priority (Future Enhancements)
- [ ] Implement usage tracking per family for billing
- [ ] Create family-specific dashboards in Grafana
- [ ] Add family context to all audit logs
- [ ] Implement family-based RBAC policies

---

## Template Engine Options

Based on your project design, I recommend **Kustomize** for templating:

### Option 1: Kustomize (Recommended)
```
services/photoprism/
├── base/
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── storage.yaml
│   ├── minio.yaml
│   ├── mariadb.yaml
│   ├── photoprism.yaml
│   └── ingress.yaml
└── overlays/
    ├── smith/
    │   ├── kustomization.yaml
    │   └── family-patch.yaml
    └── garcia/
        ├── kustomization.yaml
        └── family-patch.yaml
```

**Benefits:**
- Native to kubectl
- No external dependencies
- Supports variable substitution
- Works with GitOps (ArgoCD/Flux)

### Option 2: Helm Charts
```
services/photoprism/
└── helm-chart/
    ├── Chart.yaml
    ├── values.yaml
    ├── templates/
    │   ├── namespace.yaml
    │   ├── storage.yaml
    │   └── ...
    └── values-families/
        ├── smith.yaml
        └── garcia.yaml
```

**Benefits:**
- Rich templating with Go templates
- Package management
- Version control for deployments

### Option 3: Ansible with Jinja2 Templates (Current Approach)
Keep deployment script but use Jinja2 templating:
```bash
ansible-playbook \
  -e family_name=smith \
  -e preferred_name="The Smith Family" \
  services/photoprism/deploy-playbook.yml
```

---

## Example: Full Deployment Command

```bash
# Onboarding via AI Ops bot
curl -X POST https://ai-ops.suhlabs.io/api/v1/photoprism/onboard \
  -H "Content-Type: application/json" \
  -d '{
    "family_name": "smith",
    "preferred_name": "The Smith Family",
    "contact_email": "admin@smith.family",
    "enable_gpu": true,
    "enable_authelia": true,
    "storage_size": "1Ti"
  }'

# Manual deployment (IT ops)
FAMILY_NAME=smith \
PREFERRED_NAME="The Smith Family" \
CONTACT_EMAIL=admin@smith.family \
./services/photoprism/deploy.sh
```

---

## Summary

**$family_name** must be set in:

1. ✅ **AI Ops Agent** - Intent mappings, onboarding flow, domain module
2. ⏳ **Kubernetes Resources** - Namespaces, PVCs, Deployments, Services, Ingress
3. ⏳ **DNS Records** - Domain registration and A record configuration
4. ⏳ **Vault Paths** - Secret storage per family
5. ⏳ **Monitoring** - Prometheus labels, ServiceMonitor, alerts
6. ⏳ **Deployment Scripts** - Template variables in deploy.sh
7. ⏳ **Authelia** - Per-family SSO configuration
8. ⏳ **Logs** - Structured logging fields
9. 🔮 **Billing** - Resource tagging (future)
10. ⏳ **Database** - Per-family database naming

**Next Steps:**
1. Choose templating engine (Kustomize recommended)
2. Convert all Kubernetes manifests to templates
3. Update deploy.sh to use $FAMILY_NAME parameter
4. Test end-to-end onboarding flow
