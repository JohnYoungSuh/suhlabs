# CoreDNS Foundation Service

Custom CoreDNS deployment with corp.local zone for the AI Ops Substrate project.

## What This Provides

1. **Cluster DNS** - Standard Kubernetes service discovery (cluster.local)
2. **Custom Zone** - corp.local for internal services
3. **DNS Resolution** - Forward external queries to upstream DNS
4. **Service Discovery** - Automatic DNS records for K8s services

## Quick Start

```bash
cd cluster/foundation/coredns

# Deploy CoreDNS
./deploy.sh

# Verify deployment
kubectl get pods -n kube-system -l k8s-app=coredns
```

## Configuration

### Standard K8s DNS (cluster.local)

Automatically resolves:
- `kubernetes.default.svc.cluster.local` → K8s API
- `vault.vault.svc.cluster.local` → Vault service
- `ai-ops-agent.ai-ops.svc.cluster.local` → AI Ops Agent

### Custom Zone (corp.local)

Manually configured records in `values.yaml`:

```
ns1.corp.local              → 10.96.0.10 (CoreDNS)
vault.corp.local            → CNAME vault.vault.svc.cluster.local
ai-ops.corp.local           → CNAME ai-ops-agent.ai-ops.svc.cluster.local
*.corp.local                → 10.0.1.100 (Wildcard)
```

## DNS Testing

### Test Cluster DNS

```bash
kubectl run -it dns-test --image=busybox:1.36 --rm --restart=Never -- \
  nslookup kubernetes.default.svc.cluster.local
```

Expected output:
```
Server:    10.96.0.10
Address 1: 10.96.0.10 coredns.kube-system.svc.cluster.local

Name:      kubernetes.default.svc.cluster.local
Address 1: 10.96.0.1 kubernetes.default.svc.cluster.local
```

### Test Custom Zone

```bash
kubectl run -it dns-test --image=busybox:1.36 --rm --restart=Never -- \
  nslookup ns1.corp.local
```

Expected output:
```
Server:    10.96.0.10
Address 1: 10.96.0.10 coredns.kube-system.svc.cluster.local

Name:      ns1.corp.local
Address 1: 10.96.0.10
```

### Test External DNS

```bash
kubectl run -it dns-test --image=busybox:1.36 --rm --restart=Never -- \
  nslookup google.com
```

Should resolve to Google's IP (forwarded to upstream DNS).

## Troubleshooting

### CoreDNS Pods Not Starting

```bash
# Check pod status
kubectl get pods -n kube-system -l k8s-app=coredns

# Check logs
kubectl logs -n kube-system -l k8s-app=coredns
```

Common issues:
- Port 53 already in use
- Invalid zone file syntax
- Resource limits too low

### DNS Not Resolving

```bash
# Check CoreDNS config
kubectl get configmap coredns -n kube-system -o yaml

# Test from inside pod
kubectl run -it debug --image=busybox:1.36 --rm --restart=Never -- sh
# Then inside pod:
cat /etc/resolv.conf
nslookup kubernetes.default
```

### Zone File Errors

```bash
# Check CoreDNS logs for syntax errors
kubectl logs -n kube-system -l k8s-app=coredns | grep error

# Common errors:
# - Missing trailing dot in SOA
# - Invalid TTL values
# - Incorrect zone name
```

## Adding New DNS Records

Edit `values.yaml` and add records to the `corp.local.db` zone file:

```yaml
zoneFiles:
  - filename: corp.local.db
    domain: corp.local
    contents: |
      # ... existing records ...

      ; New service
      myservice  IN  A   10.0.1.101
```

Then apply changes:

```bash
helm upgrade coredns coredns/coredns \
  -n kube-system \
  -f values.yaml
```

## Performance Tuning

### Cache Settings

Adjust cache TTL in `values.yaml`:

```yaml
- name: cache
  parameters: 30  # seconds
```

Higher values = less load, but stale data.
Lower values = fresh data, but more queries.

### Resource Limits

For production, increase resources:

```yaml
resources:
  limits:
    cpu: 500m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

### Replicas

High availability:

```yaml
replicaCount: 3  # For production
```

## Integration with Other Services

### Vault

Vault service will be accessible at:
- `vault.vault.svc.cluster.local` (K8s service discovery)
- `vault.corp.local` (custom zone CNAME)

### AI Ops Agent

AI Ops Agent will be accessible at:
- `ai-ops-agent.ai-ops.svc.cluster.local` (K8s service discovery)
- `ai-ops.corp.local` (custom zone CNAME)

### Cert-Manager

Cert-manager will use CoreDNS for:
- Service discovery (finding Vault)
- DNS challenges (if using Let's Encrypt)

## Next Steps

After CoreDNS is deployed:

1. **Deploy Vault** with PKI engine (Hour 2-3)
2. **Configure cert-manager** to use Vault PKI (Day 5)
3. **Deploy services** with automatic DNS records (Day 5+)

## Learning Outcomes

By deploying CoreDNS, you learn:

- ✅ How Kubernetes DNS works
- ✅ CoreDNS plugin system
- ✅ Custom DNS zones
- ✅ Service discovery patterns
- ✅ DNS troubleshooting

## Reference

- [CoreDNS Documentation](https://coredns.io/manual/toc/)
- [Kubernetes DNS Specification](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
- [CoreDNS Plugins](https://coredns.io/plugins/)

---

**Status**: Foundation service for Day 4 (Hour 1)
