# PhotoPrism Deployment Guide

Complete guide to deploying PhotoPrism on your K3s cluster with MinIO storage, MariaDB, and optional Authelia SSO.

## Prerequisites

- K3s cluster running (3 masters, 2+ workers)
- kubectl configured
- cert-manager installed (for TLS certificates)
- Vault PKI configured (for cert-manager issuer)
- Longhorn storage class (for persistent volumes)
- nginx-ingress controller
- Domain name (recommended: *.family TLD)

## Architecture Overview

```
User → HTTPS (TLS via cert-manager)
    ↓
Ingress (nginx)
    ↓
Authelia (Optional SSO)
    ↓
PhotoPrism (2 replicas)
    ↓
├─→ MariaDB (StatefulSet, 50GB)
└─→ MinIO (S3-compatible, 3TB)
```

## Storage Requirements

- **MariaDB**: 50GB (photo metadata, user data)
- **MinIO**: 3TB (original photos, videos)
- **PhotoPrism Cache**: 100GB (thumbnails, sidecars)
- **Total**: ~3.15TB

## Step-by-Step Deployment

### Option 1: Automated Deployment (Recommended)

```bash
# Navigate to PhotoPrism service directory
cd services/photoprism

# Run deployment script
./deploy.sh

# Follow prompts for optional Authelia installation
```

The script will:
1. Create namespace
2. Deploy storage (PVCs)
3. Deploy MinIO with automatic bucket creation
4. Deploy MariaDB
5. Deploy PhotoPrism
6. Create Ingress with TLS
7. Optionally deploy Authelia for SSO

### Option 2: Manual Deployment

```bash
# 1. Create namespace
kubectl apply -f kubernetes/00-namespace.yaml

# 2. Create storage
kubectl apply -f kubernetes/01-storage.yaml

# 3. Deploy MinIO
kubectl apply -f kubernetes/02-minio.yaml

# Wait for MinIO
kubectl wait --for=condition=available --timeout=300s deployment/minio -n photoprism

# Initialize MinIO bucket
kubectl wait --for=condition=complete --timeout=120s job/minio-init -n photoprism

# 4. Deploy MariaDB
kubectl apply -f kubernetes/03-mariadb.yaml

# Wait for MariaDB
kubectl wait --for=condition=ready --timeout=300s pod -l app=mariadb -n photoprism

# 5. Deploy PhotoPrism
kubectl apply -f kubernetes/04-photoprism.yaml

# Wait for PhotoPrism
kubectl wait --for=condition=available --timeout=600s deployment/photoprism -n photoprism

# 6. Create Ingress
kubectl apply -f kubernetes/05-ingress.yaml

# 7. (Optional) Deploy Authelia
kubectl apply -f kubernetes/06-authelia.yaml
```

## Configuration

### 1. Domain Names

Edit `kubernetes/05-ingress.yaml` and replace `familyname.family` with your actual domain:

```yaml
- host: photos.yourdomain.family  # Main PhotoPrism UI
- host: minio.photos.yourdomain.family  # MinIO console (admin)
- host: auth.yourdomain.family  # Authelia SSO (if enabled)
```

### 2. DNS Records

Add DNS A records pointing to your K3s ingress IP:

```
photos.yourdomain.family        A    <INGRESS_IP>
minio.photos.yourdomain.family  A    <INGRESS_IP>
auth.yourdomain.family          A    <INGRESS_IP>
```

Get ingress IP:
```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### 3. Secrets Management

**Important**: Replace default passwords before production use!

#### Using Vault (Recommended)

```bash
# Store MinIO credentials in Vault
vault kv put secret/photoprism/minio \
  rootUser=your-minio-admin \
  rootPassword=your-secure-password

# Store MariaDB credentials
vault kv put secret/photoprism/mariadb \
  root-password=your-mariadb-root-password \
  password=your-photoprism-db-password

# Store PhotoPrism admin password
vault kv put secret/photoprism/admin \
  password=your-admin-password
```

Then update secrets to reference Vault:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: minio-credentials
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/role: "photoprism"
    vault.hashicorp.com/agent-inject-secret-minio: "secret/photoprism/minio"
```

#### Manual Secrets Update

```bash
# Update MinIO credentials
kubectl create secret generic minio-credentials \
  --from-literal=rootUser=your-username \
  --from-literal=rootPassword=your-password \
  -n photoprism \
  --dry-run=client -o yaml | kubectl apply -f -

# Update MariaDB credentials
kubectl create secret generic mariadb-credentials \
  --from-literal=root-password=your-root-password \
  --from-literal=password=your-db-password \
  -n photoprism \
  --dry-run=client -o yaml | kubectl apply -f -

# Update PhotoPrism admin password
kubectl create secret generic photoprism-secrets \
  --from-literal=PHOTOPRISM_ADMIN_PASSWORD=your-admin-password \
  -n photoprism \
  --dry-run=client -o yaml | kubectl apply -f -
```

### 4. GPU Support (Optional)

If you have GPU nodes for ML acceleration:

1. Label GPU nodes:
```bash
kubectl label nodes <node-name> gpu=true
```

2. Enable GPU in `kubernetes/04-photoprism.yaml`:
```yaml
resources:
  limits:
    nvidia.com/gpu: "1"

# Un comment node affinity
affinity:
  nodeAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      preference:
        matchExpressions:
        - key: gpu
          operator: In
          values:
          - "true"
```

3. Redeploy:
```bash
kubectl apply -f kubernetes/04-photoprism.yaml
```

