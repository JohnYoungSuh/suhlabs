# PhotoPrism Onboarding - Knowledge Transfer Document

**Project:** PhotoPrism Multi-Tenant Family Onboarding Automation
**Branch:** `claude/ai-ops-sec-automation-01LjtHd9Wa4HeRqxAdmPknMm`
**Date:** November 18, 2025
**Status:** Phase 1 Complete - 5 Enhancement Tasks Remaining

---

## Executive Summary

This document provides a complete knowledge transfer for the PhotoPrism onboarding automation system. Phase 1 (conversational onboarding framework) is **complete and committed**. Five enhancement tasks remain for full production readiness.

### What's Been Built (Phase 1 - Complete ✅)

1. **Conversational Onboarding Flow** - 8-step state machine guiding families through setup
2. **Domain Management Module** - Multi-registrar framework (scaffolded, not fully implemented)
3. **Multi-Tenant Kustomize Templates** - Base templates for namespace, storage, monitoring
4. **Storage Monitoring** - Prometheus alerts at 80% capacity
5. **API Endpoints** - 3 FastAPI endpoints for onboarding
6. **Documentation** - Complete guides for `$family_name` usage and onboarding

### What Remains (Phase 2 - To Do)

1. **Complete Kustomize Base Templates** - Add MinIO, MariaDB, PhotoPrism, Ingress YAML
2. **Implement Domain Registrar APIs** - Real API integration for Cloudflare/Namecheap/GoDaddy
3. **Add Prometheus Metrics Integration** - Replace mock data with real queries
4. **Create End-to-End Test Script** - Automated testing for full onboarding flow
5. **Add Billing Integration** - Usage tracking and cost calculation per family

---

## Task 1: Complete Kustomize Base Templates

### Current State

**What Exists:**
- ✅ `kustomize/base/kustomization.yaml` - Base configuration with variable placeholders
- ✅ `kustomize/base/namespace.yaml` - Namespace template
- ✅ `kustomize/base/storage.yaml` - PVC templates (3 volumes)
- ✅ `kustomize/base/monitoring.yaml` - Prometheus ServiceMonitor and alerts
- ✅ `kustomize/overlays/example-smith/` - Example family overlay

**What's Missing:**
- ❌ `kustomize/base/minio.yaml` - MinIO S3-compatible storage deployment
- ❌ `kustomize/base/mariadb.yaml` - MariaDB database StatefulSet
- ❌ `kustomize/base/photoprism.yaml` - PhotoPrism application Deployment
- ❌ `kustomize/base/ingress.yaml` - Ingress with TLS for all services

### Why This Matters

The existing `services/photoprism/kubernetes/*.yaml` files have hardcoded values. We need Kustomize templates with `$FAMILY_NAME` placeholders so each family gets isolated resources.

### What You Need to Do

#### Step 1: Create MinIO Base Template

**File:** `services/photoprism/kustomize/base/minio.yaml`

**Source Reference:** `services/photoprism/kubernetes/02-minio.yaml` (copy and modify)

**Required Changes:**
1. Replace namespace: `photoprism` → `photoprism-FAMILY_NAME`
2. Replace resource names: `minio` → `minio-FAMILY_NAME`
3. Add labels: `family: FAMILY_NAME`
4. Update PVC references to use templated names
5. Update service names to include family

**Template Structure:**
```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: minio-credentials
  namespace: photoprism-FAMILY_NAME
  labels:
    family: FAMILY_NAME
type: Opaque
stringData:
  rootUser: "minio-FAMILY_NAME"
  rootPassword: "PLACEHOLDER"  # Replaced by Vault in deployment

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  namespace: photoprism-FAMILY_NAME
  labels:
    app: minio
    family: FAMILY_NAME
spec:
  replicas: 1
  selector:
    matchLabels:
      app: minio
      family: FAMILY_NAME
  template:
    metadata:
      labels:
        app: minio
        family: FAMILY_NAME
    spec:
      containers:
      - name: minio
        image: minio/minio:RELEASE.2024-01-16T16-07-38Z
        args:
        - server
        - /data
        - --console-address
        - ":9001"
        env:
        - name: MINIO_ROOT_USER
          valueFrom:
            secretKeyRef:
              name: minio-credentials
              key: rootUser
        - name: MINIO_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: minio-credentials
              key: rootPassword
        ports:
        - containerPort: 9000
          name: api
        - containerPort: 9001
          name: console
        volumeMounts:
        - name: data
          mountPath: /data
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: minio-photos

---
apiVersion: v1
kind: Service
metadata:
  name: minio
  namespace: photoprism-FAMILY_NAME
  labels:
    app: minio
    family: FAMILY_NAME
spec:
  type: ClusterIP
  ports:
  - port: 9000
    targetPort: 9000
    protocol: TCP
    name: api
  - port: 9001
    targetPort: 9001
    protocol: TCP
    name: console
  selector:
    app: minio
    family: FAMILY_NAME

---
# MinIO bucket initialization job
apiVersion: batch/v1
kind: Job
metadata:
  name: minio-init-FAMILY_NAME
  namespace: photoprism-FAMILY_NAME
  labels:
    family: FAMILY_NAME
spec:
  template:
    spec:
      restartPolicy: OnFailure
      containers:
      - name: mc
        image: minio/mc:latest
        command:
        - /bin/sh
        - -c
        - |
          mc alias set myminio http://minio:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD
          mc mb myminio/photoprism-FAMILY_NAME || true
          mc anonymous set download myminio/photoprism-FAMILY_NAME/public || true
        env:
        - name: MINIO_ROOT_USER
          valueFrom:
            secretKeyRef:
              name: minio-credentials
              key: rootUser
        - name: MINIO_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: minio-credentials
              key: rootPassword
```

**Testing:**
```bash
# Validate template
kustomize build services/photoprism/kustomize/overlays/example-smith | grep -A5 "kind: Deployment"

# Check MinIO service exists
kustomize build services/photoprism/kustomize/overlays/example-smith | grep "name: minio"
```

---

#### Step 2: Create MariaDB Base Template

**File:** `services/photoprism/kustomize/base/mariadb.yaml`

**Source Reference:** `services/photoprism/kubernetes/03-mariadb.yaml`

**Required Changes:**
1. Convert to StatefulSet for stable storage
2. Add family labels
3. Create per-family database: `photoprism_FAMILY_NAME`
4. Template all resource names

**Key Sections:**
```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: mariadb-credentials
  namespace: photoprism-FAMILY_NAME
  labels:
    family: FAMILY_NAME
type: Opaque
stringData:
  root-password: "PLACEHOLDER"
  database: "photoprism_FAMILY_NAME"
  username: "photoprism_FAMILY_NAME"
  password: "PLACEHOLDER"

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: mariadb-config
  namespace: photoprism-FAMILY_NAME
  labels:
    family: FAMILY_NAME
data:
  custom.cnf: |
    [mysqld]
    innodb_buffer_pool_size = 2G
    max_connections = 200
    character-set-server = utf8mb4
    collation-server = utf8mb4_unicode_ci

---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mariadb
  namespace: photoprism-FAMILY_NAME
  labels:
    app: mariadb
    family: FAMILY_NAME
spec:
  serviceName: mariadb
  replicas: 1
  selector:
    matchLabels:
      app: mariadb
      family: FAMILY_NAME
  template:
    metadata:
      labels:
        app: mariadb
        family: FAMILY_NAME
    spec:
      containers:
      - name: mariadb
        image: mariadb:10.11
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mariadb-credentials
              key: root-password
        - name: MYSQL_DATABASE
          valueFrom:
            secretKeyRef:
              name: mariadb-credentials
              key: database
        - name: MYSQL_USER
          valueFrom:
            secretKeyRef:
              name: mariadb-credentials
              key: username
        - name: MYSQL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mariadb-credentials
              key: password
        ports:
        - containerPort: 3306
          name: mysql
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
        - name: config
          mountPath: /etc/mysql/conf.d
        resources:
          requests:
            memory: "2Gi"
            cpu: "500m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: mariadb-data
      - name: config
        configMap:
          name: mariadb-config

---
apiVersion: v1
kind: Service
metadata:
  name: mariadb
  namespace: photoprism-FAMILY_NAME
  labels:
    app: mariadb
    family: FAMILY_NAME
spec:
  type: ClusterIP
  clusterIP: None  # Headless service for StatefulSet
  ports:
  - port: 3306
    targetPort: 3306
    name: mysql
  selector:
    app: mariadb
    family: FAMILY_NAME
```

---

#### Step 3: Create PhotoPrism Base Template

**File:** `services/photoprism/kustomize/base/photoprism.yaml`

**Source Reference:** `services/photoprism/kubernetes/04-photoprism.yaml`

**Critical Configuration:**
- S3 endpoint: `http://minio:9000` (within namespace)
- Database host: `mariadb:3306` (within namespace)
- Site URL: `https://photos.FAMILY_NAME.family`
- Admin user from onboarding

