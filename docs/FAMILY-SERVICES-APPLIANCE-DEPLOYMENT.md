# Family Services Appliance - Deployment Guide

## Overview

This guide covers the software deployment and configuration of the Family Services Appliance after hardware assembly is complete.

## Prerequisites

- ✅ Hardware assembled per [Assembly Guide](FAMILY-SERVICES-APPLIANCE-ASSEMBLY.md)
- ✅ Both nodes powered on and accessible via SSH
- ✅ Network configured and tested
- ✅ Storage mounted and verified
- ✅ UPS configured and tested

## Deployment Architecture

```
┌─────────────────────────────────────────────────────┐
│  High Availability k3s Cluster                       │
│                                                       │
│  ┌──────────────────┐      ┌──────────────────┐    │
│  │   Node 1         │      │   Node 2         │    │
│  │   k3s server     │◄────►│   k3s server     │    │
│  │   + etcd         │ HA   │   + etcd         │    │
│  │                  │      │                  │    │
│  │  ┌────────────┐  │      │  ┌────────────┐  │    │
│  │  │ CoreDNS    │  │      │  │ CoreDNS    │  │    │
│  │  │ MetalLB    │  │      │  │ MetalLB    │  │    │
│  │  │ cert-mgr   │  │      │  │ cert-mgr   │  │    │
│  │  └────────────┘  │      │  └────────────┘  │    │
│  │                  │      │                  │    │
│  │  ┌────────────┐  │      │  ┌────────────┐  │    │
│  │  │PhotoPrism  │  │      │  │PhotoPrism  │  │    │
│  │  │Email       │  │      │  │Email       │  │    │
│  │  │Nextcloud   │  │      │  │Nextcloud   │  │    │
│  │  └────────────┘  │      │  └────────────┘  │    │
│  └──────────────────┘      └──────────────────┘    │
│           │                         │               │
│           └────────┬────────────────┘               │
│                    │                                 │
│         ┌──────────▼──────────┐                    │
│         │  Shared Storage     │                    │
│         │  (Longhorn/NFS)     │                    │
│         └─────────────────────┘                    │
└─────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────┐
│  dnsmasq/Pi-hole    │  ← External DNS/DHCP
│  (on Node 1 or      │     Ad-blocking
│   separate device)  │     Family network
└─────────────────────┘
```

## Phase 1: Base System Configuration

### 1.1 Update Both Nodes

Run on **both Node 1 and Node 2**:

```bash
# Update package lists
apt update

# Upgrade all packages
apt upgrade -y

# Install essential tools
apt install -y \
  curl \
  wget \
  git \
  vim \
  htop \
  iotop \
  net-tools \
  dnsutils \
  nfs-common \
  open-iscsi \
  util-linux

# Reboot if kernel updated
reboot
```

### 1.2 Configure Hostnames and DNS

**Node 1:**
```bash
hostnamectl set-hostname familysvc-node1

# Set static IP (edit for your network)
cat > /etc/netplan/01-netcfg.yaml <<EOF
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: no
      addresses:
        - 192.168.1.11/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses:
          - 1.1.1.1
          - 8.8.8.8
EOF

netplan apply
```

**Node 2:**
```bash
hostnamectl set-hostname familysvc-node2

cat > /etc/netplan/01-netcfg.yaml <<EOF
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: no
      addresses:
        - 192.168.1.12/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses:
          - 1.1.1.1
          - 8.8.8.8
EOF

netplan apply
```

### 1.3 Configure /etc/hosts

**Both nodes:**
```bash
cat >> /etc/hosts <<EOF
192.168.1.11    familysvc-node1 node1
192.168.1.12    familysvc-node2 node2
192.168.1.100   familysvc-vip   # MetalLB VIP (will configure later)
EOF
```

### 1.4 Set Up SSH Keys

**On your management workstation:**
```bash
# Generate SSH key if you don't have one
ssh-keygen -t ed25519 -C "familysvc-admin"

# Copy to both nodes
ssh-copy-id root@192.168.1.11
ssh-copy-id root@192.168.1.12
```

**Disable password authentication (recommended):**
```bash
# On both nodes
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd
```

### 1.5 Configure NTP

**Both nodes:**
```bash
timedatectl set-timezone America/New_York  # Adjust for your timezone
timedatectl set-ntp true

# Verify
timedatectl status
```

### 1.6 Disable Swap (Required for k3s)

**Both nodes:**
```bash
# Disable swap immediately
swapoff -a

# Disable swap permanently
sed -i '/ swap / s/^/#/' /etc/fstab

# Verify
free -h  # Swap should show 0
```

