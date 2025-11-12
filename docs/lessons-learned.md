# Lessons Learned - DevSecOps Sprint

## Day 1: Kubernetes Deployment Issues

### Issue: ImagePullBackOff Error
**Date:** 2025-11-10
**Severity:** 🟡 Medium - Blocks deployments

---

### Problem
```bash
kubectl get pods
# Output:
NAME                    READY   STATUS             RESTARTS   AGE
nginx-c95765fd4-kmqzg   0/1     ImagePullBackOff   0          4m52s
```

Pod stuck in `ImagePullBackOff` state when deploying nginx.

---

### Root Cause
Kubernetes cannot pull container images from Docker Hub due to:
1. **Network connectivity issues** - Docker Desktop can't reach external registries
2. **Docker Hub rate limits** - Anonymous pulls limited to 100/6hrs
3. **Corporate proxy/firewall** - Blocking container registry access
4. **Docker daemon not authenticated** - No Docker Hub login

---

### Solution

#### Step 1: Verify Network Connectivity
```bash
# Test Docker Hub connectivity
curl -I https://hub.docker.com
# Should return: HTTP/2 200

# Test registry API
curl -I https://registry-1.docker.io
# Should return: HTTP/1.1 401 Unauthorized (expected - means it's reachable)
```

#### Step 2: Pre-pull Images Manually
```bash
# Pull image to local Docker cache BEFORE deploying to K8s
docker pull nginx:latest

# Verify image exists locally
docker images | grep nginx
```

#### Step 3: Deploy to Kubernetes
```bash
# Now deploy - K8s will use locally cached image
kubectl create deployment nginx --image=nginx:latest

# Watch it come up
kubectl get pods -w
```

#### Step 4: Check Pod Events (Debug)
```bash
# If still failing, check events
kubectl describe pod <pod-name>

# Look for ImagePullBackOff details in Events section
# Common errors:
# - "dial tcp: i/o timeout" = Network issue
# - "429 Too Many Requests" = Rate limit hit
# - "unauthorized" = Need Docker Hub login
```

---

### Prevention Strategies

#### 1. Always Pre-pull Critical Images
```bash
# Add to daily workflow
docker pull nginx:latest
docker pull ollama/ollama:latest
docker pull postgres:15
docker pull vault:1.15
```

#### 2. Use Image Pull Secrets (Production)
```bash
# Login to Docker Hub
docker login

# Create K8s secret from Docker config
kubectl create secret generic regcred \
  --from-file=.dockerconfigjson=$HOME/.docker/config.json \
  --type=kubernetes.io/dockerconfigjson

# Use in deployment
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      imagePullSecrets:
      - name: regcred
```

#### 3. Use Local Registry (Air-gapped Environments)
```bash
# Run local registry
docker run -d -p 5000:5000 --name registry registry:2

# Tag and push images
docker tag nginx:latest localhost:5000/nginx:latest
docker push localhost:5000/nginx:latest

# Deploy from local registry
kubectl create deployment nginx --image=localhost:5000/nginx:latest
```

#### 4. Pin Image Versions (Avoid :latest)
```bash
# BAD: :latest can change, causes pull every time
kubectl create deployment nginx --image=nginx:latest

# GOOD: Specific version, K8s uses cached image if available
kubectl create deployment nginx --image=nginx:1.25.3
```

---

### Verification
```bash
# Successful deployment looks like:
kubectl get pods
NAME                    READY   STATUS    RESTARTS   AGE
nginx-c95765fd4-kmqzg   1/1     Running   0          30s

# Check image pull policy
kubectl get deployment nginx -o yaml | grep imagePullPolicy
# Output: imagePullPolicy: IfNotPresent  (uses cache if available)
```

---

### Key Takeaways

1. **Always check network connectivity BEFORE deploying**
   - `curl -I https://registry-1.docker.io`
   - `docker pull <image>` to test

2. **Pre-pull images in local dev**
   - Faster deployments
   - Works offline
   - Avoids rate limits

3. **Use specific image tags, not :latest**
   - Reproducible builds
   - Faster pulls (cached)
   - No surprises in production

4. **Monitor Docker Hub rate limits**
   - Anonymous: 100 pulls/6hrs per IP
   - Authenticated: 200 pulls/6hrs per account
   - Pro: Unlimited

5. **k9s is already showing pods**
   - No need to type `:pods` when you're in pod view
   - Use `:svc`, `:deploy`, `:ns` to switch views
   - `l` for logs, `d` for describe, `s` for shell

---

### Related Issues
- None yet (Day 1)

---

### References
- [Kubernetes ImagePullBackOff Debugging](https://kubernetes.io/docs/concepts/containers/images/#imagepullbackoff)
- [Docker Hub Rate Limits](https://docs.docker.com/docker-hub/download-rate-limit/)
- [k9s Documentation](https://k9scli.io/)

---

### Next Steps
- [ ] Set up Docker Hub authentication for higher rate limits
- [ ] Create local registry for air-gapped testing
- [ ] Document all required images for suhlabs project
- [ ] Add image pre-pull to Makefile targets