**Template Structure:**
```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: photoprism-config
  namespace: photoprism-FAMILY_NAME
  labels:
    family: FAMILY_NAME
data:
  PHOTOPRISM_SITE_URL: "https://photos.FAMILY_NAME.family"
  PHOTOPRISM_SITE_TITLE: "PREFERRED_NAME Photos"
  PHOTOPRISM_SITE_CAPTION: "AI-Powered Photo Management"
  PHOTOPRISM_ADMIN_USER: "ADMIN_EMAIL"
  PHOTOPRISM_DATABASE_DRIVER: "mysql"
  PHOTOPRISM_DATABASE_SERVER: "mariadb:3306"
  PHOTOPRISM_DATABASE_NAME: "photoprism_FAMILY_NAME"
  PHOTOPRISM_DATABASE_USER: "photoprism_FAMILY_NAME"
  # S3 Storage
  PHOTOPRISM_ORIGINALS_LIMIT: "1000"
  PHOTOPRISM_S3_ENDPOINT: "http://minio:9000"
  PHOTOPRISM_S3_BUCKET: "photoprism-FAMILY_NAME"
  # Features
  PHOTOPRISM_DISABLE_WEBDAV: "false"
  PHOTOPRISM_DISABLE_SETTINGS: "false"
  PHOTOPRISM_DISABLE_PLACES: "false"
  PHOTOPRISM_DISABLE_TENSORFLOW: "false"
  PHOTOPRISM_DETECT_NSFW: "false"
  PHOTOPRISM_UPLOAD_NSFW: "true"

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: photoprism
  namespace: photoprism-FAMILY_NAME
  labels:
    app: photoprism
    family: FAMILY_NAME
spec:
  replicas: 2
  selector:
    matchLabels:
      app: photoprism
      family: FAMILY_NAME
  template:
    metadata:
      labels:
        app: photoprism
        family: FAMILY_NAME
    spec:
      initContainers:
      # Wait for MariaDB
      - name: wait-mariadb
        image: busybox:1.35
        command:
        - sh
        - -c
        - |
          until nc -z mariadb 3306; do
            echo "Waiting for MariaDB..."
            sleep 2
          done
      # Wait for MinIO
      - name: wait-minio
        image: busybox:1.35
        command:
        - sh
        - -c
        - |
          until nc -z minio 9000; do
            echo "Waiting for MinIO..."
            sleep 2
          done
      containers:
      - name: photoprism
        image: photoprism/photoprism:latest
        envFrom:
        - configMapRef:
            name: photoprism-config
        env:
        - name: PHOTOPRISM_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: photoprism-credentials
              key: admin-password
        - name: PHOTOPRISM_DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mariadb-credentials
              key: password
        - name: PHOTOPRISM_S3_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: minio-credentials
              key: rootUser
        - name: PHOTOPRISM_S3_SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: minio-credentials
              key: rootPassword
        ports:
        - containerPort: 2342
          name: http
        volumeMounts:
        - name: cache
          mountPath: /photoprism/cache
        - name: import
          mountPath: /photoprism/import
        resources:
          requests:
            memory: "4Gi"
            cpu: "1000m"
          limits:
            memory: "16Gi"
            cpu: "4000m"
        # Optional: GPU support
        # resources:
        #   limits:
        #     nvidia.com/gpu: "1"
      volumes:
      - name: cache
        persistentVolumeClaim:
          claimName: photoprism-cache
      - name: import
        emptyDir: {}

---
apiVersion: v1
kind: Service
metadata:
  name: photoprism
  namespace: photoprism-FAMILY_NAME
  labels:
    app: photoprism
    family: FAMILY_NAME
spec:
  type: ClusterIP
  ports:
  - port: 2342
    targetPort: 2342
    name: http
  selector:
    app: photoprism
    family: FAMILY_NAME

---
apiVersion: v1
kind: Secret
metadata:
  name: photoprism-credentials
  namespace: photoprism-FAMILY_NAME
  labels:
    family: FAMILY_NAME
type: Opaque
stringData:
  admin-password: "PLACEHOLDER"
```

---

#### Step 4: Create Ingress Base Template

**File:** `services/photoprism/kustomize/base/ingress.yaml`

**Source Reference:** `services/photoprism/kubernetes/05-ingress.yaml`

**Required Changes:**
1. Template domain names: `photos.FAMILY_NAME.family`
2. Template TLS secret names
3. Add annotations for cert-manager and Authelia (optional)

**Template:**
```yaml
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: photoprism
  namespace: photoprism-FAMILY_NAME
  labels:
    app: photoprism
    family: FAMILY_NAME
  annotations:
    cert-manager.io/cluster-issuer: "vault-issuer"
    nginx.ingress.kubernetes.io/proxy-body-size: "10240m"
    nginx.ingress.kubernetes.io/proxy-request-buffering: "off"
    # Optional: Authelia SSO
    # nginx.ingress.kubernetes.io/auth-url: "https://auth.FAMILY_NAME.family/api/verify"
    # nginx.ingress.kubernetes.io/auth-signin: "https://auth.FAMILY_NAME.family"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - photos.FAMILY_NAME.family
    secretName: photoprism-tls
  - hosts:
    - minio.photos.FAMILY_NAME.family
    secretName: minio-tls
  rules:
  # PhotoPrism UI
  - host: photos.FAMILY_NAME.family
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: photoprism
            port:
              number: 2342
  # MinIO Console
  - host: minio.photos.FAMILY_NAME.family
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: minio
            port:
              number: 9001
```

---

#### Step 5: Update Base Kustomization

**File:** `services/photoprism/kustomize/base/kustomization.yaml`

**Add new resources:**
```yaml
resources:
  - namespace.yaml
  - storage.yaml
  - minio.yaml          # NEW
  - mariadb.yaml        # NEW
  - photoprism.yaml     # NEW
  - ingress.yaml        # NEW
  - monitoring.yaml
```

---

#### Step 6: Testing

**Validate templates:**
```bash
# Build for example family
cd services/photoprism
kustomize build kustomize/overlays/example-smith > /tmp/smith-manifest.yaml

# Check for FAMILY_NAME placeholders (should be replaced)
grep "FAMILY_NAME" /tmp/smith-manifest.yaml

# Verify namespace isolation
grep "namespace: photoprism-smith" /tmp/smith-manifest.yaml | wc -l
# Should be ~20+ lines (one per resource)

# Validate YAML syntax
kubectl apply --dry-run=client -f /tmp/smith-manifest.yaml
```

**Create test overlay:**
```bash
# Create test family
mkdir -p kustomize/overlays/test-garcia

cat > kustomize/overlays/test-garcia/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: photoprism-garcia

resources:
  - ../../base

configMapGenerator:
  - name: photoprism-config
    behavior: merge
    literals:
      - FAMILY_NAME=garcia
      - PREFERRED_NAME=Garcia Family
      - PHOTOPRISM_SITE_URL=https://photos.garcia.family

commonLabels:
  family: garcia
EOF

# Build and validate
kustomize build kustomize/overlays/test-garcia | kubectl apply --dry-run=client -f -
```

---

### Acceptance Criteria

- ✅ All 4 new base templates created (MinIO, MariaDB, PhotoPrism, Ingress)
- ✅ No hardcoded family names in base templates
- ✅ All resources use `family: FAMILY_NAME` label
- ✅ Services reference each other within namespace (e.g., `mariadb:3306`, not external)
- ✅ `kustomize build` succeeds for overlays
- ✅ `kubectl apply --dry-run` validates successfully
- ✅ Can build manifests for multiple families without conflicts

---

## Task 2: Implement Domain Registrar APIs

### Current State

**What Exists:**
- ✅ Domain module scaffolding: `cluster/ai-ops-agent/ai_ops_agent/domain/__init__.py`
- ✅ `DomainManager` class with method signatures
- ✅ `DomainRegistrar` enum (Cloudflare, Namecheap, GoDaddy, Route53)
- ✅ Placeholder implementations for API calls

**What's Missing:**
- ❌ Actual API client implementations
- ❌ API credential management (from environment/Vault)
- ❌ Error handling for rate limits, timeouts
- ❌ Domain verification after registration
- ❌ DNS propagation checking

### Why This Matters

Currently, the onboarding flow can check if a domain *might* be available and suggest alternatives, but it **cannot actually register domains**. This is a critical gap for production deployment.

### What You Need to Do

#### Step 1: Choose Primary Registrar

**Recommendation:** Start with **Cloudflare** - they have:
- ✅ Best API documentation
- ✅ At-cost domain pricing (no markup)
- ✅ Free DNS management
- ✅ Python SDK available (`cloudflare`)
- ✅ API tokens (no username/password)

**Alternative:** Namecheap has good API but XML-based (more complex)

---

#### Step 2: Install Dependencies

**File:** `cluster/ai-ops-agent/requirements.txt`

**Add:**
```python
# Domain Registration
cloudflare==2.11.7  # Cloudflare API client
dnspython==2.4.2    # DNS propagation checking

# Optional: Other registrars
# namecheap-sdk==0.0.3  # Namecheap (if needed)
# godaddypy==2.4.7      # GoDaddy (if needed)
```

**Install:**
```bash
cd cluster/ai-ops-agent
pip install -r requirements.txt
```

---

#### Step 3: Configure API Credentials

**Environment Variables:**

Create `.env` file (or use Vault):
```bash
# Cloudflare
CLOUDFLARE_API_TOKEN=your_cloudflare_api_token
CLOUDFLARE_ACCOUNT_ID=your_account_id

# Namecheap (optional)
NAMECHEAP_API_USER=your_username
NAMECHEAP_API_KEY=your_api_key
NAMECHEAP_USERNAME=your_username
NAMECHEAP_CLIENT_IP=your_whitelisted_ip

# GoDaddy (optional)
GODADDY_API_KEY=your_api_key
GODADDY_API_SECRET=your_api_secret
```

**Load in Python:**
```python
import os
from pathlib import Path
from dotenv import load_dotenv

# Load environment variables
env_path = Path('.env')
if env_path.exists():
    load_dotenv(env_path)

# Or use Vault (production)
# vault_client = hvac.Client(url='http://vault:8200')
# secrets = vault_client.secrets.kv.v2.read_secret_version(path='domain-registrars')
```

---

#### Step 4: Implement Cloudflare Domain Registration

**File:** `cluster/ai-ops-agent/ai_ops_agent/domain/__init__.py`

**Update `_check_cloudflare()` method:**

```python
import CloudFlare
from typing import Optional, Dict, List

class DomainManager:
    def __init__(self):
        # Initialize Cloudflare client
        api_token = os.getenv("CLOUDFLARE_API_TOKEN")
        if api_token:
            self.cf = CloudFlare.CloudFlare(token=api_token)
            self.cf_account_id = os.getenv("CLOUDFLARE_ACCOUNT_ID")
        else:
            self.cf = None
            logger.warning("Cloudflare API token not configured")

    async def _check_cloudflare(self, domain: str) -> bool:
        """
        Check domain availability via Cloudflare Registrar API

        Docs: https://developers.cloudflare.com/api/operations/registrar-domains-check-availability
        """
        if not self.cf:
            logger.error("Cloudflare client not initialized")
            return False

        try:
            # Check domain availability
            result = self.cf.accounts.registrar.domains.check(
                self.cf_account_id,
                data={'domain': domain}
            )

            # Cloudflare returns: {"available": true/false}
            available = result.get('available', False)

            logger.info(f"Cloudflare domain check: {domain} = {available}")
            return available

        except CloudFlare.exceptions.CloudFlareAPIError as e:
            logger.error(f"Cloudflare API error checking {domain}: {e}")
            # If domain already owned by this account, it's not available
            if e.code == 1004:  # Domain not available
                return False
            raise
        except Exception as e:
            logger.error(f"Error checking Cloudflare domain {domain}: {e}")
            return False
```