### 1.7 Configure Kernel Parameters

**Both nodes:**
```bash
cat >> /etc/sysctl.d/99-k3s.conf <<EOF
# K3s kernel parameters
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
net.ipv6.conf.all.forwarding        = 1

# Performance tuning
vm.max_map_count                    = 262144
fs.inotify.max_user_watches         = 524288
fs.inotify.max_user_instances       = 512
EOF

# Load br_netfilter module
modprobe br_netfilter

# Make it persistent
echo "br_netfilter" >> /etc/modules-load.d/k3s.conf

# Apply settings
sysctl --system
```

## Phase 2: Storage Configuration

### 2.1 Prepare NVMe Storage for k3s

**Both nodes:**
```bash
# Create directories for k3s data
mkdir -p /mnt/nvme/k3s
mkdir -p /mnt/nvme/longhorn
mkdir -p /mnt/nvme/containers

# Set permissions
chmod 755 /mnt/nvme/k3s
chmod 755 /mnt/nvme/longhorn
```

### 2.2 Optional: Set Up NFS for Shared Storage

**If using separate NAS:**
```bash
# Install NFS client (already done in 1.1)
# Create mount point
mkdir -p /mnt/nfs

# Add to fstab
echo "nas.home.lan:/volume1/familysvc /mnt/nfs nfs defaults,_netdev 0 0" >> /etc/fstab

# Mount
mount -a

# Verify
df -h /mnt/nfs
```

## Phase 3: k3s Cluster Deployment

### 3.1 Install k3s on Node 1 (Primary Server)

**Node 1:**
```bash
# Set environment variables
export K3S_TOKEN="your-secure-cluster-token-here"  # Generate with: openssl rand -hex 32
export INSTALL_K3S_VERSION="v1.28.5+k3s1"  # Pin version for consistency

# Install k3s with embedded etcd
curl -sfL https://get.k3s.io | sh -s - server \
  --cluster-init \
  --data-dir=/mnt/nvme/k3s \
  --disable traefik \
  --disable servicelb \
  --flannel-backend=vxlan \
  --write-kubeconfig-mode=644 \
  --node-name=familysvc-node1 \
  --node-taint node-role.kubernetes.io/master=true:NoSchedule \
  --token="${K3S_TOKEN}"

# Wait for k3s to be ready (may take 2-3 minutes)
sleep 120

# Verify installation
systemctl status k3s
kubectl get nodes

# Should show:
# NAME                STATUS   ROLES                  AGE   VERSION
# familysvc-node1     Ready    control-plane,master   1m    v1.28.5+k3s1
```

### 3.2 Install k3s on Node 2 (Secondary Server)

**Get cluster token from Node 1:**
```bash
# On Node 1:
cat /var/lib/rancher/k3s/server/token
# Copy this token - you'll need it for Node 2
```

**Node 2:**
```bash
# Set environment variables
export K3S_TOKEN="<token-from-node1>"
export K3S_URL="https://192.168.1.11:6443"
export INSTALL_K3S_VERSION="v1.28.5+k3s1"

# Install k3s as additional server
curl -sfL https://get.k3s.io | sh -s - server \
  --server="${K3S_URL}" \
  --data-dir=/mnt/nvme/k3s \
  --disable traefik \
  --disable servicelb \
  --flannel-backend=vxlan \
  --write-kubeconfig-mode=644 \
  --node-name=familysvc-node2 \
  --node-taint node-role.kubernetes.io/master=true:NoSchedule \
  --token="${K3S_TOKEN}"

# Wait for node to join
sleep 120

# Verify
systemctl status k3s
```

### 3.3 Verify Cluster

**On Node 1:**
```bash
# Check nodes
kubectl get nodes -o wide

# Should show both nodes:
# NAME                STATUS   ROLES                  AGE   VERSION
# familysvc-node1     Ready    control-plane,master   5m    v1.28.5+k3s1
# familysvc-node2     Ready    control-plane,master   2m    v1.28.5+k3s1

# Check etcd cluster
kubectl get endpoints -n kube-system

# Check system pods
kubectl get pods -n kube-system
```

### 3.4 Configure kubectl on Management Workstation

**On your workstation:**
```bash
# Copy kubeconfig from Node 1
scp root@192.168.1.11:/etc/rancher/k3s/k3s.yaml ~/.kube/familysvc-config

# Edit the file to use correct server address
sed -i 's/127.0.0.1/192.168.1.11/' ~/.kube/familysvc-config

# Set KUBECONFIG
export KUBECONFIG=~/.kube/familysvc-config

# Or merge into main config
KUBECONFIG=~/.kube/config:~/.kube/familysvc-config kubectl config view --flatten > ~/.kube/config.new
mv ~/.kube/config.new ~/.kube/config

# Test
kubectl get nodes
```

