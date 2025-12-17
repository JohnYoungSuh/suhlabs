# DNS Pod Troubleshooting Guide

## Scenario 1: No Kubernetes Cluster (Current Situation)

### Symptoms
- Ansible playbook fails with "Expected at least 1 CoreDNS pods, found 0"
- `kubectl` command not found or can't connect
- No cluster running

### Solution: Create a Cluster

**Prerequisites:**
- Docker Desktop installed and running
- kubectl installed
- kind installed

**Steps:**

```bash
# 1. Verify Docker is running
docker ps

# 2. Create Kind cluster
cd ~/suhlabs
kind create cluster --name aiops-dev --config bootstrap/kind-cluster.yaml

# 3. Verify cluster is ready
kubectl cluster-info
kubectl get nodes

# 4. Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=coredns

# 5. If CoreDNS is running, deploy custom DNS
cd cluster/foundation/coredns
./deploy.sh
```

---

## Scenario 2: CoreDNS Pods CrashLooping

### Symptoms
```bash
$ kubectl get pods -n kube-system -l k8s-app=coredns
NAME                       READY   STATUS             RESTARTS   AGE
coredns-5d78c9869d-abc12   0/1     CrashLoopBackOff   5          10m
```

### Diagnosis Steps

**Step 1: Check pod logs**
```bash
kubectl logs -n kube-system -l k8s-app=coredns --tail=50
```

**Common errors and fixes:**

#### Error: "Port 53 already in use"
```
[FATAL] plugin/bind: dns already listening on :53
```

**Fix:** Another DNS service is using port 53
```bash
# On Linux/Mac - find what's using port 53
sudo lsof -i :53

# If it's systemd-resolved (common on Ubuntu)
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved

# Then restart CoreDNS
kubectl rollout restart deployment/coredns -n kube-system
```

#### Error: "Invalid Corefile"
```
[ERROR] plugin/file: Could not read zone file
```

**Fix:** Syntax error in CoreDNS config
```bash
# Check ConfigMap
kubectl get configmap coredns -n kube-system -o yaml

# Fix by editing
kubectl edit configmap coredns -n kube-system

# Restart CoreDNS
kubectl rollout restart deployment/coredns -n kube-system
```

#### Error: "OOMKilled"
```bash
$ kubectl describe pod -n kube-system coredns-xxx
Reason: OOMKilled
```

**Fix:** Increase memory limits
```bash
kubectl set resources deployment/coredns -n kube-system \
  --limits=memory=170Mi \
  --requests=memory=70Mi
```

---

## Scenario 3: CoreDNS Not Resolving Names

### Symptoms
- Pods can't resolve service names
- `nslookup kubernetes.default` fails from inside pods

### Diagnosis Steps

**Step 1: Test DNS from a pod**
```bash
kubectl run -it --rm debug --image=busybox:1.36 --restart=Never -- sh

# Inside the pod:
nslookup kubernetes.default
cat /etc/resolv.conf
exit
```

**Step 2: Check CoreDNS is running**
```bash
kubectl get pods -n kube-system -l k8s-app=coredns
# Should show 2 pods in "Running" state
```

**Step 3: Check kube-dns service**
```bash
kubectl get svc -n kube-system kube-dns
# Should show ClusterIP (usually 10.96.0.10)
```

**Step 4: Check pod's DNS config**
```bash
kubectl run test --image=nginx --dry-run=client -o yaml | grep -A 5 dnsPolicy
```

### Fixes

#### Fix 1: CoreDNS ConfigMap is wrong
```bash
# Reset to default
kubectl get configmap coredns -n kube-system -o yaml > coredns-backup.yaml

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf {
           max_concurrent 1000
        }
        cache 30
        loop
        reload
        loadbalance
    }
EOF

kubectl rollout restart deployment/coredns -n kube-system
```

#### Fix 2: Service endpoints are wrong
```bash
# Check endpoints
kubectl get endpoints -n kube-system kube-dns

# If no endpoints, CoreDNS pods aren't selected properly
kubectl get pods -n kube-system -l k8s-app=coredns --show-labels

# Check service selector
kubectl get svc kube-dns -n kube-system -o yaml | grep -A 5 selector
```

---

## Scenario 4: Custom DNS Zone Not Working

### Symptoms
- `kubernetes.default` resolves ✓
- `vault.corp.local` doesn't resolve ✗

### Diagnosis

**Check if custom ConfigMap is loaded:**
```bash
kubectl get configmap coredns-custom -n kube-system

# If it doesn't exist, your custom DNS isn't configured
```

### Fix: Deploy Custom DNS

```bash
cd cluster/foundation/coredns
./deploy.sh

# This will:
# 1. Add custom zone configuration
# 2. Create corp.local zone file
# 3. Restart CoreDNS
```

**Manual fix:**
```bash
# Create custom ConfigMap
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns-custom
  namespace: kube-system
data:
  corp.server: |
    corp.local:53 {
        errors
        cache 30
        file /etc/coredns/corp.local.db
    }
  corp.local.db: |
    \$ORIGIN corp.local.
    @   IN SOA ns1 admin 2024010101 7200 3600 1209600 3600
    @   IN NS ns1
    ns1 IN A 10.96.0.10
    vault IN CNAME vault.vault.svc.cluster.local.
    ai-ops IN CNAME ai-ops-agent.ai-ops.svc.cluster.local.
    * IN A 10.0.1.100
EOF

# Update CoreDNS deployment to use custom config
kubectl rollout restart deployment/coredns -n kube-system
```

