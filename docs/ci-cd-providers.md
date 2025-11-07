# CI/CD Provider Guide - Platform-Agnostic Workflows

**Version:** 1.0
**Last Updated:** 2025-11-07
**Purpose:** Guide for switching between CI/CD providers without rewriting logic

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Supported Providers](#supported-providers)
4. [Quick Start by Provider](#quick-start-by-provider)
5. [Migration Guide](#migration-guide)
6. [Comparison Matrix](#comparison-matrix)
7. [Best Practices](#best-practices)
8. [Troubleshooting](#troubleshooting)

---

## Overview

### The Problem

Traditional CI/CD configurations lock you into a specific provider:
- GitHub Actions uses YAML with GitHub-specific syntax
- GitLab CI uses different YAML structure
- Jenkins uses Groovy/Declarative syntax
- Tekton uses Kubernetes CRDs

**Switching providers = rewriting all CI/CD logic** 😱

### Our Solution: Platform-Agnostic Design

```
┌─────────────────────────────────────────────────────────────┐
│  ALL LOGIC IN MAKEFILE (Universal)                          │
│  make lint, make test, make security, make build            │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│  CI/CD Provider (Thin Wrapper - Pluggable)                  │
│                                                               │
│  GitHub Actions:  - run: make ci-pr                         │
│  GitLab CI:       script: make ci-pr                        │
│  Jenkins:         sh 'make ci-pr'                           │
│  Tekton:          script: |                                 │
│                     make ci-pr                              │
└─────────────────────────────────────────────────────────────┘
```

**Benefits:**
- ✅ Switch providers in < 1 day
- ✅ Test locally exactly as CI does (`make ci-pr`)
- ✅ No vendor lock-in
- ✅ All logic version controlled in Makefile
- ✅ Easy to debug (run `make` commands locally)

---

## Architecture

### Layer 1: Makefile (Universal Logic)

All CI/CD logic lives in the Makefile:

```makefile
# Platform-agnostic targets
ci-lint: doctor lint           # Lint all code
ci-test: doctor test           # Run all tests
ci-security: doctor security   # Run security scans
ci-build: doctor build         # Build artifacts
ci-pr: ci-lint ci-test ci-security  # Full PR validation
ci-main: ci-pr ci-build        # Full main branch workflow
```

### Layer 2: CI/CD Wrappers (Provider-Specific)

Each provider has a thin wrapper that calls the Makefile:

```yaml
# GitHub Actions (.github/workflows/pr-validation.yml)
- run: make ci-pr

# GitLab CI (.gitlab-ci.yml)
script:
  - make ci-pr

# Jenkins (Jenkinsfile)
sh 'make ci-pr'

# Tekton (.tekton/pipeline.yaml)
script: |
  make ci-pr
```

---

## Supported Providers

| Provider | Config File | Status | Migration Time |
|----------|-------------|--------|----------------|
| **GitHub Actions** | `.github/workflows/pr-validation.yml` | ✅ Ready | N/A |
| **GitLab CI** | `.gitlab-ci.yml` | ✅ Ready | < 1 hour |
| **Jenkins** | `Jenkinsfile` | ✅ Ready | < 2 hours |
| **Tekton** | `.tekton/pipeline.yaml` | ✅ Ready | < 3 hours |
| **Drone** | `.drone.yml` | 📝 Template available | < 1 hour |
| **CircleCI** | `.circleci/config.yml` | 📝 Template available | < 1 hour |
| **Azure Pipelines** | `azure-pipelines.yml` | 📝 Template available | < 2 hours |

---

## Quick Start by Provider

### GitHub Actions

**File:** `.github/workflows/pr-validation.yml`

**Setup:**
```bash
# Already configured! Just push to GitHub.
git push origin your-branch
```

**Key Features:**
- ✅ Automatic PR validation
- ✅ Code coverage upload to Codecov
- ✅ Security scanning with Trivy
- ✅ SBOM generation
- ✅ Artifact archiving

**Test Locally:**
```bash
# Run the same checks CI will run
make ci-pr

# Run individual stages
make ci-lint
make ci-test
make ci-security
```

---

### GitLab CI

**File:** `.gitlab-ci.yml`

**Setup:**
```bash
# Push to GitLab repository
git remote add gitlab git@gitlab.com:yourorg/aiops-substrate.git
git push gitlab main
```

**Key Features:**
- ✅ Parallel job execution
- ✅ Coverage reporting
- ✅ Security dashboard integration
- ✅ Container scanning
- ✅ SAST (if GitLab Ultimate)

**Test Locally:**
```bash
# Same as GitHub Actions!
make ci-pr

# Or use GitLab Runner locally
gitlab-runner exec docker lint:all
```

**Variables to Configure:**
```yaml
# In GitLab Project Settings → CI/CD → Variables
PROXMOX_API_TOKEN: <your-token>
VAULT_TOKEN: <your-token>
REGISTRY_USER: <your-registry-user>
REGISTRY_PASSWORD: <your-registry-password>
```

---

### Jenkins

**File:** `Jenkinsfile`

**Setup:**

1. **Create Jenkins Pipeline Job:**
   ```
   New Item → Pipeline → aiops-substrate
   Pipeline from SCM → Git
   Script Path: Jenkinsfile
   ```

2. **Configure Credentials:**
   ```
   Manage Jenkins → Credentials
   Add: proxmox-api-token (Secret text)
   Add: vault-root-token (Secret text)
   ```

3. **Install Required Plugins:**
   ```
   - Docker Pipeline
   - Pipeline
   - Git
   - JUnit
   - HTML Publisher (for coverage reports)
   ```

**Key Features:**
- ✅ Parallel stage execution
- ✅ Manual approval for deployments
- ✅ Build artifacts archiving
- ✅ Test results publishing
- ✅ Coverage reports

**Test Locally:**
```bash
# Same as other providers!
make ci-pr

# Or use Jenkins X for local testing
jx pipeline start
```

---

### Tekton (Kubernetes-Native)

**File:** `.tekton/pipeline.yaml`

**Setup:**

1. **Install Tekton on Kubernetes:**
   ```bash
   # Install Tekton Pipelines
   kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml

   # Install Tekton Triggers (optional)
   kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml

   # Install Tekton Dashboard (optional)
   kubectl apply -f https://storage.googleapis.com/tekton-releases/dashboard/latest/release.yaml
   ```

2. **Apply Pipeline:**
   ```bash
   kubectl apply -f .tekton/pipeline.yaml
   ```

3. **Create PipelineRun:**
   ```bash
   kubectl create -f - <<EOF
   apiVersion: tekton.dev/v1beta1
   kind: PipelineRun
   metadata:
     generateName: aiops-substrate-run-
     namespace: tekton-pipelines
   spec:
     pipelineRef:
       name: aiops-substrate-pipeline
     params:
       - name: repo-url
         value: https://github.com/yourorg/aiops-substrate.git
       - name: revision
         value: main
     workspaces:
       - name: source-code
         volumeClaimTemplate:
           spec:
             accessModes: [ReadWriteOnce]
             resources:
               requests:
                 storage: 1Gi
   EOF
   ```

**Key Features:**
- ✅ Kubernetes-native
- ✅ Cloud-agnostic (runs anywhere k8s runs)
- ✅ Reusable tasks
- ✅ Event-driven triggers
- ✅ Multi-cloud support

**Test Locally:**
```bash
# Same Makefile!
make ci-pr

# Or use tkn CLI
tkn pipeline start aiops-substrate-pipeline
tkn pipelinerun logs -f
```

---

## Migration Guide

### Scenario 1: GitHub → GitLab

**Time:** < 1 hour

**Steps:**

1. **Push `.gitlab-ci.yml` to GitLab:**
   ```bash
   git remote add gitlab git@gitlab.com:yourorg/aiops-substrate.git
   git push gitlab main
   ```

2. **Configure Variables in GitLab:**
   - Go to Project Settings → CI/CD → Variables
   - Add required secrets (Proxmox tokens, etc.)

3. **Test:**
   ```bash
   # Trigger pipeline
   git commit --allow-empty -m "Test GitLab CI"
   git push gitlab main
   ```

4. **Done!** Your Makefile logic works identically.

---

### Scenario 2: GitLab → Jenkins

**Time:** < 2 hours

**Steps:**

1. **Create Jenkins Pipeline:**
   - New Item → Pipeline
   - SCM: Git → Your repo URL
   - Script Path: `Jenkinsfile`

2. **Add Credentials:**
   - Manage Jenkins → Credentials
   - Add required secrets

3. **Install Plugins:**
   ```
   - Docker Pipeline
   - Pipeline
   - Git
   ```

4. **Test:**
   - Build Now
   - Check console output

5. **Done!** Same Makefile, different wrapper.

---

### Scenario 3: Any Provider → Tekton (Kubernetes)

**Time:** < 3 hours

**Steps:**

1. **Install Tekton on your Kubernetes cluster:**
   ```bash
   kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
   ```

2. **Apply your pipeline:**
   ```bash
   kubectl apply -f .tekton/pipeline.yaml
   ```

3. **Create PipelineRun:**
   ```bash
   kubectl create -f .tekton/pipelinerun-example.yaml
   ```

4. **Monitor:**
   ```bash
   tkn pipelinerun logs -f -n tekton-pipelines
   ```

5. **Done!** Kubernetes-native CI/CD with same Makefile logic.

---

## Comparison Matrix

### Feature Comparison

| Feature | GitHub Actions | GitLab CI | Jenkins | Tekton |
|---------|---------------|-----------|---------|--------|
| **Hosted Option** | ✅ Yes (GitHub.com) | ✅ Yes (GitLab.com) | ❌ Self-host only | ❌ Self-host only |
| **Self-Hosted** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes (Kubernetes) |
| **Parallel Execution** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes |
| **Matrix Builds** | ✅ Yes | ✅ Yes | ✅ Yes (plugins) | ✅ Yes |
| **Artifacts** | ✅ Built-in | ✅ Built-in | ✅ Built-in | ✅ PVC/S3 |
| **Secret Management** | ✅ Built-in | ✅ Built-in | ✅ Built-in | ✅ Kubernetes Secrets |
| **Docker Support** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Native |
| **Cost (Hosted)** | Free for public, $$ private | Free tier, $$ after | N/A | N/A |
| **Kubernetes-Native** | ❌ No | ❌ No | ❌ No | ✅ Yes |
| **Learning Curve** | Low | Low | Medium | High |

### Performance Comparison

**Test:** Full PR validation (lint + test + security)

| Provider | Cold Start | Warm Start | Parallel | Notes |
|----------|------------|------------|----------|-------|
| **GitHub Actions** | ~3 min | ~1.5 min | ✅ Yes | Fast, good caching |
| **GitLab CI** | ~3.5 min | ~1.5 min | ✅ Yes | Comparable to GitHub |
| **Jenkins** | ~2 min | ~1 min | ✅ Yes | Fast if self-hosted |
| **Tekton** | ~4 min | ~2 min | ✅ Yes | Overhead from k8s pods |

### Cost Comparison (Monthly)

**Assumptions:** 5 developers, 100 builds/month, self-hosted where applicable

| Provider | Hosted Option | Self-Hosted | Notes |
|----------|--------------|-------------|-------|
| **GitHub Actions** | $0-200/month | Free (+ runner costs) | 2,000 min/month free (public) |
| **GitLab CI** | $0-99/month | Free (+ runner costs) | 400 min/month free tier |
| **Jenkins** | N/A | Free (+ server costs) | Server: $50-100/month (AWS t3.medium) |
| **Tekton** | N/A | Free (+ k8s costs) | K8s cluster: $100-200/month |

**Winner:** Jenkins (self-hosted) or GitLab CI (free tier) for small teams.

---

## Best Practices

### 1. Keep CI/CD Wrappers Thin

**❌ BAD (Logic in CI/CD):**
```yaml
# .github/workflows/bad.yml
- name: Lint Terraform
  run: terraform fmt -check -recursive
- name: Lint Ansible
  run: ansible-lint ansible/
- name: Lint Python
  run: flake8 tests/
```

**✅ GOOD (Logic in Makefile):**
```yaml
# .github/workflows/good.yml
- name: Lint All
  run: make ci-lint
```

### 2. Test Locally Before Pushing

```bash
# Always run this before pushing
make ci-pr

# If it passes locally, it'll pass in CI
```

### 3. Use Environment Variables for Configuration

```makefile
# Makefile - platform-agnostic
CONTAINER_RUNTIME ?= docker  # Can be overridden
ENV ?= local
```

```yaml
# GitHub Actions - override if needed
env:
  CONTAINER_RUNTIME: podman
```

### 4. Document Provider-Specific Requirements

```markdown
# In your CI/CD config
# Required secrets:
# - PROXMOX_API_TOKEN
# - VAULT_TOKEN
# - REGISTRY_PASSWORD
```

### 5. Version Your CI/CD Configs

```bash
git add .github/workflows/ .gitlab-ci.yml Jenkinsfile .tekton/
git commit -m "chore: update CI/CD configs to v3.0"
```

---

## Troubleshooting

### Issue: "make: command not found"

**Solution:** Install make in your CI environment.

```yaml
# GitHub Actions / GitLab CI
before_script:
  - apt-get update && apt-get install -y make
```

```groovy
// Jenkinsfile
sh 'apk add make'  // Alpine
sh 'yum install -y make'  // CentOS/RHEL
```

### Issue: "docker: command not found"

**Solution:** Use CONTAINER_RUNTIME variable.

```bash
# Test with different runtime
make CONTAINER_RUNTIME=podman ci-pr
```

```yaml
# CI config
env:
  CONTAINER_RUNTIME: podman
```

### Issue: Tests pass locally but fail in CI

**Possible Causes:**
1. **Different environment:** Check `make doctor` output
2. **Missing dependencies:** Review `requirements-dev.txt`
3. **Timing issues:** Increase timeouts in `pytest.ini`
4. **Network restrictions:** Some CI environments block external calls

**Debug Steps:**
```bash
# 1. Check what CI sees
make doctor

# 2. Run exact same command as CI
make ci-pr

# 3. Enable verbose output
make ci-pr VERBOSE=1
```

### Issue: CI takes too long

**Solutions:**

1. **Enable caching:**
   ```yaml
   # GitHub Actions
   - uses: actions/cache@v3
     with:
       path: ~/.cache/pip
       key: ${{ runner.os }}-pip-${{ hashFiles('**/requirements-dev.txt') }}
   ```

2. **Run tests in parallel:**
   ```bash
   # In Makefile
   test-unit:
       pytest -n auto  # Use all CPU cores
   ```

3. **Skip slow tests in PR:**
   ```bash
   pytest -m "not slow"
   ```

---

## Examples

### Example 1: Switching from GitHub to GitLab

**Before (GitHub Actions only):**
```yaml
# .github/workflows/ci.yml
jobs:
  test:
    steps:
      - run: terraform fmt -check
      - run: ansible-lint
      - run: pytest tests/
```

**After (Platform-agnostic):**

```makefile
# Makefile
ci-pr:
    terraform fmt -check
    ansible-lint
    pytest tests/
```

```yaml
# .github/workflows/ci.yml
jobs:
  test:
    steps:
      - run: make ci-pr

# .gitlab-ci.yml
test:
  script:
    - make ci-pr
```

**Result:** Now works on both platforms!

---

### Example 2: Local Development Matches CI

```bash
# Developer workflow
git checkout -b feature/new-thing
# ... make changes ...
make ci-pr  # Run EXACT same checks as CI
git push origin feature/new-thing
# PR automatically validated with same logic
```

---

## Resources

### Documentation
- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [GitLab CI Docs](https://docs.gitlab.com/ee/ci/)
- [Jenkins Pipeline Docs](https://www.jenkins.io/doc/book/pipeline/)
- [Tekton Docs](https://tekton.dev/docs/)

### Tools
- [act](https://github.com/nektos/act) - Run GitHub Actions locally
- [GitLab Runner](https://docs.gitlab.com/runner/) - Run GitLab CI locally
- [Jenkins X](https://jenkins-x.io/) - Kubernetes-native Jenkins
- [tkn CLI](https://tekton.dev/docs/cli/) - Tekton CLI

### Related Documentation
- `../workflow-pattern-analysis.md` - Platform dependency analysis
- `../README.md` - Project overview
- `../Makefile` - All CI/CD logic

---

## Summary

**Key Takeaway:** By putting all logic in the Makefile, switching CI/CD providers becomes trivial. You're never locked into a single vendor.

**Next Steps:**
1. ✅ Read this guide
2. ✅ Test locally: `make ci-pr`
3. ✅ Push to your preferred CI provider
4. ✅ Profit! 🎉

**Questions?** Open an issue or see `workflow-pattern-analysis.md` for deeper analysis.

---

**Last Updated:** 2025-11-07
**Version:** 1.0
**Maintainers:** Infrastructure Team