**Implement `_register_cloudflare()` method:**

```python
async def _register_cloudflare(
    self,
    domain: str,
    contact_info: Dict,
    dns_records: Optional[List[Dict]] = None
) -> Tuple[bool, Optional[str]]:
    """
    Register domain via Cloudflare Registrar

    Args:
        domain: Domain to register (e.g., "smith.family")
        contact_info: Registrant contact information
        dns_records: Optional DNS records to create

    Returns:
        (success, error_message)
    """
    if not self.cf:
        return False, "Cloudflare client not initialized"

    try:
        # Validate contact info
        required_fields = ['first_name', 'last_name', 'email',
                          'phone', 'address1', 'city',
                          'state', 'zip', 'country']

        for field in required_fields:
            if field not in contact_info:
                return False, f"Missing required field: {field}"

        # Prepare registration data
        registration_data = {
            'domain': domain,
            'years': 1,  # Register for 1 year
            'privacy': True,  # Enable WHOIS privacy
            'auto_renew': True,  # Auto-renew domain
            'registrant': {
                'first_name': contact_info['first_name'],
                'last_name': contact_info['last_name'],
                'organization': contact_info.get('organization', ''),
                'email': contact_info['email'],
                'phone': contact_info['phone'],
                'address1': contact_info['address1'],
                'address2': contact_info.get('address2', ''),
                'city': contact_info['city'],
                'state': contact_info['state'],
                'zip': contact_info['zip'],
                'country': contact_info['country']
            }
        }

        # Register domain
        logger.info(f"Registering domain {domain} with Cloudflare...")
        result = self.cf.accounts.registrar.domains.post(
            self.cf_account_id,
            data=registration_data
        )

        domain_id = result.get('id')
        if not domain_id:
            return False, "Domain registration failed - no ID returned"

        logger.info(f"Domain {domain} registered successfully. ID: {domain_id}")

        # Configure DNS records if provided
        if dns_records:
            success, error = await self._configure_cloudflare_dns(
                domain,
                dns_records
            )
            if not success:
                logger.warning(f"DNS configuration failed: {error}")
                # Don't fail registration if DNS setup fails

        return True, None

    except CloudFlare.exceptions.CloudFlareAPIError as e:
        error_msg = f"Cloudflare API error: {e}"
        logger.error(error_msg)
        return False, error_msg

    except Exception as e:
        error_msg = f"Unexpected error registering domain: {e}"
        logger.error(error_msg)
        return False, error_msg
```

**Implement DNS configuration:**

```python
async def _configure_cloudflare_dns(
    self,
    domain: str,
    dns_records: List[Dict]
) -> Tuple[bool, Optional[str]]:
    """
    Configure DNS records for domain in Cloudflare

    Args:
        domain: Domain name
        dns_records: List of DNS records to create
            [{"type": "A", "name": "photos.smith.family", "value": "1.2.3.4"}]

    Returns:
        (success, error_message)
    """
    try:
        # Get zone ID for domain
        zones = self.cf.zones.get(params={'name': domain})
        if not zones:
            return False, f"Zone not found for {domain}"

        zone_id = zones[0]['id']

        # Create DNS records
        for record in dns_records:
            try:
                dns_data = {
                    'type': record['type'],
                    'name': record['name'],
                    'content': record['value'],
                    'ttl': record.get('ttl', 300),
                    'proxied': record.get('proxied', False)
                }

                self.cf.zones.dns_records.post(zone_id, data=dns_data)
                logger.info(f"Created DNS record: {record['name']} -> {record['value']}")

            except CloudFlare.exceptions.CloudFlareAPIError as e:
                # Record might already exist
                if e.code == 81057:  # Record already exists
                    logger.warning(f"DNS record already exists: {record['name']}")
                    continue
                raise

        return True, None

    except Exception as e:
        error_msg = f"Error configuring DNS: {e}"
        logger.error(error_msg)
        return False, error_msg
```

---

#### Step 5: Add DNS Propagation Checking

**Helper function to verify DNS is working:**

```python
import dns.resolver
import asyncio

async def check_dns_propagation(
    self,
    domain: str,
    expected_ip: str,
    max_attempts: int = 30,
    delay_seconds: int = 10
) -> bool:
    """
    Check if DNS A record has propagated

    Args:
        domain: Domain to check
        expected_ip: Expected IP address
        max_attempts: Maximum number of checks
        delay_seconds: Delay between checks

    Returns:
        True if DNS has propagated, False otherwise
    """
    logger.info(f"Checking DNS propagation for {domain} -> {expected_ip}")

    for attempt in range(max_attempts):
        try:
            # Query DNS
            answers = dns.resolver.resolve(domain, 'A')

            for rdata in answers:
                if str(rdata) == expected_ip:
                    logger.info(f"DNS propagated for {domain}! ({attempt + 1}/{max_attempts})")
                    return True

            logger.debug(f"DNS not yet propagated for {domain}. Attempt {attempt + 1}/{max_attempts}")

        except dns.resolver.NXDOMAIN:
            logger.debug(f"Domain {domain} not found. Attempt {attempt + 1}/{max_attempts}")
        except dns.resolver.NoAnswer:
            logger.debug(f"No A record for {domain}. Attempt {attempt + 1}/{max_attempts}")
        except Exception as e:
            logger.warning(f"DNS query error for {domain}: {e}")

        # Wait before retry
        if attempt < max_attempts - 1:
            await asyncio.sleep(delay_seconds)

    logger.error(f"DNS propagation timeout for {domain} after {max_attempts} attempts")
    return False
```

---

#### Step 6: Update Onboarding Flow Integration

**File:** `cluster/ai-ops-agent/ai_ops_agent/onboarding/__init__.py`

**Update `_handle_register_domain()` method:**

```python
async def _handle_register_domain(self, state: OnboardingState) -> str:
    """
    Register domain and configure DNS
    """
    domain = state.domain

    # Prepare contact info from state
    contact_info = {
        'first_name': state.preferred_name.split()[0],
        'last_name': state.preferred_name.split()[-1] if len(state.preferred_name.split()) > 1 else 'Family',
        'email': state.contact_email,
        'phone': '+1.5555551234',  # TODO: Collect phone during onboarding
        'address1': '123 Main St',  # TODO: Collect address during onboarding
        'city': 'San Francisco',
        'state': 'CA',
        'zip': '94105',
        'country': 'US'
    }

    # Register domain
    success, error = await self.domain_manager.register_domain(
        domain=domain,
        contact_info=contact_info,
        registrar=DomainRegistrar.CLOUDFLARE
    )

    if not success:
        return f"❌ Domain registration failed: {error}\n\nPlease contact support."

    logger.info(f"Domain {domain} registered successfully")

    # Get ingress IP (from environment or K8s)
    ingress_ip = os.getenv("INGRESS_IP", "1.2.3.4")  # TODO: Get from K8s

    # Configure DNS
    success, error = await self.domain_manager.configure_dns(domain, ingress_ip)

    if not success:
        logger.error(f"DNS configuration failed: {error}")
        return f"⚠️ Domain registered but DNS setup failed.\n\nManually add these A records:\n- photos.{domain} -> {ingress_ip}"

    # Check DNS propagation (async, don't block)
    # In production, this would be a background task

    return f"✅ Domain {domain} registered and DNS configured!\n\nProceeding with deployment..."
```

---

#### Step 7: Testing

**Unit tests:**

```python
# File: cluster/ai-ops-agent/tests/test_domain_manager.py

import pytest
from ai_ops_agent.domain import DomainManager, DomainRegistrar

@pytest.mark.asyncio
async def test_check_availability_cloudflare():
    """Test Cloudflare domain availability check"""
    manager = DomainManager()

    # Test with a domain that should be taken
    available = await manager.check_availability("google.family", "family")
    assert available is False

    # Test with a random domain (likely available)
    import uuid
    random_domain = f"test-{uuid.uuid4().hex[:8]}.family"
    available = await manager.check_availability(random_domain, "family")
    # Can't assert True because it might actually be taken

@pytest.mark.asyncio
async def test_register_domain_mock():
    """Test domain registration with mock data"""
    manager = DomainManager()

    contact_info = {
        'first_name': 'Test',
        'last_name': 'User',
        'email': 'test@example.com',
        'phone': '+1.5555551234',
        'address1': '123 Test St',
        'city': 'Test City',
        'state': 'CA',
        'zip': '12345',
        'country': 'US'
    }

    # This will fail in test without real API key
    # In production, use VCR.py to record/replay HTTP requests
```

**Manual testing:**

```bash
# Test domain check
curl -X POST http://localhost:8000/api/v1/photoprism/onboard \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test", "user_email": "test@example.com"}'

# Get session ID, then test domain input
SESSION_ID="<session-id>"
curl -X POST "http://localhost:8000/api/v1/photoprism/onboard/$SESSION_ID/respond" \
  -H "Content-Type: application/json" \
  -d '{"user_input": "TestFamily"}'

# Should check Cloudflare API for testfamily.family availability
```

---

### Acceptance Criteria

- ✅ Cloudflare API client configured with credentials
- ✅ `check_availability()` returns real data from Cloudflare
- ✅ `register_domain()` successfully registers domains
- ✅ DNS A records created automatically
- ✅ DNS propagation verification works
- ✅ Error handling for API failures (rate limits, timeouts)
- ✅ Contact information validation
- ✅ Integration with onboarding flow tested

---

## Task 3: Add Prometheus Metrics Integration

### Current State

**What Exists:**
- ✅ Storage monitoring endpoint: `/api/v1/photoprism/storage`
- ✅ PrometheusRule definitions in `kustomize/base/monitoring.yaml`
- ✅ Mock storage data returned from endpoint

**What's Missing:**
- ❌ Actual Prometheus client connection
- ❌ Real PromQL queries for storage metrics
- ❌ Kubernetes volume metrics collection
- ❌ Alert manager integration for notifications

### Why This Matters

The AI Ops bot needs real storage metrics to proactively alert families at 80% capacity. Currently, it returns fake data.

### What You Need to Do

#### Step 1: Install Prometheus Client

**File:** `cluster/ai-ops-agent/requirements.txt`

```python
# Prometheus Integration
prometheus-client==0.19.0
prometheus-api-client==0.5.3
```

#### Step 2: Configure Prometheus Connection

**Environment variables:**

