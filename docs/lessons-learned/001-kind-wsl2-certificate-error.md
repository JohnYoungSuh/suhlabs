# Lesson Learned: kind Certificate Validation Error in WSL2

## Issue Date
2025-11-07

## Summary
kind cluster creation in WSL2 environment results in TLS certificate validation errors when kubectl attempts to connect to the API server.

## Error Message
```
Unable to connect to the server: tls: failed to verify certificate:
x509: certificate is valid for 10.96.0.1, 172.20.0.4, 127.0.0.1, not 0.0.0.0
```

## Root Cause Analysis

### What Happened
1. kind creates a Kubernetes cluster in Docker containers
2. kind generates TLS certificates for the API server
3. kind auto-generates a kubeconfig file
4. **In WSL2**, kind incorrectly sets the API server URL to `https://0.0.0.0:6443`
5. kubectl tries to connect to `0.0.0.0`
6. The TLS certificate is only valid for: `10.96.0.1` (service), `172.20.0.4` (Docker bridge), `127.0.0.1` (loopback)
7. Certificate validation fails because `0.0.0.0` is not in the cert's SAN (Subject Alternative Names)

### Why It Happened

**WSL2-Specific Networking Issue**:
- WSL2 has a virtual network bridge between Windows and Linux
- Docker Desktop in WSL2 has special networking configurations
- kind's automatic API server address detection gets confused
- Defaults to `0.0.0.0` instead of `127.0.0.1`

### Certificate Details

When kind creates the cluster:
```bash
# Certificate is generated with these SANs:
# - 10.96.0.1      (Kubernetes service ClusterIP)
# - 172.20.0.4     (Docker bridge IP)
# - 127.0.0.1      (Loopback)
# - NOT 0.0.0.0    (All interfaces - not in cert!)
```

The kubeconfig generated:
```yaml
clusters:
- cluster:
    server: https://0.0.0.0:6443  # ❌ This is wrong!
  name: kind-aiops-dev
```

Should be:
```yaml
clusters:
- cluster:
    server: https://127.0.0.1:6443  # ✅ This is correct!
  name: kind-aiops-dev
```

## Impact

- **Severity**: High (blocks cluster usage)
- **Scope**: All kubectl commands fail
- **Environment**: WSL2 + Docker Desktop + kind
- **Workaround Time**: 5-10 minutes (if you know the fix)
- **Learning Value**: High (understanding PKI, certificates, SANs)

## Solutions

### Solution 1: Prevent the Issue (RECOMMENDED)

Update `bootstrap/kind-cluster.yaml` to explicitly set API server address:

```yaml
networking:
  # Explicitly set API server address for WSL2 compatibility
  apiServerAddress: "127.0.0.1"
  apiServerPort: 6443
  # ... rest of config
```

Then recreate the cluster:
```bash
make kind-down
make kind-up
```

### Solution 2: Fix Existing Cluster (Quick Fix)

Update the kubeconfig to point to the correct address:

```bash
# Check current server URL
kubectl config view --minify --context kind-aiops-dev

# Fix it
kubectl config set-cluster kind-aiops-dev --server=https://127.0.0.1:6443

# Test
kubectl get nodes
```

### Solution 3: Complete Cluster Recreation

Delete and recreate with correct configuration:

```bash
# Delete broken cluster
kind delete cluster --name aiops-dev

# Recreate with fixed config
make kind-up
```

## Verification

After applying the fix, verify:

```bash
# 1. Check kubeconfig has correct server URL
kubectl config view --minify --context kind-aiops-dev -o jsonpath='{.clusters[0].cluster.server}'
# Should output: https://127.0.0.1:6443

# 2. Test connection
kubectl cluster-info --context kind-aiops-dev
# Should succeed without cert errors

# 3. Check nodes
kubectl get nodes
# Should list 3 nodes

# 4. Check certificates (advanced)
openssl s_client -connect 127.0.0.1:6443 -showcerts 2>&1 | grep -A2 "Subject Alternative Name"
# Should show: DNS:kubernetes, DNS:kubernetes.default, IP:10.96.0.1, IP:127.0.0.1
```

## Technical Deep Dive

### Understanding x509 Certificate Validation

1. **Subject Alternative Names (SANs)**:
   - Modern certificates use SANs instead of CN (Common Name)
   - SANs list all valid hostnames/IPs for the certificate
   - Client must connect to an address in the SAN list

2. **Why `0.0.0.0` Fails**:
   - `0.0.0.0` means "bind to all interfaces" (server-side concept)
   - It's not a routable address (client-side)
   - Certificate can't be valid for "all interfaces"
   - Clients should use specific IPs (127.0.0.1, actual IP, etc.)

3. **Certificate Generation in kind**:
   ```bash
   # kind generates certs with:
   - Service ClusterIP (10.96.0.1)
   - Docker bridge IP (172.20.0.x)
   - Loopback (127.0.0.1)
   - NOT 0.0.0.0 (invalid for certificates)
   ```

### WSL2 Networking Context

```
┌─────────────────────────────────────────┐
│           Windows Host                  │
│  Docker Desktop                         │
│    └─> WSL2 Backend                     │
│         └─> kind cluster (containers)   │
│              ├─> Control plane          │
│              │    API: 0.0.0.0:6443 ❌  │
│              │    Should be: 127.0.0.1  │
│              └─> Workers                │
└─────────────────────────────────────────┘
```

## Prevention for Future

### In Makefile
The enhanced `make kind-up` now:
1. Checks for existing clusters
2. Auto-deletes stale clusters (prevents cert mismatches)
3. Creates cluster with explicit API server address
4. Validates connectivity before declaring success

### In CI/CD
If automating cluster creation:
```bash
# Always specify apiServerAddress in kind config
cat > kind-config.yaml <<EOF
networking:
  apiServerAddress: "127.0.0.1"
  apiServerPort: 6443
EOF

kind create cluster --config kind-config.yaml
```

## Related Issues

- [kind issue #1558](https://github.com/kubernetes-sigs/kind/issues/1558): WSL2 networking
- [kind docs](https://kind.sigs.k8s.io/docs/user/known-issues/#wsl2): WSL2 known issues

## Key Takeaways

1. **Always explicitly set `apiServerAddress` in kind configs for WSL2**
2. **Certificate SANs must match the connection address**
3. **`0.0.0.0` is not a valid client connection address**
4. **WSL2 networking requires special attention**
5. **Auto-cleanup of stale clusters prevents cert mismatches**

## Testing Checklist

When deploying to new environments:

- [ ] Verify `apiServerAddress: "127.0.0.1"` in kind config
- [ ] Test: `kubectl config view --minify` shows `127.0.0.1`
- [ ] Test: `kubectl cluster-info` succeeds
- [ ] Test: `kubectl get nodes` succeeds
- [ ] Document: Save working kind config for future use

## References

- kind Documentation: https://kind.sigs.k8s.io/
- Kubernetes TLS: https://kubernetes.io/docs/concepts/security/
- x509 Certificates: https://datatracker.ietf.org/doc/html/rfc5280

---

**Author**: Infrastructure Team
**Reviewers**: DevOps Team
**Status**: Resolved
**Environment**: WSL2 + Docker Desktop + kind
**Related Tickets**: HOMELAB-3