### 5. Authelia SSO Configuration

If using Authelia for centralized authentication:

1. Edit `kubernetes/06-authelia.yaml`:
   - Change `familyname.family` to your domain
   - Update `jwt_secret` and other secrets
   - Configure SMTP for password reset emails

2. Add users to `users_database.yml`:
```yaml
users:
  john:
    displayname: "John Doe"
    password: "$argon2id$v=19$..."  # Generate with: docker run authelia/authelia:latest authelia hash-password 'yourpassword'
    email: john@familyname.family
    groups:
      - family
```

3. Configure PhotoPrism Ingress for Authelia:
```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/auth-url: "http://authelia.authelia.svc.cluster.local:9091/api/verify"
    nginx.ingress.kubernetes.io/auth-signin: "https://auth.yourdomain.family"
```

## Verification

### Check Deployment Status

```bash
# Get all resources
kubectl get all -n photoprism

# Check pod logs
kubectl logs -f deployment/photoprism -n photoprism
kubectl logs -f statefulset/mariadb -n photoprism
kubectl logs -f deployment/minio -n photoprism

# Check TLS certificate
kubectl get certificate -n photoprism
kubectl describe certificate photoprism-tls -n photoprism
```

### Access Services

1. **PhotoPrism**: https://photos.yourdomain.family
2. **MinIO Console**: https://minio.photos.yourdomain.family
3. **Authelia** (if enabled): https://auth.yourdomain.family

### Test Upload

1. Log in to PhotoPrism with admin credentials
2. Click "Upload" button
3. Select test photos
4. Verify photos appear in Library

### Test Search (ML Features)

1. Wait for indexing to complete (check "Index" tab)
2. Use search bar to find photos by:
   - People (if faces detected)
   - Objects ("dog", "car", "beach")
   - Locations (if GPS data available)
   - Colors

## Performance Tuning

### Database Optimization

Adjust MariaDB settings in `kubernetes/03-mariadb.yaml`:

```yaml
innodb_buffer_pool_size = 4G  # Increase for better performance
max_connections = 1000  # Increase for more concurrent users
```

### PhotoPrism Workers

Adjust workers based on CPU cores:

```yaml
PHOTOPRISM_WORKERS: "8"  # Default: 4, increase for faster indexing
```

### Storage Performance

For better I/O performance:
- Use local NVMe/SSD storage for database
- Use network storage (MinIO) only for originals
- Enable Longhorn SSD storage class

## Scaling

### Horizontal Scaling (More Replicas)

```bash
# Scale PhotoPrism to 4 replicas
kubectl scale deployment photoprism --replicas=4 -n photoprism
```

### Vertical Scaling (More Resources)

Edit `kubernetes/04-photoprism.yaml`:

```yaml
resources:
  requests:
    cpu: 2000m  # Increase from 1000m
    memory: 8Gi  # Increase from 4Gi
  limits:
    cpu: 8000m  # Increase from 4000m
    memory: 32Gi  # Increase from 16Gi
```

### Storage Expansion

```bash
# Expand PVC (if storage class supports it)
kubectl patch pvc minio-photos -n photoprism -p '{"spec":{"resources":{"requests":{"storage":"5Ti"}}}}'
```

## Backup & Restore

See [BACKUP.md](./BACKUP.md) for detailed backup procedures.

### Quick Backup

```bash
# Backup MariaDB
kubectl exec -it statefulset/mariadb -n photoprism -- \
  mysqldump -u root -p photoprism > photoprism-backup.sql

# Backup MinIO (using mc)
kubectl port-forward -n photoprism svc/minio 9000:9000 &
mc alias set myminio http://localhost:9000 <user> <password>
mc mirror myminio/photoprism ./photoprism-backup/
```

## Troubleshooting

See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for common issues and solutions.

### Common Issues

1. **PhotoPrism won't start**:
   - Check database connection: `kubectl logs deployment/photoprism -n photoprism`
   - Verify MariaDB is ready: `kubectl get pods -n photoprism`

2. **Upload fails**:
   - Check MinIO accessibility
   - Verify S3 credentials in secrets
   - Check ingress max body size

3. **TLS certificate not issued**:
   - Check cert-manager logs: `kubectl logs -n cert-manager -l app=cert-manager`
   - Verify Vault issuer: `kubectl get clusterissuer vault-issuer`

## Security Considerations

1. **Change all default passwords** immediately
2. **Enable Authelia** for centralized authentication
3. **Use Vault** for secrets management
4. **Enable mTLS** between services (via service mesh)
5. **Regular security updates**: Update PhotoPrism, MariaDB, MinIO images
6. **Network policies**: Restrict inter-pod communication
7. **RBAC**: Limit Kubernetes access to PhotoPrism namespace

## Next Steps

1. **Invite family members**: Settings → Users → Add User
2. **Create albums**: Organize photos into albums
3. **Share photos**: Generate sharing links for guests
4. **Set up backups**: Configure automated backups (see BACKUP.md)
5. **Monitor usage**: Set up Prometheus metrics

## Support

- **PhotoPrism Docs**: https://docs.photoprism.app/
- **PhotoPrism Community**: https://www.photoprism.app/community
- **GitHub Issues**: https://github.com/photoprism/photoprism/issues
- **suhlabs Documentation**: ../../docs/

---

**Deployment checklist**: ✅ Deployed | ✅ DNS configured | ✅ TLS working | ✅ Passwords changed | ✅ Backups configured