```bash
PROMETHEUS_URL=http://prometheus-server:9090  # Or external URL
```

**Initialize client in `main.py`:**

```python
from prometheus_api_client import PrometheusConnect

# Configuration
PROMETHEUS_URL = os.getenv("PROMETHEUS_URL", "http://prometheus-server:9090")

# Initialize Prometheus client
try:
    prom = PrometheusConnect(url=PROMETHEUS_URL, disable_ssl=True)
    logger.info(f"Prometheus connected: {PROMETHEUS_URL}")
except Exception as e:
    logger.error(f"Failed to connect to Prometheus: {e}")
    prom = None
```

---

#### Step 3: Implement Real Storage Queries

**File:** `cluster/ai-ops-agent/main.py`

**Update `check_photoprism_storage()` endpoint:**

```python
@app.get("/api/v1/photoprism/storage")
async def check_photoprism_storage(family_name: str):
    """Check PhotoPrism storage status for a family"""

    logger.info(f"Checking PhotoPrism storage for family: {family_name}")

    if not prom:
        raise HTTPException(
            status_code=503,
            detail="Prometheus metrics unavailable"
        )

    try:
        namespace = f"photoprism-{family_name}"

        # Query 1: MinIO photos storage
        photos_used_query = f'''
            sum(kubelet_volume_stats_used_bytes{{
                namespace="{namespace}",
                persistentvolumeclaim="minio-photos"
            }})
        '''

        photos_capacity_query = f'''
            sum(kubelet_volume_stats_capacity_bytes{{
                namespace="{namespace}",
                persistentvolumeclaim="minio-photos"
            }})
        '''

        photos_used_result = prom.custom_query(query=photos_used_query)
        photos_capacity_result = prom.custom_query(query=photos_capacity_query)

        # Extract values
        photos_used = float(photos_used_result[0]['value'][1]) if photos_used_result else 0
        photos_capacity = float(photos_capacity_result[0]['value'][1]) if photos_capacity_result else 0
        photos_percent = (photos_used / photos_capacity * 100) if photos_capacity > 0 else 0

        # Query 2: MariaDB database storage
        db_used_query = f'''
            sum(kubelet_volume_stats_used_bytes{{
                namespace="{namespace}",
                persistentvolumeclaim="mariadb-data"
            }})
        '''

        db_capacity_query = f'''
            sum(kubelet_volume_stats_capacity_bytes{{
                namespace="{namespace}",
                persistentvolumeclaim="mariadb-data"
            }})
        '''

        db_used_result = prom.custom_query(query=db_used_query)
        db_capacity_result = prom.custom_query(query=db_capacity_query)

        db_used = float(db_used_result[0]['value'][1]) if db_used_result else 0
        db_capacity = float(db_capacity_result[0]['value'][1]) if db_capacity_result else 0
        db_percent = (db_used / db_capacity * 100) if db_capacity > 0 else 0

        # Query 3: Cache storage
        cache_used_query = f'''
            sum(kubelet_volume_stats_used_bytes{{
                namespace="{namespace}",
                persistentvolumeclaim="photoprism-cache"
            }})
        '''

        cache_capacity_query = f'''
            sum(kubelet_volume_stats_capacity_bytes{{
                namespace="{namespace}",
                persistentvolumeclaim="photoprism-cache"
            }})
        '''

        cache_used_result = prom.custom_query(query=cache_used_query)
        cache_capacity_result = prom.custom_query(query=cache_capacity_query)

        cache_used = float(cache_used_result[0]['value'][1]) if cache_used_result else 0
        cache_capacity = float(cache_capacity_result[0]['value'][1]) if cache_capacity_result else 0
        cache_percent = (cache_used / cache_capacity * 100) if cache_capacity > 0 else 0

        # Build response
        storage_info = {
            "family_name": family_name,
            "namespace": namespace,
            "storage": {
                "photos": {
                    "used_bytes": int(photos_used),
                    "capacity_bytes": int(photos_capacity),
                    "usage_percent": round(photos_percent, 2),
                    "pvc_name": "minio-photos"
                },
                "database": {
                    "used_bytes": int(db_used),
                    "capacity_bytes": int(db_capacity),
                    "usage_percent": round(db_percent, 2),
                    "pvc_name": "mariadb-data"
                },
                "cache": {
                    "used_bytes": int(cache_used),
                    "capacity_bytes": int(cache_capacity),
                    "usage_percent": round(cache_percent, 2),
                    "pvc_name": "photoprism-cache"
                }
            },
            "alerts": {
                "active": False,
                "warnings": [],
                "critical": []
            },
            "recommendations": []
        }

        # Check for alerts
        if photos_percent > 80:
            storage_info["alerts"]["active"] = True
            severity = "critical" if photos_percent > 95 else "warning"
            storage_info["alerts"]["warnings" if severity == "warning" else "critical"].append({
                "severity": severity,
                "message": f"Photo storage at {photos_percent:.1f}%",
                "recommendation": "Delete old photos or request storage expansion"
            })

        # Generate recommendations
        if photos_percent < 60:
            storage_info["recommendations"].append("Storage is healthy")
        elif photos_percent < 80:
            storage_info["recommendations"].append("Consider archiving photos when usage reaches 80%")
        else:
            storage_info["recommendations"].append("Action recommended: Delete photos or expand storage")

        return storage_info

    except Exception as e:
        logger.error(f"Error checking storage: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Failed to check storage: {str(e)}"
        )
```

---

#### Step 4: Add Service Health Checks

**Add endpoint to check if PhotoPrism is running:**

```python
@app.get("/api/v1/photoprism/health/{family_name}")
async def check_photoprism_health(family_name: str):
    """Check if PhotoPrism service is healthy for a family"""

    if not prom:
        raise HTTPException(status_code=503, detail="Prometheus unavailable")

    try:
        namespace = f"photoprism-{family_name}"

        # Query service uptime
        uptime_query = f'''
            up{{
                job="photoprism",
                namespace="{namespace}"
            }}
        '''

        result = prom.custom_query(query=uptime_query)

        if not result:
            return {
                "status": "unknown",
                "message": "No metrics available"
            }

        is_up = int(result[0]['value'][1]) == 1

        # Query pod status
        pod_ready_query = f'''
            kube_pod_status_ready{{
                namespace="{namespace}",
                pod=~"photoprism-.*",
                condition="true"
            }}
        '''

        pod_result = prom.custom_query(query=pod_ready_query)
        ready_pods = len(pod_result)

        return {
            "status": "healthy" if is_up and ready_pods > 0 else "unhealthy",
            "service_up": is_up,
            "ready_pods": ready_pods,
            "namespace": namespace
        }

    except Exception as e:
        logger.error(f"Error checking health: {e}")
        raise HTTPException(status_code=500, detail=str(e))
```

---

#### Step 5: Add Alert Webhook Handler

**Receive alerts from Prometheus Alertmanager:**

```python
from pydantic import BaseModel
from typing import List

class PrometheusAlert(BaseModel):
    """Prometheus alert webhook payload"""
    status: str  # "firing" or "resolved"
    labels: Dict
    annotations: Dict
    startsAt: str
    endsAt: Optional[str] = None

class AlertWebhook(BaseModel):
    """Alertmanager webhook payload"""
    version: str
    groupKey: str
    status: str
    alerts: List[PrometheusAlert]

@app.post("/api/v1/alerts/webhook")
async def handle_prometheus_alerts(webhook: AlertWebhook, background_tasks: BackgroundTasks):
    """
    Handle alerts from Prometheus Alertmanager

    This endpoint receives alerts and triggers AI Ops bot notifications
    to families about storage issues.
    """

    logger.info(f"Received {len(webhook.alerts)} alerts from Prometheus")

    try:
        for alert in webhook.alerts:
            # Only process firing alerts
            if alert.status != "firing":
                continue

            # Extract family information
            family_name = alert.labels.get("family")
            if not family_name:
                logger.warning("Alert missing family label")
                continue

            alert_name = alert.labels.get("alertname")
            severity = alert.labels.get("severity", "warning")

            # Get AI Ops message from annotations
            ai_ops_message = alert.annotations.get("ai_ops_message")
            if not ai_ops_message:
                logger.warning(f"Alert {alert_name} missing ai_ops_message annotation")
                continue

            # Schedule background task to notify family
            background_tasks.add_task(
                notify_family_about_alert,
                family_name=family_name,
                alert_name=alert_name,
                severity=severity,
                message=ai_ops_message
            )

            logger.info(f"Scheduled notification for family {family_name}: {alert_name}")

        return {"status": "ok", "processed": len(webhook.alerts)}

    except Exception as e:
        logger.error(f"Error processing alerts: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


async def notify_family_about_alert(
    family_name: str,
    alert_name: str,
    severity: str,
    message: str
):
    """
    Send notification to family about alert

    In production, this would:
    1. Look up family contact info (email, SMS)
    2. Send notification via preferred channel
    3. Log notification in ML system
    """

    logger.info(f"Notifying family {family_name} about {alert_name} ({severity})")

    # TODO: Implement actual notification
    # - Email via SendGrid/SES
    # - SMS via Twilio
    # - Push notification via Firebase
    # - In-app notification

    # For now, just log
    logger.info(f"NOTIFICATION TO {family_name}:\n{message}")
```

---

#### Step 6: Configure Alertmanager

**File:** `services/photoprism/monitoring/alertmanager-config.yaml` (NEW)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: monitoring
data:
  alertmanager.yml: |
    global:
      resolve_timeout: 5m

    route:
      group_by: ['family', 'alertname']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 12h
      receiver: 'ai-ops-webhook'

      routes:
      # Family-facing alerts (notify via AI Ops bot)
      - match:
          family_facing: "true"
        receiver: 'ai-ops-webhook'
        continue: false

      # Internal alerts (notify ops team)
      - match:
          family_facing: "false"
        receiver: 'ops-team'
        continue: false

    receivers:
    - name: 'ai-ops-webhook'
      webhook_configs:
      - url: 'http://ai-ops-agent:8000/api/v1/alerts/webhook'
        send_resolved: true

    - name: 'ops-team'
      email_configs:
      - to: 'ops@suhlabs.io'
        from: 'alerts@suhlabs.io'
        smarthost: 'smtp.gmail.com:587'
        auth_username: 'alerts@suhlabs.io'
        auth_password: '<vault-secret>'