## Phase 4: Deploy Foundation Services

### 4.1 Install MetalLB (Load Balancer)

**Create MetalLB namespace and deploy:**
```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml

# Wait for pods to be ready
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=90s
```

**Configure IP address pool:**
```bash
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.100-192.168.1.110  # Adjust for your network
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-pool
EOF
```

### 4.2 Install cert-manager

**Install cert-manager CRDs and controller:**
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml

# Wait for pods
kubectl wait --namespace cert-manager \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/instance=cert-manager \
  --timeout=90s
```

**Create internal CA (for *.home.lan certificates):**
```bash
# Generate CA certificate
openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
  -keyout ca.key -out ca.crt \
  -subj "/CN=Family Services CA" \
  -addext "subjectAltName=DNS:*.home.lan,DNS:home.lan"

# Create secret
kubectl create secret tls ca-key-pair \
  --cert=ca.crt \
  --key=ca.key \
  --namespace=cert-manager

# Create ClusterIssuer
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-issuer
spec:
  ca:
    secretName: ca-key-pair
EOF
```

**Install CA cert on family devices:**
```bash
# Distribute ca.crt to family devices
# iOS: Email cert, tap to install
# Android: Settings > Security > Install cert
# macOS: Keychain Access > Import > Trust
# Windows: certmgr.msc > Trusted Root > Import
```

### 4.3 Install Longhorn (Distributed Storage)

**Install Longhorn:**
```bash
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.5.3/deploy/longhorn.yaml

# Wait for deployment (may take 5 minutes)
kubectl wait --namespace longhorn-system \
  --for=condition=ready pod \
  --selector=app=longhorn-manager \
  --timeout=300s
```

**Configure Longhorn to use NVMe storage:**
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: longhorn-default-setting
  namespace: longhorn-system
data:
  default-data-path: "/mnt/nvme/longhorn"
  replica-soft-anti-affinity: "true"
  replica-auto-balance: "best-effort"
EOF
```

**Access Longhorn UI:**
```bash
# Create LoadBalancer service
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: longhorn-frontend-lb
  namespace: longhorn-system
spec:
  type: LoadBalancer
  selector:
    app: longhorn-ui
  ports:
  - port: 80
    targetPort: 8000
EOF

# Get IP
kubectl get svc -n longhorn-system longhorn-frontend-lb

# Access at http://<LoadBalancer-IP>
```

### 4.4 Install Monitoring Stack

**Install kube-prometheus-stack:**
```bash
# Add Helm repo
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.retention=30d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi \
  --set grafana.adminPassword=admin  # CHANGE THIS!

# Wait for pods
kubectl wait --namespace monitoring \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=prometheus \
  --timeout=180s
```

**Access Grafana:**
```bash
# Create LoadBalancer
kubectl patch svc kube-prometheus-stack-grafana -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'

# Get IP
kubectl get svc -n monitoring kube-prometheus-stack-grafana

# Access at http://<LoadBalancer-IP>
# Default: admin / <password-you-set>
```

## Phase 5: Deploy Application Services

### 5.1 Create Namespaces

```bash
kubectl create namespace photoprism
kubectl create namespace email
kubectl create namespace files
kubectl create namespace dns
kubectl create namespace media
```

### 5.2 Deploy PhotoPrism

**Create PhotoPrism deployment:**
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: photoprism-storage
  namespace: photoprism
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: longhorn
  resources:
    requests:
      storage: 100Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: photoprism-originals
  namespace: photoprism
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: longhorn
  resources:
    requests:
      storage: 500Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: photoprism
  namespace: photoprism
spec:
  replicas: 1
  selector:
    matchLabels:
      app: photoprism
  template:
    metadata:
      labels:
        app: photoprism
    spec:
      containers:
      - name: photoprism
        image: photoprism/photoprism:latest
        ports:
        - containerPort: 2342
        env:
        - name: PHOTOPRISM_ADMIN_PASSWORD
          value: "changeme"  # CHANGE THIS!
        - name: PHOTOPRISM_SITE_URL
          value: "https://photos.home.lan"
        - name: PHOTOPRISM_ORIGINALS_LIMIT
          value: "5000"
        - name: PHOTOPRISM_HTTP_COMPRESSION
          value: "gzip"
        - name: PHOTOPRISM_DATABASE_DRIVER
          value: "sqlite"
        - name: PHOTOPRISM_DETECT_NSFW
          value: "false"
        - name: PHOTOPRISM_UPLOAD_NSFW
          value: "true"
        volumeMounts:
        - name: storage
          mountPath: /photoprism/storage
        - name: originals
          mountPath: /photoprism/originals
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
      volumes:
      - name: storage
        persistentVolumeClaim:
          claimName: photoprism-storage
      - name: originals
        persistentVolumeClaim:
          claimName: photoprism-originals
