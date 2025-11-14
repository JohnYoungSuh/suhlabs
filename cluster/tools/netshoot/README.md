# Netshoot Troubleshooting Pod

Netshoot is a powerful container for troubleshooting Kubernetes networking, DNS, TLS certificates, and general cluster issues.

## Quick Start

```bash
# Deploy netshoot pod
./deploy.sh

# Exec into the pod
kubectl exec -it netshoot -n default -- bash

# Delete when done
kubectl delete -f netshoot.yaml
```

## Common Debugging Commands

### DNS Troubleshooting

```bash
# Test internal DNS resolution
nslookup ai-ops-agent.default.svc.cluster.local
nslookup vault.vault.svc.cluster.local
nslookup coredns.kube-system.svc.cluster.local

# Dig for detailed DNS info
dig ai-ops-agent.default.svc.cluster.local
dig @10.96.0.10 ai-ops-agent.default.svc.cluster.local  # Query CoreDNS directly

# Test external DNS
nslookup google.com
```

### Network Connectivity

```bash
# Test service connectivity
curl -v http://ai-ops-agent.default.svc.cluster.local:8000
curl -v http://vault.vault.svc.cluster.local:8200

# Test with specific IP
curl -v http://10.96.0.1:443

# TCP connectivity test
nc -zv ai-ops-agent.default.svc.cluster.local 8000
telnet ai-ops-agent.default.svc.cluster.local 8000

# Trace route
traceroute ai-ops-agent.default.svc.cluster.local

# Check open ports
netstat -tuln
ss -tuln
```

### TLS Certificate Debugging

```bash
# View certificate details
openssl s_client -connect ai-ops-agent.default.svc.cluster.local:8000 -showcerts

# Check certificate expiration
openssl s_client -connect ai-ops-agent.default.svc.cluster.local:8000 </dev/null 2>/dev/null | openssl x509 -noout -dates

# View certificate subject and SANs
openssl s_client -connect ai-ops-agent.default.svc.cluster.local:8000 </dev/null 2>/dev/null | openssl x509 -noout -text | grep -A1 "Subject:"
openssl s_client -connect ai-ops-agent.default.svc.cluster.local:8000 </dev/null 2>/dev/null | openssl x509 -noout -text | grep -A1 "Subject Alternative Name"

# Verify certificate chain
openssl s_client -connect ai-ops-agent.default.svc.cluster.local:8000 -CAfile /etc/ssl/certs/ca-certificates.crt
```

### Kubernetes API Debugging

```bash
# Check certificates (cert-manager)
kubectl get certificates -A
kubectl describe certificate ai-ops-agent-cert -n default

# Check certificate requests
kubectl get certificaterequests -A
kubectl describe certificaterequest <name> -n default

# Check secrets
kubectl get secrets -A | grep tls
kubectl describe secret ai-ops-agent-tls -n default

# Check pod status
kubectl get pods -A -o wide
kubectl describe pod ai-ops-agent-xxx -n default

# Check services and endpoints
kubectl get svc -A
kubectl get endpoints -A
kubectl describe svc ai-ops-agent -n default

# Check events (useful for race conditions!)
kubectl get events -A --sort-by='.lastTimestamp'
kubectl get events -n default --sort-by='.lastTimestamp' | grep -i failed
kubectl get events -n default --sort-by='.lastTimestamp' | grep -i mount

# Check logs
kubectl logs -n default ai-ops-agent-xxx
kubectl logs -n default ai-ops-agent-xxx -c wait-for-certificate  # Init container
kubectl logs -n cert-manager deploy/cert-manager
```

### Network Policies

```bash
# Check network policies
kubectl get networkpolicies -A
kubectl describe networkpolicy <name> -n default

# Test if network policy is blocking traffic
# (Run this from inside netshoot)
curl -v --max-time 5 http://ai-ops-agent.default.svc.cluster.local:8000
```

### Race Condition Debugging

When debugging certificate mount race conditions:

```bash
# Watch pod events in real-time
kubectl get events -n default --watch

# Watch certificate status
watch kubectl get certificate ai-ops-agent-cert -n default

# Check if secret exists
kubectl get secret ai-ops-agent-tls -n default
kubectl get secret ai-ops-agent-tls -n default -o yaml

# Check init container logs
kubectl logs ai-ops-agent-xxx -c wait-for-certificate -n default

# Describe pod to see mount status
kubectl describe pod ai-ops-agent-xxx -n default | grep -A10 "Volumes:"
kubectl describe pod ai-ops-agent-xxx -n default | grep -A10 "Mounts:"
```

### Performance Testing

```bash
# HTTP load testing
ab -n 1000 -c 10 http://ai-ops-agent.default.svc.cluster.local:8000/health

# Bandwidth testing
iperf3 -c <target-ip> -p 5201

# DNS query performance
time nslookup ai-ops-agent.default.svc.cluster.local
```

## Tools Included in Netshoot

- **Network**: curl, wget, netcat, socat, iperf3, mtr, tcpdump, nmap
- **DNS**: dig, nslookup, host
- **TLS/SSL**: openssl
- **Kubernetes**: kubectl (configured with pod's service account)
- **General**: bash, vim, jq, yq, git

## Security Notes

The netshoot pod runs with:
- **Root user (UID 0)**: Required for many network debugging tools
- **NET_ADMIN + NET_RAW capabilities**: Required for tcpdump, nmap, etc.
- **ClusterRole with read access**: Can view most Kubernetes resources

**IMPORTANT**: This is a debugging tool with elevated privileges. Delete it when you're done troubleshooting:

```bash
kubectl delete -f netshoot.yaml
```

## Advanced Usage

### Host Network Mode

For debugging node-level networking issues, enable hostNetwork:

```yaml
spec:
  hostNetwork: true  # Change from false to true
```

Then redeploy:
```bash
kubectl delete -f netshoot.yaml
kubectl apply -f netshoot.yaml
```

### Persistent Storage

To preserve debugging scripts or data:

```yaml
volumes:
- name: debug-data
  persistentVolumeClaim:
    claimName: netshoot-pvc
```

### Multiple Namespaces

Deploy netshoot in different namespaces to test network policies:

```bash
kubectl apply -f netshoot.yaml -n vault
kubectl apply -f netshoot.yaml -n cert-manager
```

## Troubleshooting Tips

### Certificate Race Conditions

1. **Watch events**: `kubectl get events -n default --watch`
2. **Check certificate status**: `kubectl get certificate -n default`
3. **Verify secret exists**: `kubectl get secret ai-ops-agent-tls -n default`
4. **Check init container**: `kubectl logs pod-name -c wait-for-certificate`
5. **Describe pod**: Look for mount failures

### DNS Issues

1. **Check CoreDNS**: `kubectl get pods -n kube-system -l k8s-app=kube-dns`
2. **Test from netshoot**: `nslookup kubernetes.default.svc.cluster.local`
3. **Check DNS config**: `cat /etc/resolv.conf`
4. **Query CoreDNS directly**: `dig @10.96.0.10 service-name.namespace.svc.cluster.local`

### Network Policy Issues

1. **List policies**: `kubectl get networkpolicies -A`
2. **Check pod labels**: `kubectl get pods --show-labels`
3. **Test connectivity**: `curl -v --max-time 5 http://target:port`
4. **Check ingress/egress rules**: `kubectl describe networkpolicy <name>`

## References

- [Netshoot GitHub](https://github.com/nicolaka/netshoot)
- [Kubernetes Debugging](https://kubernetes.io/docs/tasks/debug/)
- [cert-manager Troubleshooting](https://cert-manager.io/docs/troubleshooting/)
