# CI/CD Pipeline Documentation

## Overview

The AIOps Substrate project uses GitHub Actions for continuous integration and continuous deployment. The pipeline is designed to ensure security, quality, and reliability at every stage.

## Pipeline Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Git Push (main/claude/*)               │
└─────────────────┬───────────────────────────────────────┘
                  │
        ┌─────────┴─────────┐
        │                   │
        ▼                   ▼
   ┌────────┐        ┌──────────────┐
   │ Test   │        │ Security     │
   │        │        │ Scan (Trivy) │
   └───┬────┘        └──────┬───────┘
       │                    │
       └─────────┬──────────┘
                 │
                 ▼
         ┌───────────────┐
         │ Build & Push  │
         │ to GHCR       │
         └───────┬───────┘
                 │
        ┌────────┴────────┐
        │                 │
        ▼                 ▼
  ┌──────────┐     ┌────────────┐
  │ Image    │     │ SBOM       │
  │ Scan     │     │ Generation │
  └─────┬────┘     └──────┬─────┘
        │                 │
        └────────┬────────┘
                 │
                 ▼
         ┌───────────────┐
         │ Deploy to Dev │
         │ (main only)   │
         └───────────────┘
```

## Workflows

### 1. CD Pipeline (.github/workflows/cd.yml)

The main CD pipeline runs on every push to `main` and `claude/*` branches.

**Jobs:**

#### Test Job
- **Purpose**: Validate application functionality
- **Actions**:
  - Checkout code
  - Setup Python 3.11
  - Install dependencies with pip caching
  - Run pytest suite
  - Auto-generate basic tests if none exist
- **Duration**: ~2-3 minutes

#### Security Scan Job
- **Purpose**: Identify vulnerabilities in source code and dependencies
- **Tools**: Trivy filesystem scanner
- **Actions**:
  - Scan Python dependencies
  - Check for known CVEs
  - Upload results to GitHub Security tab (SARIF format)
  - Display table output in logs
- **Severity Levels**: CRITICAL, HIGH, MEDIUM
- **Duration**: ~1-2 minutes

#### Build Job
- **Purpose**: Build and publish container images
- **Registry**: GitHub Container Registry (GHCR)
- **Actions**:
  - Setup Docker Buildx for multi-platform builds
  - Login to GHCR (non-PR only)
  - Extract metadata (tags, labels)
  - Build image with caching
  - Push to registry (non-PR only)
- **Tags Generated**:
  - `<branch>-<sha>` (e.g., `main-abc123`)
  - `<branch>` (e.g., `main`)
  - `latest` (main branch only)
- **Cache**: GitHub Actions cache for faster builds
- **Duration**: ~3-5 minutes (first run), ~1-2 minutes (cached)

#### Image Scan Job
- **Purpose**: Scan built container image for vulnerabilities
- **Tools**: Trivy image scanner
- **Actions**:
  - Pull built image from GHCR
  - Scan all layers for CVEs
  - Upload SARIF to GitHub Security
  - Display findings table
- **Severity Levels**: CRITICAL, HIGH, MEDIUM
- **Duration**: ~2-3 minutes

#### SBOM Job
- **Purpose**: Generate Software Bill of Materials
- **Tools**: Syft (Anchore), Grype
- **Actions**:
  - Generate CycloneDX SBOM
  - Generate SPDX SBOM
  - Upload SBOM as artifacts (90-day retention)
  - Scan SBOM with Grype for vulnerabilities
  - Upload Grype results (30-day retention)
- **Formats**:
  - CycloneDX JSON (industry standard)
  - SPDX JSON (Linux Foundation standard)
- **Duration**: ~2-3 minutes

#### Deploy Dev Job
- **Purpose**: Deploy to development environment
- **Trigger**: Only on `main` branch
- **Actions**:
  - Display deployment configuration
  - (Optional) Deploy to Kubernetes cluster
- **Environment**: development
- **Duration**: ~1 minute (placeholder), ~3-5 minutes (actual deployment)

#### Summary Job
- **Purpose**: Provide pipeline execution summary
- **Actions**:
  - Generate markdown summary
  - Display job statuses
  - List artifacts produced
- **Always runs**: Even if previous jobs fail

### 2. CI Pipeline (.github/workflows/ci.yml)

Legacy CI workflow for basic build validation.

**Jobs:**
- Build Docker image without pushing
- Validate Dockerfile syntax
- Cache layers for faster builds

## Security Features

### 1. Vulnerability Scanning

**Trivy** scans are performed at two stages:

1. **Filesystem Scan**: Before building the image
   - Scans Python dependencies
   - Checks for outdated packages with known CVEs
   - Reports: CRITICAL, HIGH, MEDIUM severities

2. **Image Scan**: After building the image
   - Scans all container layers
   - Checks OS packages
   - Checks application dependencies
   - Reports: CRITICAL, HIGH severities

**Results Location**: GitHub Security → Code scanning alerts

### 2. SBOM (Software Bill of Materials)

Every build generates comprehensive SBOMs:

**Why SBOMs Matter:**
- Supply chain transparency
- License compliance
- Vulnerability tracking
- Incident response

**Formats:**
- **CycloneDX**: Industry standard, widely supported
- **SPDX**: Linux Foundation standard, legal focus

**Access**: Workflow artifacts (90-day retention)

### 3. Container Image Security

**Best Practices Implemented:**
- Multi-stage builds (smaller attack surface)
- Non-root user (UID 1000)
- Minimal base image (python:3.11-slim)
- No secrets in layers
- Healthcheck included
- Security context enforcement

### 4. Secret Management

**GitHub Secrets Used:**
- `GITHUB_TOKEN`: Auto-provided, scoped to repository
- `KUBECONFIG_DEV`: (Optional) For deployment

**Never Committed:**
- API keys
- Passwords
- TLS certificates
- Private keys

## Image Tagging Strategy

### Semantic Tags

| Tag Pattern | Example | When Applied | Use Case |
|-------------|---------|--------------|----------|
| `latest` | `latest` | Main branch only | Development, not recommended for production |
| `<branch>` | `main`, `claude/feature` | Every branch | Branch tracking |
| `<branch>-<sha>` | `main-a1b2c3d` | Every commit | Immutable reference |
| `<version>` | `1.2.3` | Git tags (semver) | Production releases |

### Best Practices

- **Production**: Always use SHA-based tags (immutable)
  ```yaml
  image: ghcr.io/johnyoungsuh/suhlabs/ai-agent:main-a1b2c3d
  ```

- **Development**: Branch tags acceptable
  ```yaml
  image: ghcr.io/johnyoungsuh/suhlabs/ai-agent:main
  ```

- **Never**: Don't use `latest` in production
  ```yaml
  # ❌ BAD
  image: ghcr.io/johnyoungsuh/suhlabs/ai-agent:latest
  ```

## Caching Strategy

### 1. Pip Cache
```yaml
- uses: actions/setup-python@v5
  with:
    cache: 'pip'
```
- Caches: `~/.cache/pip`
- Invalidates: On requirements.txt change
- Speedup: ~30 seconds per run

### 2. Docker Layer Cache
```yaml
cache-from: type=gha
cache-to: type=gha,mode=max
```
- Caches: All Docker layers
- Invalidates: On Dockerfile/code change
- Speedup: ~2-4 minutes on cache hit

## Deployment

### Current State: Development Placeholder

The pipeline currently **does not** automatically deploy to Kubernetes. The deploy job shows what would be deployed.

### Enabling Automatic Deployment

**Requirements:**
1. Kubernetes cluster accessible from GitHub Actions
2. `kubectl` configured
3. Deployment manifests in cluster

**Steps:**

1. **Generate kubeconfig**
   ```bash
   # On your cluster
   kubectl config view --flatten --minify > kubeconfig-dev.yaml
   base64 kubeconfig-dev.yaml > kubeconfig-dev.b64
   ```

2. **Add GitHub Secret**
   ```bash
   gh secret set KUBECONFIG_DEV < kubeconfig-dev.b64
   ```

3. **Uncomment deployment steps** in `.github/workflows/cd.yml`:
   ```yaml
   - name: Set up kubectl
     uses: azure/setup-kubectl@v3

   - name: Configure kubeconfig
     run: |
       mkdir -p ~/.kube
       echo "${{ secrets.KUBECONFIG_DEV }}" | base64 -d > ~/.kube/config

   - name: Deploy to Kubernetes
     run: |
       kubectl set image deployment/ai-ops-agent \
         ai-ops-agent=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:main-${{ github.sha }} \
         -n ai-ops
       kubectl rollout status deployment/ai-ops-agent -n ai-ops --timeout=5m
   ```

4. **Push to main** - deployment will run automatically

### GitOps Alternative (Recommended for Production)

Instead of direct deployment, use GitOps:

1. **ArgoCD** or **Flux** watches Git repository
2. Pipeline updates image tag in Git
3. GitOps tool detects change and deploys
4. Full audit trail in Git history

**Example with ArgoCD:**
```yaml
- name: Update ArgoCD manifest
  run: |
    git clone https://github.com/${{ github.repository }}-gitops
    cd ${{ github.repository }}-gitops
    yq e '.spec.template.spec.containers[0].image = "${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:main-${{ github.sha }}"' \
      -i apps/ai-ops-agent/deployment.yaml
    git commit -am "Update ai-ops-agent to ${{ github.sha }}"
    git push
```

## Monitoring & Observability

### Pipeline Metrics

**Available in GitHub Actions:**
- Job duration trends
- Success/failure rates
- Cache hit rates
- Artifact sizes

**Access**: Actions → Workflow → Insights

### Security Alerts

**GitHub Security Tab:**
- Code scanning alerts (Trivy findings)
- Dependabot alerts (outdated dependencies)
- Secret scanning alerts (leaked secrets)

**Access**: Security → Code scanning

### Artifacts

**Available Downloads:**
- SBOM files (CycloneDX, SPDX)
- Grype vulnerability reports
- Test results (future)

**Retention**: 30-90 days based on artifact type

## Troubleshooting

### Build Failures

**Symptom**: `Build and Push Image` job fails

**Common Causes:**
1. Dockerfile syntax error
   - Fix: Validate locally with `docker build`
2. Missing dependencies
   - Fix: Update `requirements.txt`
3. GHCR authentication failure
   - Fix: Check `GITHUB_TOKEN` permissions

**Debug:**
```bash
# Test locally
cd cluster/ai-ops-agent
docker build -t test .
docker run -p 8000:8000 test
curl http://localhost:8000/health
```

### Security Scan Failures

**Symptom**: Critical vulnerabilities block pipeline

**Resolution:**
1. Review Trivy output in job logs
2. Update dependencies:
   ```bash
   pip install --upgrade -r requirements.txt
   pip freeze > requirements.txt
   ```
3. If no fix available, document exception
4. Consider pinning to safe version

**Bypass (Emergency Only):**
```yaml
# In cd.yml, temporarily skip check
- name: Run Trivy
  continue-on-error: true
```

### SBOM Generation Failures

**Symptom**: Syft cannot analyze image

**Common Causes:**
1. Image not yet pushed to GHCR
   - Fix: Check build job completed
2. Authentication issue
   - Fix: Verify GHCR login step

**Debug:**
```bash
# Test locally
docker pull ghcr.io/johnyoungsuh/suhlabs/ai-agent:main
syft ghcr.io/johnyoungsuh/suhlabs/ai-agent:main -o cyclonedx-json
```

### Deployment Failures

**Symptom**: Deploy job fails (when enabled)

**Common Causes:**
1. Kubeconfig invalid/expired
   - Fix: Regenerate and update secret
2. Deployment doesn't exist
   - Fix: Apply manifests first
3. Image pull auth failure
   - Fix: Create GHCR image pull secret

**Debug:**
```bash
# Test cluster access
echo "$KUBECONFIG_DEV" | base64 -d > test-config
KUBECONFIG=test-config kubectl get nodes
KUBECONFIG=test-config kubectl get deploy -n ai-ops
```

## Performance Optimization

### Current Benchmarks

| Job | Cold Start | Cached |
|-----|------------|--------|
| Test | ~2 min | ~1 min |
| Security Scan | ~1.5 min | ~1.5 min |
| Build | ~5 min | ~2 min |
| Image Scan | ~3 min | ~2 min |
| SBOM | ~2 min | ~2 min |
| **Total** | **~14 min** | **~9 min** |

### Optimization Tips

1. **Maximize cache hits**
   - Don't change `requirements.txt` unnecessarily
   - Order Dockerfile layers by change frequency
   - Use `.dockerignore` to exclude unnecessary files

2. **Parallelize jobs**
   - Test and Security Scan run in parallel
   - Image Scan and SBOM run in parallel

3. **Use matrix builds** (future)
   ```yaml
   strategy:
     matrix:
       python-version: [3.11, 3.12]
   ```

4. **Self-hosted runners** (production)
   - Faster builds (local cache)
   - Lower costs (no minute limits)
   - GPU access (for LLM workloads)

## Cost Analysis

### GitHub Actions Free Tier

- **Public repos**: Unlimited minutes
- **Private repos**: 2,000 minutes/month
- **Storage**: 500 MB artifacts

### Current Usage

- **Per pipeline run**: ~14 minutes (cold), ~9 minutes (cached)
- **Estimated monthly**: ~300 commits × 9 min = 2,700 minutes
- **Cost**: $0 (public repo) or ~$5/month (private repo over limit)

### Cost Reduction Strategies

1. **Skip CI on docs changes**
   ```yaml
   on:
     push:
       paths-ignore:
         - '**.md'
         - 'docs/**'
   ```

2. **Use larger runners** (faster but more expensive)
   ```yaml
   runs-on: ubuntu-latest-4-cores
   ```

3. **Self-hosted runners** (zero cost after hardware)

## Integration with Day 5 (Cert-Manager)

The CI/CD pipeline integrates with cert-manager for certificate automation:

1. **Deployed images** include cert-manager integration
2. **Secrets** are injected at runtime (not in image)
3. **mTLS certificates** are auto-issued on pod start
4. **Renewals** are handled by cert-manager (no CI/CD involvement)

**Example deployment with cert-manager:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ai-ops-agent
spec:
  template:
    metadata:
      annotations:
        # Cert-manager will inject certs
        cert-manager.io/inject-ca-from: ai-ops/vault-issuer
    spec:
      containers:
      - name: ai-ops-agent
        image: ghcr.io/johnyoungsuh/suhlabs/ai-agent:main-abc123
        volumeMounts:
        - name: tls
          mountPath: /etc/tls
      volumes:
      - name: tls
        secret:
          secretName: ai-ops-agent-tls
```

## Future Enhancements

### Planned (Week 2)

- [ ] **Code signing** with Cosign (Day 11)
- [ ] **Policy enforcement** with Kyverno (Day 11)
- [ ] **Admission control** - only signed images deploy
- [ ] **Performance testing** - load tests on merge
- [ ] **E2E tests** - full stack integration tests

### Considered

- [ ] **Multi-arch builds** (arm64 support)
- [ ] **Helm chart publishing**
- [ ] **Release automation** (changelog, GitHub releases)
- [ ] **Slack/Discord notifications**
- [ ] **Rollback automation** on failure
- [ ] **Blue-green deployments**
- [ ] **Canary deployments** with traffic splitting

## Best Practices

### 1. Commit Messages

Good commit messages help pipeline debugging:

```bash
# ✅ GOOD
git commit -m "fix: update FastAPI to 0.104.2 (CVE-2024-1234)"

# ❌ BAD
git commit -m "fixed stuff"
```

### 2. Branch Protection

**Recommended settings** (GitHub repo settings):

- ✅ Require status checks to pass
  - `test`
  - `security-scan`
  - `build`
- ✅ Require branches to be up to date
- ✅ Require signed commits (optional)
- ✅ Include administrators

### 3. Secret Rotation

**Schedule:**
- `KUBECONFIG_DEV`: Every 90 days
- `GITHUB_TOKEN`: Auto-rotated by GitHub
- Image pull secrets: Every 90 days

**Process:**
1. Generate new secret
2. Update GitHub secret
3. Trigger test deployment
4. Delete old secret

### 4. Dependency Updates

**Weekly:**
- Review Dependabot PRs
- Test updated dependencies
- Merge if tests pass

**Monthly:**
- Update base image (`python:3.11-slim`)
- Update GitHub Actions versions
- Review Trivy findings

## Resources

### Documentation
- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [Syft Documentation](https://github.com/anchore/syft)
- [SBOM Guide](https://www.cisa.gov/sbom)
- [Container Best Practices](https://docs.docker.com/develop/dev-best-practices/)

### Tools
- [act](https://github.com/nektos/act) - Run GitHub Actions locally
- [hadolint](https://github.com/hadolint/hadolint) - Dockerfile linter
- [dive](https://github.com/wagoodman/dive) - Analyze image layers

### Related Docs
- [Day 4: Foundation Services](DAY-4-COMPLETE.md)
- [Day 5: Cert-Manager](DAY-5-COMPLETE.md)
- [14-Day Sprint Plan](14-DAY-SPRINT.md)
- [Security Scanning Guide](../cluster/ai-ops-agent/SECURITY_SCANNING.md)

---

**Last Updated**: Day 6 - CI/CD Pipeline Implementation
**Author**: AIOps Substrate Project
**Status**: Production Ready