```

---

#### Step 7: Testing

**Test Prometheus queries:**

```bash
# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus-server 9090:9090

# Test query in browser
http://localhost:9090/graph

# Query:
sum(kubelet_volume_stats_used_bytes{namespace="photoprism-smith",persistentvolumeclaim="minio-photos"})
```

**Test storage endpoint:**

```bash
# With real Prometheus
curl "http://localhost:8000/api/v1/photoprism/storage?family_name=smith"

# Should return real metrics, not mock data
```

**Test alert webhook:**

```bash
# Send test alert
curl -X POST http://localhost:8000/api/v1/alerts/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "version": "4",
    "groupKey": "test",
    "status": "firing",
    "alerts": [{
      "status": "firing",
      "labels": {
        "alertname": "PhotoPrismStorageHigh",
        "family": "smith",
        "severity": "warning",
        "family_facing": "true"
      },
      "annotations": {
        "ai_ops_message": "Hi Smith Family! Your storage is at 85%."
      },
      "startsAt": "2025-11-18T10:00:00Z"
    }]
  }'
```

---

### Acceptance Criteria

- ✅ Prometheus client connected to cluster
- ✅ Real storage metrics queried from kubelet
- ✅ Storage endpoint returns actual usage data
- ✅ Health check endpoint works
- ✅ Alert webhook receives alerts from Alertmanager
- ✅ Family notifications triggered for `family_facing=true` alerts
- ✅ No more mock data in responses

---

## Task 4: Create End-to-End Test Script

### Current State

**What Exists:**
- ✅ All components implemented (API, onboarding, domain, storage)
- ✅ Individual module testing possible

**What's Missing:**
- ❌ Automated end-to-end test suite
- ❌ Test data cleanup automation
- ❌ CI/CD integration
- ❌ Performance/load testing

### Why This Matters

E2E tests ensure the entire onboarding flow works from start to finish without manual intervention. Critical for CI/CD and preventing regressions.

### What You Need to Do

#### Step 1: Create Test Framework

**File:** `services/photoprism/tests/test_e2e_onboarding.sh`

```bash
#!/bin/bash
# End-to-End PhotoPrism Onboarding Test
# Tests full flow: API → Domain check → Deployment → Verification

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
API_URL="${API_URL:-http://localhost:8000}"
TEST_FAMILY="test-$(date +%s)"
TEST_EMAIL="test@example.com"
CLEANUP="${CLEANUP:-true}"

# Test state
SESSION_ID=""
DEPLOYMENT_COMMAND=""

echo "========================================="
echo "PhotoPrism E2E Onboarding Test"
echo "========================================="
echo "API URL: $API_URL"
echo "Test Family: $TEST_FAMILY"
echo "Cleanup: $CLEANUP"
echo ""

# Helper functions
log_info() {
    echo -e "${GREEN}✓${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}!${NC} $1"
}

cleanup_test_resources() {
    if [ "$CLEANUP" = "true" ]; then
        log_info "Cleaning up test resources..."

        # Delete Kubernetes namespace
        kubectl delete namespace "photoprism-$TEST_FAMILY" --ignore-not-found=true

        # Delete Kustomize overlay
        rm -rf "services/photoprism/kustomize/overlays/$TEST_FAMILY"

        log_info "Cleanup complete"
    else
        log_warn "Skipping cleanup (CLEANUP=false)"
    fi
}

# Trap errors and cleanup
trap cleanup_test_resources EXIT

# Test 1: Start onboarding
test_start_onboarding() {
    echo "Test 1: Start onboarding..."

    RESPONSE=$(curl -s -X POST "$API_URL/api/v1/photoprism/onboard" \
        -H "Content-Type: application/json" \
        -d "{
            \"user_id\": \"test-user\",
            \"user_email\": \"$TEST_EMAIL\"
        }")

    SESSION_ID=$(echo "$RESPONSE" | jq -r '.session_id')
    STEP=$(echo "$RESPONSE" | jq -r '.step')
    MESSAGE=$(echo "$RESPONSE" | jq -r '.message')

    if [ "$STEP" = "WELCOME" ] && [ "$SESSION_ID" != "null" ]; then
        log_info "Onboarding started successfully"
        log_info "Session ID: $SESSION_ID"
    else
        log_error "Failed to start onboarding"
        echo "$RESPONSE" | jq .
        exit 1
    fi
}

# Test 2: Provide family name
test_provide_family_name() {
    echo ""
    echo "Test 2: Provide family name..."

    RESPONSE=$(curl -s -X POST "$API_URL/api/v1/photoprism/onboard/$SESSION_ID/respond" \
        -H "Content-Type: application/json" \
        -d "{
            \"user_input\": \"$TEST_FAMILY\"
        }")

    STEP=$(echo "$RESPONSE" | jq -r '.step')
    MESSAGE=$(echo "$RESPONSE" | jq -r '.message')

    if [[ "$STEP" =~ "CHECK_DOMAIN" ]] || [[ "$STEP" =~ "CONFIRM_DOMAIN" ]]; then
        log_info "Family name accepted: $TEST_FAMILY"
        log_info "Current step: $STEP"
    else
        log_error "Failed to process family name"
        echo "$RESPONSE" | jq .
        exit 1
    fi
}

# Test 3: Confirm domain
test_confirm_domain() {
    echo ""
    echo "Test 3: Confirm domain..."

    RESPONSE=$(curl -s -X POST "$API_URL/api/v1/photoprism/onboard/$SESSION_ID/respond" \
        -H "Content-Type: application/json" \
        -d "{
            \"user_input\": \"yes\"
        }")

    STEP=$(echo "$RESPONSE" | jq -r '.step')

    if [[ "$STEP" =~ "COLLECT_CONTACT" ]] || [[ "$STEP" =~ "DEPLOYMENT" ]]; then
        log_info "Domain confirmed"
    else
        log_error "Failed to confirm domain"
        echo "$RESPONSE" | jq .
        exit 1
    fi
}

# Test 4: Provide contact email
test_provide_email() {
    echo ""
    echo "Test 4: Provide contact email..."

    RESPONSE=$(curl -s -X POST "$API_URL/api/v1/photoprism/onboard/$SESSION_ID/respond" \
        -H "Content-Type: application/json" \
        -d "{
            \"user_input\": \"$TEST_EMAIL\"
        }")

    STEP=$(echo "$RESPONSE" | jq -r '.step')
    DEPLOYMENT_INFO=$(echo "$RESPONSE" | jq -r '.deployment_info')

    if [ "$DEPLOYMENT_INFO" != "null" ]; then
        DEPLOYMENT_COMMAND=$(echo "$DEPLOYMENT_INFO" | jq -r '.command')
        log_info "Email accepted, deployment ready"
        log_info "Deployment command: $DEPLOYMENT_COMMAND"
    else
        log_error "No deployment info received"
        echo "$RESPONSE" | jq .
        exit 1
    fi
}

# Test 5: Execute deployment
test_execute_deployment() {
    echo ""
    echo "Test 5: Execute deployment..."

    # Export environment variables for deploy-family.sh
    export FAMILY_NAME="$TEST_FAMILY"
    export PREFERRED_NAME="Test Family $TEST_FAMILY"
    export CONTACT_EMAIL="$TEST_EMAIL"
    export ENABLE_GPU="false"
    export ENABLE_AUTHELIA="false"

    # Run deployment script
    cd services/photoprism
    if ./deploy-family.sh 2>&1 | tee /tmp/deployment-$TEST_FAMILY.log; then
        log_info "Deployment completed successfully"
    else
        log_error "Deployment failed"
        cat /tmp/deployment-$TEST_FAMILY.log
        exit 1
    fi
    cd -
}

# Test 6: Verify pods are running
test_verify_pods() {
    echo ""
    echo "Test 6: Verify pods are running..."

    # Wait for pods to be ready (max 5 minutes)
    timeout=300
    elapsed=0

    while [ $elapsed -lt $timeout ]; do
        READY_PODS=$(kubectl get pods -n "photoprism-$TEST_FAMILY" \
            --field-selector=status.phase=Running \
            --no-headers 2>/dev/null | wc -l)

        if [ "$READY_PODS" -ge 3 ]; then
            log_info "All pods are running ($READY_PODS/3)"
            kubectl get pods -n "photoprism-$TEST_FAMILY"
            return 0
        fi

        sleep 10
        elapsed=$((elapsed + 10))
        echo "Waiting for pods... ($elapsed/$timeout seconds)"
    done

    log_error "Pods not ready after $timeout seconds"
    kubectl get pods -n "photoprism-$TEST_FAMILY"
    exit 1
}

# Test 7: Check storage metrics
test_check_storage() {
    echo ""
    echo "Test 7: Check storage metrics..."

    RESPONSE=$(curl -s "$API_URL/api/v1/photoprism/storage?family_name=$TEST_FAMILY")

    NAMESPACE=$(echo "$RESPONSE" | jq -r '.namespace')
    USAGE=$(echo "$RESPONSE" | jq -r '.storage.photos.usage_percent')

    if [ "$NAMESPACE" = "photoprism-$TEST_FAMILY" ]; then
        log_info "Storage metrics available"
        log_info "Photo storage usage: $USAGE%"
    else
        log_error "Storage metrics not available"
        echo "$RESPONSE" | jq .
        exit 1
    fi
}

# Test 8: Verify ingress
test_verify_ingress() {
    echo ""
    echo "Test 8: Verify ingress..."

    INGRESS=$(kubectl get ingress -n "photoprism-$TEST_FAMILY" \
        -o jsonpath='{.items[0].spec.rules[0].host}' 2>/dev/null || echo "")

    if [ -n "$INGRESS" ]; then
        log_info "Ingress configured: $INGRESS"
    else
        log_warn "Ingress not found (may be expected in test environment)"
    fi
}

# Run all tests
main() {
    test_start_onboarding
    test_provide_family_name
    test_confirm_domain
    test_provide_email
    test_execute_deployment
    test_verify_pods
    test_check_storage
    test_verify_ingress

    echo ""
    echo "========================================="
    echo -e "${GREEN}All tests passed!${NC}"
    echo "========================================="
    echo ""
    echo "Test family: $TEST_FAMILY"
    echo "Namespace: photoprism-$TEST_FAMILY"
    echo "Session ID: $SESSION_ID"
    echo ""
}