---
apiVersion: v1
kind: Service
metadata:
  name: photoprism
  namespace: photoprism
spec:
  type: LoadBalancer
  selector:
    app: photoprism
  ports:
  - port: 80
    targetPort: 2342
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: photoprism-tls
  namespace: photoprism
spec:
  secretName: photoprism-tls
  issuerRef:
    name: ca-issuer
    kind: ClusterIssuer
  dnsNames:
  - photos.home.lan
EOF
```

**Get PhotoPrism IP:**
```bash
kubectl get svc -n photoprism photoprism
# Access at http://<LoadBalancer-IP>
```

### 5.3 Deploy Pi-hole (DNS/DHCP/Ad-blocking)

**Option A: Deploy on host (Node 1) - Recommended**

This avoids DNS resolution issues during cluster problems.

**On Node 1:**
```bash
# Install Pi-hole directly on host
curl -sSL https://install.pi-hole.net | bash

# Follow installer prompts:
# - Interface: eth0
# - DNS: Cloudflare (1.1.1.1)
# - Block lists: Yes
# - Admin interface: Yes
# - Web server: Yes

# Set admin password
pihole -a -p

# Configure to point to k3s services
# Add custom DNS records in /etc/pihole/custom.list:
192.168.1.100 photos.home.lan
192.168.1.101 mail.home.lan
192.168.1.102 files.home.lan

# Restart DNS
pihole restartdns

# Access Pi-hole admin: http://192.168.1.11/admin
```

**Option B: Deploy in k3s - Advanced**

Only if you want Pi-hole HA (not recommended for DNS).

```bash
cat <<EOF | kubectl apply -f -
# Similar deployment to PhotoPrism
# Use hostNetwork: true for DNS on port 53
# Requires careful configuration
EOF
```

### 5.4 Configure Family Devices

**Update DHCP settings:**

1. Access your router's admin interface
2. Set primary DNS to Node 1 IP (192.168.1.11)
3. Set secondary DNS to 1.1.1.1 (fallback)
4. Or: Disable router DHCP and use Pi-hole DHCP

**Test DNS:**
```bash
# From family device
nslookup photos.home.lan
# Should return: 192.168.1.100 (MetalLB IP)

# Test ad-blocking
nslookup ads.google.com
# Should return: 0.0.0.0 (blocked)
```

## Phase 6: Configure Backup and Monitoring

### 6.1 Deploy Velero (Cluster Backup)

```bash
# Install Velero CLI
wget https://github.com/vmware-tanzu/velero/releases/download/v1.12.3/velero-v1.12.3-linux-arm64.tar.gz
tar -xvf velero-v1.12.3-linux-arm64.tar.gz
sudo mv velero-v1.12.3-linux-arm64/velero /usr/local/bin/

# Configure backup location (using NFS or S3-compatible)
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.8.0 \
  --bucket familysvc-backups \
  --secret-file ./credentials-velero \
  --backup-location-config region=us-east-1,s3ForcePathStyle="true",s3Url=http://minio.home.lan \
  --use-volume-snapshots=true \
  --snapshot-location-config region=us-east-1

# Create backup schedule
velero schedule create daily-backup \
  --schedule="0 2 * * *" \
  --include-namespaces photoprism,email,files \
  --ttl 720h0m0s  # 30 days retention
```

### 6.2 Configure Alert Manager

```bash
cat <<EOF | kubectl apply -f -
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
      group_by: ['alertname', 'cluster', 'service']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 12h
      receiver: 'family-email'
    
    receivers:
    - name: 'family-email'
      email_configs:
      - to: 'alerts@family.com'
        from: 'alerts@home.lan'
        smarthost: 'smtp.home.lan:587'
        auth_username: 'alerts@home.lan'
        auth_password: 'password'  # Use secret in production
        headers:
          Subject: '[FamilySvc] {{ .GroupLabels.alertname }}'
EOF