---

## Scenario 5: DNS Works But Slow

### Symptoms
- DNS queries succeed but take >1 second
- Pods timeout on startup

### Diagnosis
```bash
# Time DNS resolution from inside a pod
kubectl run -it --rm debug --image=busybox:1.36 --restart=Never -- sh -c "time nslookup kubernetes.default"

# Check CoreDNS metrics
kubectl port-forward -n kube-system svc/kube-dns 9153:9153
curl localhost:9153/metrics | grep coredns_dns_request_duration
```

### Fixes

#### Fix 1: Increase cache TTL
```bash
# Edit CoreDNS ConfigMap
kubectl edit configmap coredns -n kube-system

# Change:
cache 30
# To:
cache 300  # 5 minutes
```

#### Fix 2: Increase replicas
```bash
kubectl scale deployment coredns -n kube-system --replicas=3
```

#### Fix 3: Add more resources
```bash
kubectl set resources deployment/coredns -n kube-system \
  --limits=cpu=500m,memory=256Mi \
  --requests=cpu=100m,memory=128Mi
```

---

## Quick Diagnostic Commands

```bash
# Pod status
kubectl get pods -n kube-system -l k8s-app=coredns

# Pod logs (last 50 lines)
kubectl logs -n kube-system -l k8s-app=coredns --tail=50

# Pod logs (follow live)
kubectl logs -n kube-system -l k8s-app=coredns -f

# Describe pod (shows events)
kubectl describe pod -n kube-system -l k8s-app=coredns

# Check service
kubectl get svc kube-dns -n kube-system

# Check endpoints
kubectl get endpoints kube-dns -n kube-system

# View ConfigMap
kubectl get configmap coredns -n kube-system -o yaml

# Test DNS from pod
kubectl run -it --rm debug --image=busybox:1.36 --restart=Never -- nslookup kubernetes.default

# Check CoreDNS metrics
kubectl port-forward -n kube-system svc/kube-dns 9153:9153 &
curl localhost:9153/metrics | grep coredns
```

---

## Verification Checklist

After fixing, verify DNS is working:

- [ ] CoreDNS pods are Running (2/2 READY)
  ```bash
  kubectl get pods -n kube-system -l k8s-app=coredns
  ```

- [ ] kube-dns service exists
  ```bash
  kubectl get svc kube-dns -n kube-system
  ```

- [ ] Endpoints are populated
  ```bash
  kubectl get endpoints kube-dns -n kube-system
  ```

- [ ] cluster.local resolution works
  ```bash
  kubectl run -it --rm test --image=busybox:1.36 --restart=Never -- nslookup kubernetes.default
  ```

- [ ] Custom corp.local resolution works (if deployed)
  ```bash
  kubectl run -it --rm test --image=busybox:1.36 --restart=Never -- nslookup vault.corp.local
  ```

- [ ] Pods can reach internet
  ```bash
  kubectl run -it --rm test --image=busybox:1.36 --restart=Never -- nslookup google.com
  ```

---

## Prevention Tips

1. **Always check cluster state before deploying**
   ```bash
   kubectl cluster-info
   kubectl get nodes
   ```

2. **Use Helm for CoreDNS (easier to manage)**
   ```bash
   helm repo add coredns https://coredns.github.io/helm
   helm install coredns coredns/coredns -f values.yaml
   ```

3. **Monitor CoreDNS health**
   ```bash
   # Add to your monitoring
   kubectl port-forward -n kube-system svc/kube-dns 9153:9153
   curl localhost:9153/health
   ```

4. **Test DNS after every cluster change**
   ```bash
   kubectl run -it --rm test --image=busybox:1.36 --restart=Never -- nslookup kubernetes.default
   ```

5. **Keep CoreDNS config in version control**
   ```bash
   kubectl get configmap coredns -n kube-system -o yaml > coredns-backup.yaml
   git add coredns-backup.yaml
   git commit -m "Backup CoreDNS config"
   ```

---

## Environment-Specific Issues

### Kind Clusters
- CoreDNS included by default
- Custom DNS requires ConfigMap updates
- May need to disable built-in DNS for custom zones

### Docker Desktop
- Built-in Kubernetes includes CoreDNS
- Sometimes conflicts with host DNS (port 53)
- May need to change CoreDNS port

### Cloud Environments (AWS, GCP, Azure)
- Managed DNS often better than custom
- Check cloud provider's DNS service first
- May have network policy restrictions

---

## Getting Help

If still stuck:

1. **Gather diagnostics**
   ```bash
   kubectl get all -n kube-system
   kubectl logs -n kube-system -l k8s-app=coredns --tail=100
   kubectl describe pod -n kube-system -l k8s-app=coredns
   ```

2. **Check Kubernetes version compatibility**
   ```bash
   kubectl version
   ```

3. **Review CoreDNS documentation**
   - https://coredns.io/manual/toc/

4. **Search for similar issues**
   - https://github.com/coredns/coredns/issues