main
```

**Make executable:**
```bash
chmod +x services/photoprism/tests/test_e2e_onboarding.sh
```

---

#### Step 2: Create Python E2E Tests

**File:** `services/photoprism/tests/test_e2e_onboarding.py`

```python
"""
End-to-end tests for PhotoPrism onboarding

Run with: pytest tests/test_e2e_onboarding.py -v
"""

import pytest
import httpx
import asyncio
import subprocess
import time
from typing import Dict

# Configuration
API_URL = "http://localhost:8000"
TEST_EMAIL = "test@example.com"
CLEANUP = True


class OnboardingE2ETest:
    """End-to-end onboarding test suite"""

    def __init__(self):
        self.api_url = API_URL
        self.session_id = None
        self.family_name = f"test-{int(time.time())}"
        self.deployment_info = None

    async def test_full_flow(self):
        """Test complete onboarding flow"""

        async with httpx.AsyncClient(base_url=self.api_url, timeout=30.0) as client:
            # Step 1: Start onboarding
            await self._test_start_onboarding(client)

            # Step 2: Provide family name
            await self._test_provide_family_name(client)

            # Step 3: Confirm domain
            await self._test_confirm_domain(client)

            # Step 4: Provide email
            await self._test_provide_email(client)

        # Step 5: Deploy (subprocess)
        await self._test_deploy()

        # Step 6: Verify deployment
        await self._test_verify_deployment()

        # Step 7: Check storage
        async with httpx.AsyncClient(base_url=self.api_url, timeout=30.0) as client:
            await self._test_check_storage(client)

        print(f"\n✓ All tests passed for family: {self.family_name}")

    async def _test_start_onboarding(self, client: httpx.AsyncClient):
        """Start onboarding"""
        print("Test 1: Start onboarding...")

        response = await client.post(
            "/api/v1/photoprism/onboard",
            json={
                "user_id": "test-user",
                "user_email": TEST_EMAIL
            }
        )

        assert response.status_code == 200, f"Failed to start: {response.text}"
        data = response.json()

        assert data["step"] == "WELCOME"
        assert "session_id" in data

        self.session_id = data["session_id"]
        print(f"  ✓ Session started: {self.session_id}")

    async def _test_provide_family_name(self, client: httpx.AsyncClient):
        """Provide family name"""
        print("Test 2: Provide family name...")

        response = await client.post(
            f"/api/v1/photoprism/onboard/{self.session_id}/respond",
            json={"user_input": self.family_name}
        )

        assert response.status_code == 200
        data = response.json()

        assert "CHECK_DOMAIN" in data["step"] or "CONFIRM_DOMAIN" in data["step"]
        print(f"  ✓ Family name accepted: {self.family_name}")

    async def _test_confirm_domain(self, client: httpx.AsyncClient):
        """Confirm domain"""
        print("Test 3: Confirm domain...")

        response = await client.post(
            f"/api/v1/photoprism/onboard/{self.session_id}/respond",
            json={"user_input": "yes"}
        )

        assert response.status_code == 200
        data = response.json()

        assert "COLLECT_CONTACT" in data["step"] or "DEPLOYMENT" in data["step"]
        print("  ✓ Domain confirmed")

    async def _test_provide_email(self, client: httpx.AsyncClient):
        """Provide contact email"""
        print("Test 4: Provide email...")

        response = await client.post(
            f"/api/v1/photoprism/onboard/{self.session_id}/respond",
            json={"user_input": TEST_EMAIL}
        )

        assert response.status_code == 200
        data = response.json()

        assert data.get("deployment_info") is not None
        self.deployment_info = data["deployment_info"]
        print("  ✓ Email accepted, deployment ready")

    async def _test_deploy(self):
        """Execute deployment"""
        print("Test 5: Execute deployment...")

        env = {
            "FAMILY_NAME": self.family_name,
            "PREFERRED_NAME": f"Test Family {self.family_name}",
            "CONTACT_EMAIL": TEST_EMAIL,
            "ENABLE_GPU": "false",
            "ENABLE_AUTHELIA": "false"
        }

        result = subprocess.run(
            ["./deploy-family.sh"],
            cwd="services/photoprism",
            env=env,
            capture_output=True,
            text=True
        )

        assert result.returncode == 0, f"Deployment failed:\n{result.stderr}"
        print("  ✓ Deployment completed")

    async def _test_verify_deployment(self):
        """Verify pods are running"""
        print("Test 6: Verify pods...")

        # Wait for pods (max 5 minutes)
        for _ in range(30):
            result = subprocess.run(
                [
                    "kubectl", "get", "pods",
                    "-n", f"photoprism-{self.family_name}",
                    "--field-selector=status.phase=Running",
                    "--no-headers"
                ],
                capture_output=True,
                text=True
            )

            pod_count = len(result.stdout.strip().split('\n')) if result.stdout.strip() else 0

            if pod_count >= 3:
                print(f"  ✓ All pods running ({pod_count}/3)")
                return

            await asyncio.sleep(10)

        raise AssertionError("Pods not ready after 5 minutes")

    async def _test_check_storage(self, client: httpx.AsyncClient):
        """Check storage metrics"""
        print("Test 7: Check storage...")

        response = await client.get(
            f"/api/v1/photoprism/storage",
            params={"family_name": self.family_name}
        )

        assert response.status_code == 200
        data = response.json()

        assert data["namespace"] == f"photoprism-{self.family_name}"
        assert "storage" in data

        usage = data["storage"]["photos"]["usage_percent"]
        print(f"  ✓ Storage metrics available ({usage}% used)")

    async def cleanup(self):
        """Cleanup test resources"""
        if not CLEANUP:
            print(f"\nSkipping cleanup for: {self.family_name}")
            return

        print(f"\nCleaning up test resources for: {self.family_name}")

        # Delete namespace
        subprocess.run(
            ["kubectl", "delete", "namespace", f"photoprism-{self.family_name}", "--ignore-not-found=true"],
            capture_output=True
        )

        # Delete overlay
        subprocess.run(
            ["rm", "-rf", f"services/photoprism/kustomize/overlays/{self.family_name}"],
            capture_output=True
        )

        print("  ✓ Cleanup complete")


@pytest.mark.asyncio
async def test_photoprism_onboarding_e2e():
    """Run end-to-end onboarding test"""

    test = OnboardingE2ETest()

    try:
        await test.test_full_flow()
    finally:
        await test.cleanup()


if __name__ == "__main__":
    # Run directly
    asyncio.run(test_photoprism_onboarding_e2e())
```

---

#### Step 3: Add CI/CD Integration

**File:** `.github/workflows/photoprism-e2e.yml`

```yaml
name: PhotoPrism E2E Tests