# Restart AlertManager to apply config
kubectl rollout restart deployment -n monitoring kube-prometheus-stack-alertmanager
```

## Phase 7: Testing and Validation

### 7.1 Test High Availability

**Failover test:**
```bash
# On Node 1, stop k3s
systemctl stop k3s

# From workstation, watch pod distribution
watch kubectl get pods -A -o wide

# Pods should reschedule to Node 2 within 60 seconds

# Services should remain accessible via LoadBalancer IPs

# Restart Node 1
systemctl start k3s

# Verify cluster health
kubectl get nodes
```

### 7.2 Test Backup and Restore

```bash
# Create manual backup
velero backup create test-backup

# Verify
velero backup describe test-backup

# Simulate disaster (delete namespace)
kubectl delete namespace photoprism

# Restore from backup
velero restore create --from-backup test-backup

# Verify restoration
kubectl get pods -n photoprism
```

### 7.3 Load Testing

**PhotoPrism:**
```bash
# Upload test photos
# Use PhotoPrism mobile app or web interface
# Upload 100+ photos simultaneously

# Monitor resource usage
kubectl top nodes
kubectl top pods -n photoprism
```

## Phase 8: Documentation and Handoff

### 8.1 Create User Documentation

Create simplified guides for family members:
- How to access services (bookmarks)
- How to upload photos to PhotoPrism
- Email client configuration (IMAP/SMTP)
- Troubleshooting common issues

### 8.2 Create Operations Runbook

Document procedures for:
- Restarting services
- Adding storage
- Upgrading cluster
- Disaster recovery
- Common troubleshooting

### 8.3 Set Up Monitoring Dashboard

**Create Grafana dashboard for family view:**
- Service uptime status (green/red indicators)
- Storage usage per service
- Recent alerts
- Backup status

## Maintenance Tasks

### Daily (Automated)
```bash
# Create cron jobs on Node 1
crontab -e

# Check cluster health
0 */6 * * * kubectl get nodes -o wide >> /var/log/cluster-health.log

# Backup verification
0 3 * * * velero backup-location get >> /var/log/backup-status.log
```

### Weekly
- Review logs for errors
- Check disk space usage
- Verify backups are completing
- Update service images (if auto-update disabled)

### Monthly
- Review and rotate logs
- Update operating system
- Test disaster recovery
- Review resource usage trends

### Quarterly
- Update k3s version
- Review and tune resource allocations
- Security audit
- Update documentation

## Troubleshooting Guide

### Cluster Issues

**Node not joining cluster:**
```bash
# Check k3s logs
journalctl -u k3s -f

# Common fixes:
# - Verify token matches
# - Check firewall (ports 6443, 8472, 10250)
# - Ensure clocks are synchronized
```

**Pods stuck in Pending:**
```bash
# Check pod status
kubectl describe pod <pod-name> -n <namespace>

# Common causes:
# - Insufficient resources
# - PVC not bound
# - Node taints/tolerations
# - Image pull errors
```

### Service Issues

**Service not accessible:**
```bash
# Check service and endpoints
kubectl get svc,endpoints -n <namespace>

# Verify MetalLB
kubectl get ipaddresspool -n metallb-system
kubectl logs -n metallb-system -l app=metallb

# Check DNS
nslookup service.home.lan 192.168.1.11
```

**Certificate errors:**
```bash
# Check cert-manager
kubectl get certificate,certificaterequest -A

# Describe certificate
kubectl describe certificate <name> -n <namespace>

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager
```

## Next Steps

1. ✅ **Complete deployment**
2. **Monitor for 1 week** - Watch for issues
3. **Tune resource allocations** based on actual usage
4. **Add additional services** as needed
5. **Document customizations** for your specific needs
6. **Share improvements** upstream to community

## Support Resources

- k3s Documentation: https://docs.k3s.io/
- Kubernetes Documentation: https://kubernetes.io/docs/
- MetalLB: https://metallb.universe.tf/
- cert-manager: https://cert-manager.io/docs/
- Longhorn: https://longhorn.io/docs/
- PhotoPrism: https://docs.photoprism.app/

## Appendix: Useful Commands

```bash
# Check cluster status
kubectl get nodes
kubectl get pods -A
kubectl top nodes
kubectl top pods -A

# Restart a service
kubectl rollout restart deployment <name> -n <namespace>

# View logs
kubectl logs -f <pod-name> -n <namespace>

# Access pod shell
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Drain node for maintenance
kubectl drain node1 --ignore-daemonsets --delete-emptydir-data

# Bring node back online
kubectl uncordon node1
```

## Revision History

- v1.0 (2024-11-18): Initial deployment guide for Pro Tier HA cluster
