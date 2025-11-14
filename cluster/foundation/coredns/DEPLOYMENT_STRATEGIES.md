# CoreDNS Deployment Strategies

This document explains the two deployment strategies available in `deploy.sh` and when to use each.

## Quick Comparison

| Feature | Development Mode | Production Mode |
|---------|-----------------|-----------------|
| **Command** | `./deploy.sh` | `./deploy.sh --production` |
| **Downtime** | Yes (brief) | Zero downtime |
| **Speed** | Fast (~30s) | Slower (~2-3 min) |
| **Complexity** | Simple | Blue-green deployment |
| **Use Case** | Dev/Homelab | Production clusters |

---

## Development Mode (Default)

### How It Works
```
1. Delete existing CoreDNS resources
2. Helm installs fresh CoreDNS
3. Wait for pods ready
4. Test DNS
```

### Pros
- ✅ Fast deployment
- ✅ Simple and straightforward
- ✅ Avoids immutable field conflicts
- ✅ Clean slate deployment

### Cons
- ❌ Brief DNS outage (5-15 seconds)
- ❌ Applications may fail DNS lookups during transition
- ❌ Not suitable for production

### When to Use
- **Homelab/Development clusters**
- **Non-critical environments**
- **Initial setup**
- **Testing/experimentation**

### Example
```bash
./deploy.sh
```

---

## Production Mode

### How It Works (Blue-Green Deployment)
```
1. Deploy new CoreDNS with temporary name (coredns-new)
2. Verify new deployment is healthy
3. Test new CoreDNS functionality
4. Switch Service selector to new deployment
5. Wait for DNS cache to propagate
6. Delete old deployment
7. Rename new deployment to standard name
```

### Pros
- ✅ Zero downtime
- ✅ Old CoreDNS keeps running during deployment
- ✅ Verify health before switching traffic
- ✅ Safe rollback if new deployment fails
- ✅ Production-ready

### Cons
- ❌ Slower (2-3 minutes vs 30 seconds)
- ❌ More complex
- ❌ Temporarily uses more resources (2 deployments running)

### When to Use
- **Production clusters**
- **Critical infrastructure**
- **When DNS outage is unacceptable**
- **Compliance requirements**
- **Multi-tenant environments**

### Example
```bash
./deploy.sh --production
```

---

## Detailed Flow Diagrams

### Development Mode Flow
```
┌─────────────────────────┐
│  Existing CoreDNS       │
│  (serving traffic)      │
└───────────┬─────────────┘
            │
            ▼
    ┌───────────────┐
    │ DELETE ALL    │ ← DNS OUTAGE STARTS
    │ RESOURCES     │
    └───────┬───────┘
            │
            ▼
    ┌───────────────┐
    │ HELM INSTALL  │
    │ NEW COREDNS   │
    └───────┬───────┘
            │
            ▼
    ┌───────────────┐
    │ WAIT FOR      │
    │ PODS READY    │ ← DNS OUTAGE ENDS
    └───────┬───────┘
            │
            ▼
    ┌───────────────┐
    │ NEW COREDNS   │
    │ SERVING       │
    └───────────────┘

Total Downtime: 5-15 seconds
```

### Production Mode Flow
```
┌─────────────────────────┐
│  OLD CoreDNS            │
│  (serving traffic)      │
└───────────┬─────────────┘
            │
            ├──────────────────────────┐
            │                          │
            ▼                          │
    ┌───────────────┐                 │
    │ DEPLOY NEW    │                 │
    │ (coredns-new) │                 │
    └───────┬───────┘                 │
            │                          │
            ▼                          │
    ┌───────────────┐                 │
    │ VERIFY HEALTH │                 │
    └───────┬───────┘                 │
            │                          │
            ▼                          │
    ┌───────────────┐                 │
    │ TEST DNS      │                 │
    └───────┬───────┘                 │
            │                          │
            ├──────────────────────────┤
            │    BOTH RUNNING          │
            ├──────────────────────────┤
            │                          │
            ▼                          │
    ┌───────────────┐                 │
    │ SWITCH        │                 │
    │ SERVICE       │                 │
    └───────┬───────┘                 │
            │                          │
            │                          ▼
            │                  ┌───────────────┐
            │                  │ DELETE OLD    │
            │                  │ DEPLOYMENT    │
            │                  └───────┬───────┘
            │                          │
            ▼                          ▼
    ┌─────────────────────────────────┐
    │  NEW CoreDNS (renamed)          │
    │  (serving traffic)              │
    └─────────────────────────────────┘

Total Downtime: 0 seconds
```

---

## Troubleshooting

### Development Mode Issues

**Issue: DNS test pods fail immediately after deployment**
```bash
# Wait a bit longer for DNS cache to clear
sleep 10
kubectl run dns-test --image=busybox:1.36 --rm -it -- nslookup kubernetes.default
```

**Issue: Pods stuck in pending**
```bash
# Check for resource constraints
kubectl describe pod -n kube-system -l k8s-app=coredns
```

### Production Mode Issues

**Issue: New deployment fails health check**
- Old deployment keeps running (no outage)
- Fix issue in values.yaml
- Run `./deploy.sh --production` again

**Issue: Service switch doesn't take effect**
```bash
# Manually verify service selector
kubectl get service coredns -n kube-system -o yaml | grep selector -A 3

# Force DNS cache flush in test pod
kubectl run dns-flush --image=busybox:1.36 --rm -it -- sh -c "
  echo 'nameserver 10.96.0.10' > /etc/resolv.conf
  nslookup kubernetes.default
"
```

---

## Performance Considerations

### Development Mode
- **Time to deploy**: ~30 seconds
- **DNS outage**: 5-15 seconds
- **Resource usage**: Normal (1 deployment)

### Production Mode
- **Time to deploy**: 2-3 minutes
- **DNS outage**: 0 seconds
- **Peak resource usage**: Double (2 deployments temporarily)
- **Additional overhead**: Service switching, verification steps

---

## Best Practices

### For Development
1. Use default mode for speed
2. Accept brief DNS disruption
3. Run during off-hours if shared cluster

### For Production
1. **Always** use `--production` flag
2. Monitor both deployments during transition
3. Have rollback plan ready
4. Test in staging first
5. Notify team before deployment
6. Monitor DNS metrics after deployment

### For Both
- Review values.yaml changes before deployment
- Keep backup of working configuration
- Test DNS resolution after deployment
- Check Helm release status
- Verify pod logs for errors

---

## Related Documentation

- [VALIDATION.md](./VALIDATION.md) - Troubleshooting and error fixes
- [README.md](./README.md) - Overview and configuration
- [values.yaml](./values.yaml) - Configuration values