on:
  push:
    branches: [main, claude/*]
    paths:
      - 'services/photoprism/**'
      - 'cluster/ai-ops-agent/**'
  pull_request:
    branches: [main]

jobs:
  e2e-test:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v3

    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.11'

    - name: Install dependencies
      run: |
        pip install -r cluster/ai-ops-agent/requirements.txt
        pip install pytest pytest-asyncio httpx

    - name: Set up K3s
      uses: debianmaster/actions-k3s@master
      with:
        version: 'latest'

    - name: Install kubectl
      run: |
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

    - name: Install kustomize
      run: |
        curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
        sudo mv kustomize /usr/local/bin/

    - name: Start AI Ops agent
      run: |
        cd cluster/ai-ops-agent
        uvicorn main:app --host 0.0.0.0 --port 8000 &
        sleep 10

    - name: Run E2E tests
      run: |
        cd services/photoprism/tests
        ./test_e2e_onboarding.sh
      env:
        API_URL: http://localhost:8000
        CLEANUP: true

    - name: Upload logs
      if: failure()
      uses: actions/upload-artifact@v3
      with:
        name: test-logs
        path: /tmp/*.log
```

---

#### Step 4: Add Load Testing

**File:** `services/photoprism/tests/load_test.py`

```python
"""
Load test for PhotoPrism onboarding API

Run with: locust -f tests/load_test.py --host http://localhost:8000
"""

from locust import HttpUser, task, between
import uuid


class OnboardingUser(HttpUser):
    """Simulate concurrent onboarding sessions"""

    wait_time = between(1, 5)

    def on_start(self):
        """Start onboarding session"""
        response = self.client.post(
            "/api/v1/photoprism/onboard",
            json={
                "user_id": f"load-test-{uuid.uuid4().hex[:8]}",
                "user_email": "loadtest@example.com"
            }
        )

        if response.status_code == 200:
            self.session_id = response.json()["session_id"]
        else:
            self.session_id = None

    @task(3)
    def provide_family_name(self):
        """Provide family name"""
        if not self.session_id:
            return

        self.client.post(
            f"/api/v1/photoprism/onboard/{self.session_id}/respond",
            json={"user_input": f"test-{uuid.uuid4().hex[:6]}"}
        )

    @task(1)
    def check_storage(self):
        """Check storage for random family"""
        self.client.get(
            "/api/v1/photoprism/storage",
            params={"family_name": f"test-{uuid.uuid4().hex[:6]}"}
        )
```

**Run load test:**
```bash
pip install locust
locust -f services/photoprism/tests/load_test.py \
  --host http://localhost:8000 \
  --users 50 \
  --spawn-rate 5 \
  --run-time 5m
```

---

### Acceptance Criteria

- ✅ Shell script E2E test runs successfully
- ✅ Python E2E test suite passes
- ✅ CI/CD pipeline runs E2E tests on every PR
- ✅ Load test validates 50+ concurrent users
- ✅ Test cleanup removes all resources
- ✅ Test logs captured for debugging

---

## Task 5: Add Billing Integration

### Current State

**What Exists:**
- ✅ Per-family resource isolation (namespaces, PVCs)
- ✅ `family: $family_name` labels on all resources
- ✅ Storage metrics from Prometheus

**What's Missing:**
- ❌ Cost calculation per family
- ❌ Usage tracking over time
- ❌ Billing database/storage
- ❌ Invoice generation
- ❌ Payment integration

### Why This Matters

To run PhotoPrism as a paid service for families, you need to track costs per family and generate invoices.

### What You Need to Do

#### Step 1: Design Billing Data Model

**Database schema:**

```sql
-- Family accounts
CREATE TABLE families (
    id SERIAL PRIMARY KEY,
    family_name VARCHAR(100) UNIQUE NOT NULL,
    preferred_name VARCHAR(200),
    contact_email VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    status VARCHAR(20) DEFAULT 'active',  -- active, suspended, cancelled
    billing_tier VARCHAR(20) DEFAULT 'standard'  -- free, standard, premium
);

-- Usage metrics (time-series data)
CREATE TABLE usage_metrics (
    id SERIAL PRIMARY KEY,
    family_id INTEGER REFERENCES families(id),
    metric_type VARCHAR(50) NOT NULL,  -- storage_gb, compute_hours, bandwidth_gb
    metric_value NUMERIC(12, 4) NOT NULL,
    recorded_at TIMESTAMP DEFAULT NOW(),
    INDEX idx_family_time (family_id, recorded_at),
    INDEX idx_metric_type (metric_type)
);

-- Monthly invoices
CREATE TABLE invoices (
    id SERIAL PRIMARY KEY,
    family_id INTEGER REFERENCES families(id),
    invoice_number VARCHAR(50) UNIQUE NOT NULL,
    billing_period_start DATE NOT NULL,
    billing_period_end DATE NOT NULL,

    -- Line items
    storage_gb_hours NUMERIC(12, 2),
    storage_cost NUMERIC(10, 2),

    compute_hours NUMERIC(12, 2),
    compute_cost NUMERIC(10, 2),

    bandwidth_gb NUMERIC(12, 2),
    bandwidth_cost NUMERIC(10, 2),

    domain_cost NUMERIC(10, 2),

    subtotal NUMERIC(10, 2),
    tax NUMERIC(10, 2),
    total NUMERIC(10, 2),

    status VARCHAR(20) DEFAULT 'pending',  -- pending, paid, overdue
    created_at TIMESTAMP DEFAULT NOW(),
    paid_at TIMESTAMP,

    INDEX idx_family_period (family_id, billing_period_start)
);

-- Payments
CREATE TABLE payments (
    id SERIAL PRIMARY KEY,
    invoice_id INTEGER REFERENCES invoices(id),
    family_id INTEGER REFERENCES families(id),
    amount NUMERIC(10, 2) NOT NULL,
    payment_method VARCHAR(50),  -- stripe, paypal, credit_card
    transaction_id VARCHAR(255),
    status VARCHAR(20) DEFAULT 'pending',  -- pending, completed, failed, refunded
    created_at TIMESTAMP DEFAULT NOW()
);
```

---

#### Step 2: Create Billing Module

**File:** `cluster/ai-ops-agent/ai_ops_agent/billing/__init__.py`

```python
"""
Billing and usage tracking module

Tracks resource usage per family and generates invoices.
"""

import asyncio
from datetime import datetime, timedelta
from typing import Dict, List, Optional
import asyncpg
from prometheus_api_client import PrometheusConnect

class BillingManager:
    """Manage billing and usage tracking"""

    def __init__(self, db_url: str, prometheus_url: str):
        self.db_url = db_url
        self.prom = PrometheusConnect(url=prometheus_url, disable_ssl=True)
        self.pool = None

    async def initialize(self):
        """Initialize database connection pool"""
        self.pool = await asyncpg.create_pool(self.db_url)

    async def close(self):
        """Close database connections"""
        if self.pool:
            await self.pool.close()

    # Pricing (per month)
    PRICING = {
        'storage_gb': 0.05,      # $0.05 per GB per month
        'compute_hour': 0.10,    # $0.10 per vCPU hour
        'bandwidth_gb': 0.12,    # $0.12 per GB bandwidth
        'domain': 2.00,          # $2.00 per month (domain cost amortized)
        'base_fee': 5.00         # $5.00 base platform fee
    }

    async def collect_usage_metrics(self, family_name: str) -> Dict:
        """
        Collect current usage metrics for a family

        Returns:
            {
                'storage_gb': float,
                'compute_hours': float,  # Since last collection
                'bandwidth_gb': float
            }
        """
        namespace = f"photoprism-{family_name}"

        # Query 1: Storage usage (current snapshot)
        storage_query = f'''
            sum(kubelet_volume_stats_used_bytes{{namespace="{namespace}"}}) / 1024 / 1024 / 1024
        '''
        storage_result = self.prom.custom_query(query=storage_query)
        storage_gb = float(storage_result[0]['value'][1]) if storage_result else 0

        # Query 2: Compute hours (sum of CPU usage over last hour)
        compute_query = f'''
            sum(rate(container_cpu_usage_seconds_total{{namespace="{namespace}"}}[1h])) * 1
        '''
        compute_result = self.prom.custom_query(query=compute_query)
        compute_hours = float(compute_result[0]['value'][1]) if compute_result else 0

        # Query 3: Network bandwidth (sum over last hour)
        bandwidth_query = f'''
            sum(rate(container_network_transmit_bytes_total{{namespace="{namespace}"}}[1h])) * 3600 / 1024 / 1024 / 1024
        '''
        bandwidth_result = self.prom.custom_query(query=bandwidth_query)
        bandwidth_gb = float(bandwidth_result[0]['value'][1]) if bandwidth_result else 0

        return {
            'storage_gb': round(storage_gb, 4),
            'compute_hours': round(compute_hours, 4),
            'bandwidth_gb': round(bandwidth_gb, 4)
        }

    async def record_usage(self, family_name: str, metrics: Dict):
        """
        Record usage metrics to database

        Args:
            family_name: Family identifier
            metrics: Usage metrics from collect_usage_metrics()
        """
        async with self.pool.acquire() as conn:
            # Get family ID
            family_id = await conn.fetchval(
                'SELECT id FROM families WHERE family_name = $1',
                family_name
            )

            if not family_id:
                raise ValueError(f"Family {family_name} not found in billing database")

            # Insert metrics
            for metric_type, metric_value in metrics.items():
                await conn.execute('''
                    INSERT INTO usage_metrics (family_id, metric_type, metric_value)
                    VALUES ($1, $2, $3)
                ''', family_id, metric_type, metric_value)

    async def calculate_monthly_cost(
        self,
        family_name: str,
        start_date: datetime,
        end_date: datetime
    ) -> Dict:
        """
        Calculate cost for a billing period

        Returns:
            {
                'storage_cost': float,
                'compute_cost': float,
                'bandwidth_cost': float,
                'domain_cost': float,
                'base_fee': float,
                'subtotal': float,
                'tax': float,
                'total': float
            }
        """
        async with self.pool.acquire() as conn:
            # Get family ID
            family_id = await conn.fetchval(
                'SELECT id FROM families WHERE family_name = $1',
                family_name
            )

            # Get average storage for period
            storage_avg = await conn.fetchval('''
                SELECT AVG(metric_value)
                FROM usage_metrics
                WHERE family_id = $1
                  AND metric_type = 'storage_gb'
                  AND recorded_at BETWEEN $2 AND $3
            ''', family_id, start_date, end_date) or 0

            # Get total compute hours
            compute_total = await conn.fetchval('''
                SELECT SUM(metric_value)
                FROM usage_metrics
                WHERE family_id = $1
                  AND metric_type = 'compute_hours'
                  AND recorded_at BETWEEN $2 AND $3
            ''', family_id, start_date, end_date) or 0

            # Get total bandwidth
            bandwidth_total = await conn.fetchval('''
                SELECT SUM(metric_value)
                FROM usage_metrics
                WHERE family_id = $1
                  AND metric_type = 'bandwidth_gb'
                  AND recorded_at BETWEEN $2 AND $3
            ''', family_id, start_date, end_date) or 0

            # Calculate costs
            storage_cost = float(storage_avg) * self.PRICING['storage_gb']
            compute_cost = float(compute_total) * self.PRICING['compute_hour']
            bandwidth_cost = float(bandwidth_total) * self.PRICING['bandwidth_gb']
            domain_cost = self.PRICING['domain']
            base_fee = self.PRICING['base_fee']

            subtotal = storage_cost + compute_cost + bandwidth_cost + domain_cost + base_fee
            tax = subtotal * 0.08  # 8% tax (adjust per region)
            total = subtotal + tax

            return {
                'storage_gb_hours': round(float(storage_avg), 2),
                'storage_cost': round(storage_cost, 2),
                'compute_hours': round(float(compute_total), 2),
                'compute_cost': round(compute_cost, 2),
                'bandwidth_gb': round(float(bandwidth_total), 2),
                'bandwidth_cost': round(bandwidth_cost, 2),
                'domain_cost': round(domain_cost, 2),
                'base_fee': round(base_fee, 2),
                'subtotal': round(subtotal, 2),
                'tax': round(tax, 2),
                'total': round(total, 2)
            }

    async def generate_invoice(
        self,
        family_name: str,
        billing_period_start: datetime,
        billing_period_end: datetime
    ) -> int:
        """
        Generate invoice for a family

        Returns:
            invoice_id
        """
        async with self.pool.acquire() as conn:
            # Get family ID
            family_id = await conn.fetchval(
                'SELECT id FROM families WHERE family_name = $1',
                family_name
            )

            # Calculate costs
            costs = await self.calculate_monthly_cost(
                family_name,
                billing_period_start,
                billing_period_end
            )

            # Generate invoice number
            invoice_number = f"INV-{family_name.upper()}-{billing_period_start.strftime('%Y%m')}"

            # Insert invoice
            invoice_id = await conn.fetchval('''
                INSERT INTO invoices (
                    family_id, invoice_number,
                    billing_period_start, billing_period_end,
                    storage_gb_hours, storage_cost,
                    compute_hours, compute_cost,
                    bandwidth_gb, bandwidth_cost,
                    domain_cost,
                    subtotal, tax, total,
                    status
                ) VALUES (
                    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, 'pending'
                )
                RETURNING id
            ''',
                family_id, invoice_number,
                billing_period_start, billing_period_end,
                costs['storage_gb_hours'], costs['storage_cost'],
                costs['compute_hours'], costs['compute_cost'],
                costs['bandwidth_gb'], costs['bandwidth_cost'],
                costs['domain_cost'],
                costs['subtotal'], costs['tax'], costs['total']
            )

            return invoice_id

    async def get_invoice(self, invoice_id: int) -> Dict:
        """Get invoice details"""
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow('''
                SELECT
                    i.*,
                    f.family_name,
                    f.preferred_name,
                    f.contact_email
                FROM invoices i
                JOIN families f ON i.family_id = f.id
                WHERE i.id = $1
            ''', invoice_id)

            if not row:
                return None

            return dict(row)
```

---

#### Step 3: Add Billing API Endpoints

**File:** `cluster/ai-ops-agent/main.py`

```python
from ai_ops_agent.billing import BillingManager
from datetime import datetime, timedelta

# Initialize billing
POSTGRES_URL = os.getenv("POSTGRES_URL", "postgresql://user:pass@localhost/billing")
billing_manager = BillingManager(
    db_url=POSTGRES_URL,
    prometheus_url=PROMETHEUS_URL
)

@app.on_event("startup")
async def startup():
    """Initialize billing on startup"""
    await billing_manager.initialize()

@app.on_event("shutdown")
async def shutdown():
    """Close billing connections"""
    await billing_manager.close()


@app.get("/api/v1/billing/usage/{family_name}")
async def get_current_usage(family_name: str):
    """Get current usage for a family"""

    try:
        metrics = await billing_manager.collect_usage_metrics(family_name)

        # Calculate estimated monthly cost
        days_in_month = 30
        estimated_storage_cost = metrics['storage_gb'] * billing_manager.PRICING['storage_gb']
        estimated_compute_cost = metrics['compute_hours'] * 24 * days_in_month * billing_manager.PRICING['compute_hour']
        estimated_bandwidth_cost = metrics['bandwidth_gb'] * days_in_month * billing_manager.PRICING['bandwidth_gb']

        estimated_monthly = (
            estimated_storage_cost +
            estimated_compute_cost +
            estimated_bandwidth_cost +
            billing_manager.PRICING['domain'] +
            billing_manager.PRICING['base_fee']
        )

        return {
            "family_name": family_name,
            "current_usage": metrics,
            "estimated_monthly_cost": round(estimated_monthly, 2),
            "pricing": billing_manager.PRICING
        }

    except Exception as e:
        logger.error(f"Error getting usage: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/v1/billing/invoices/generate/{family_name}")
async def generate_invoice(family_name: str, month: Optional[str] = None):
    """
    Generate invoice for a family

    Args:
        month: YYYY-MM format (defaults to last month)
    """

    try:
        # Default to last month
        if month:
            start_date = datetime.strptime(month, "%Y-%m")
        else:
            today = datetime.now()
            start_date = (today.replace(day=1) - timedelta(days=1)).replace(day=1)

        # Calculate end date (last day of month)
        if start_date.month == 12:
            end_date = start_date.replace(year=start_date.year + 1, month=1, day=1) - timedelta(days=1)
        else:
            end_date = start_date.replace(month=start_date.month + 1, day=1) - timedelta(days=1)

        # Generate invoice
        invoice_id = await billing_manager.generate_invoice(
            family_name,
            start_date,
            end_date
        )

        # Get invoice details
        invoice = await billing_manager.get_invoice(invoice_id)

        return {
            "status": "success",
            "invoice_id": invoice_id,
            "invoice": invoice
        }

    except Exception as e:
        logger.error(f"Error generating invoice: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v1/billing/invoices/{invoice_id}")
async def get_invoice(invoice_id: int):
    """Get invoice details"""

    try:
        invoice = await billing_manager.get_invoice(invoice_id)

        if not invoice:
            raise HTTPException(status_code=404, detail="Invoice not found")

        return invoice

    except Exception as e:
        logger.error(f"Error getting invoice: {e}")
        raise HTTPException(status_code=500, detail=str(e))
```

---

#### Step 4: Add Cron Job for Usage Collection

**File:** `services/photoprism/kubernetes/billing-cronjob.yaml`

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: collect-usage-metrics
  namespace: ai-ops-agent
spec:
  schedule: "0 * * * *"  # Every hour
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: ai-ops-agent
          containers:
          - name: collect-usage
            image: curlimages/curl:latest
            command:
            - /bin/sh
            - -c
            - |
              # Get list of all PhotoPrism families
              FAMILIES=$(kubectl get namespaces -l app=photoprism -o jsonpath='{.items[*].metadata.labels.family}')

              for FAMILY in $FAMILIES; do
                echo "Collecting usage for: $FAMILY"

                # Call billing API to collect and record usage
                curl -X POST http://ai-ops-agent:8000/api/v1/billing/collect/$FAMILY
              done
          restartPolicy: OnFailure
```

---

#### Step 5: Invoice Generation

**HTML Invoice Template:**

```python
# In billing module
def generate_invoice_html(invoice: Dict) -> str:
    """Generate HTML invoice"""

    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body {{ font-family: Arial, sans-serif; margin: 40px; }}
            .header {{ text-align: center; margin-bottom: 30px; }}
            .invoice-details {{ margin-bottom: 20px; }}
            table {{ width: 100%; border-collapse: collapse; }}
            th, td {{ padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }}
            .total {{ font-weight: bold; font-size: 1.2em; }}
        </style>
    </head>
    <body>
        <div class="header">
            <h1>SuhLabs PhotoPrism</h1>
            <h2>Invoice</h2>
        </div>

        <div class="invoice-details">
            <p><strong>Invoice #:</strong> {invoice['invoice_number']}</p>
            <p><strong>Bill To:</strong> {invoice['preferred_name']}</p>
            <p><strong>Email:</strong> {invoice['contact_email']}</p>
            <p><strong>Period:</strong> {invoice['billing_period_start']} to {invoice['billing_period_end']}</p>
        </div>

        <table>
            <thead>
                <tr>
                    <th>Description</th>
                    <th>Quantity</th>
                    <th>Rate</th>
                    <th>Amount</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td>Photo Storage</td>
                    <td>{invoice['storage_gb_hours']:.2f} GB</td>
                    <td>$0.05/GB</td>
                    <td>${invoice['storage_cost']:.2f}</td>
                </tr>
                <tr>
                    <td>Compute (CPU Hours)</td>
                    <td>{invoice['compute_hours']:.2f} hours</td>
                    <td>$0.10/hour</td>
                    <td>${invoice['compute_cost']:.2f}</td>
                </tr>
                <tr>
                    <td>Bandwidth</td>
                    <td>{invoice['bandwidth_gb']:.2f} GB</td>
                    <td>$0.12/GB</td>
                    <td>${invoice['bandwidth_cost']:.2f}</td>
                </tr>
                <tr>
                    <td>Domain Registration</td>
                    <td>1</td>
                    <td>$2.00/month</td>
                    <td>${invoice['domain_cost']:.2f}</td>
                </tr>
                <tr>
                    <td>Platform Fee</td>
                    <td>1</td>
                    <td>$5.00/month</td>
                    <td>$5.00</td>
                </tr>
                <tr>
                    <td colspan="3" style="text-align: right;"><strong>Subtotal:</strong></td>
                    <td>${invoice['subtotal']:.2f}</td>
                </tr>
                <tr>
                    <td colspan="3" style="text-align: right;"><strong>Tax (8%):</strong></td>
                    <td>${invoice['tax']:.2f}</td>
                </tr>
                <tr class="total">
                    <td colspan="3" style="text-align: right;">Total Due:</td>
                    <td>${invoice['total']:.2f}</td>
                </tr>
            </tbody>
        </table>

        <div style="margin-top: 40px;">
            <p><strong>Payment Instructions:</strong></p>
            <p>Please pay by credit card at: https://photos.{invoice['family_name']}.family/billing</p>
            <p>Or send payment to: billing@suhlabs.io</p>
        </div>
    </body>
    </html>
    """
```

---

### Acceptance Criteria

- ✅ PostgreSQL database schema created
- ✅ Billing module collects usage metrics
- ✅ Usage recorded hourly via cron job
- ✅ Monthly invoices generated automatically
- ✅ API endpoints for usage and invoices
- ✅ HTML invoice generation
- ✅ Cost calculation accurate based on Prometheus metrics
- ✅ (Optional) Stripe/PayPal payment integration

---

## General Notes

### Prerequisites for All Tasks

**Required Tools:**
- `kubectl` (1.24+)
- `kustomize` (5.0+)
- Python 3.11+
- PostgreSQL 14+ (for billing)
- Access to Kubernetes cluster
- Prometheus + Alertmanager installed

**API Keys Needed:**
- Cloudflare API token (for domain registration)
- Optional: Namecheap/GoDaddy API keys
- Optional: Stripe/PayPal API keys (for billing)

### Testing Strategy

For each task:
1. **Unit tests** - Test individual functions
2. **Integration tests** - Test module interactions
3. **E2E tests** - Test full user flow
4. **Manual testing** - Verify in browser/CLI

### Documentation Updates

After completing each task, update:
- `docs/ONBOARDING.md` - User-facing onboarding guide
- `docs/FAMILY_NAME_VARIABLES.md` - Infrastructure variable usage
- API documentation (OpenAPI/Swagger)
- README files in each module

### Deployment Checklist

Before deploying to production:
- [ ] All tests passing
- [ ] API keys configured in Vault
- [ ] Prometheus alerts configured
- [ ] DNS registrar account set up
- [ ] Billing database initialized
- [ ] Backup/restore tested
- [ ] Load testing completed
- [ ] Security audit passed
- [ ] Documentation complete

---

## Contact & Support

**For Questions:**
- Technical: Review code in `cluster/ai-ops-agent/` and `services/photoprism/`
- Architecture: See `docs/HANDOFF.md` and `docs/ONBOARDING.md`
- Billing: See database schema in this document

**Useful Commands:**
```bash
# Check deployment status
kubectl get all -n photoprism-smith

# View logs
kubectl logs -f deployment/photoprism -n photoprism-smith

# Test API
curl http://localhost:8000/api/v1/photoprism/onboard

# Run tests
cd services/photoprism/tests
./test_e2e_onboarding.sh
```

---

## Summary

This knowledge transfer document covers **5 remaining enhancement tasks**:

1. **✅ Kustomize Templates** - Complete base templates for MinIO, MariaDB, PhotoPrism, Ingress
2. **✅ Domain Registrar APIs** - Implement real Cloudflare domain registration
3. **✅ Prometheus Integration** - Add real metrics queries for storage monitoring
4. **✅ E2E Test Script** - Automated testing for full onboarding flow
5. **✅ Billing Integration** - Usage tracking, invoicing, and payment

Each task includes:
- **Current state** - What exists vs. what's missing
- **Step-by-step implementation** - Detailed code examples
- **Testing procedures** - How to validate the work
- **Acceptance criteria** - Definition of "done"

**Total estimated effort:** 3-5 days for an experienced developer (1 day per task)

Good luck! 🚀
