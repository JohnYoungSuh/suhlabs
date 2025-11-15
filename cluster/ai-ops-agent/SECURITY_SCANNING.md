# IaC Security & Compliance Scanning

This document describes the security and compliance scanning setup for ai-ops-agent Kubernetes manifests.

## Overview

We use multiple complementary tools to ensure security, compliance, and best practices:

| Tool | Purpose | What It Checks |
|------|---------|----------------|
| **checkov** | Security & compliance | CIS benchmarks, security policies, misconfigurations |
| **kubeval** | YAML validation | Kubernetes API schema validation |
| **kube-score** | Best practices | Production readiness, reliability, security |
| **kubesec** | Security risks | Security scoring with actionable recommendations |
| **conftest** | Policy enforcement | Custom OPA policies (Rego) |
| **yamllint** | Syntax validation | YAML formatting and syntax |

## Quick Start

```bash
# Run all scans
./scan.sh

# Install all scanning tools (Ubuntu/Debian)
./install-scanners.sh

# Run specific tool
checkov -d ./k8s --framework kubernetes
kubeval k8s/*.yaml
kube-score score k8s/*.yaml
kubesec scan k8s/deployment.yaml
conftest test k8s/ --policy ./policies
yamllint k8s/*.yaml
```

## Tool Details

### 1. Checkov - Security & Compliance

**What it checks:**
- CIS Kubernetes benchmarks
- Container security (privileged mode, capabilities, etc.)
- Resource limits and requests
- Security contexts
- Network policies
- Secret management
- Image scanning best practices

**Installation:**
```bash
pip3 install checkov
```

**Usage:**
```bash
# Scan Kubernetes manifests
checkov -d ./k8s --framework kubernetes

# Scan with specific checks
checkov -d ./k8s --framework kubernetes --check CKV_K8S_8,CKV_K8S_9

# Skip specific checks
checkov -d ./k8s --framework kubernetes --skip-check CKV_K8S_20

# Output formats
checkov -d ./k8s --framework kubernetes --output json
checkov -d ./k8s --framework kubernetes --output sarif
```

**Key Checks:**
- CKV_K8S_8: Liveness probe defined
- CKV_K8S_9: Readiness probe defined
- CKV_K8S_10: CPU requests defined
- CKV_K8S_11: CPU limits defined
- CKV_K8S_12: Memory requests defined
- CKV_K8S_13: Memory limits defined
- CKV_K8S_14: Image tag not latest
- CKV_K8S_20: Containers not privileged
- CKV_K8S_21: Default namespace not used
- CKV_K8S_22: Read-only root filesystem
- CKV_K8S_23: runAsNonRoot enabled
- CKV_K8S_28: Drop ALL capabilities
- CKV_K8S_37: Minimize capabilities

### 2. kubeval - Kubernetes YAML Validation

**What it checks:**
- Valid Kubernetes API schema
- Correct resource versions
- Required fields present
- Field types correct

**Installation:**
```bash
wget https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64.tar.gz
tar xf kubeval-linux-amd64.tar.gz
sudo mv kubeval /usr/local/bin
```

**Usage:**
```bash
# Validate all manifests
kubeval k8s/*.yaml

# Strict mode (fail on warnings)
kubeval --strict k8s/*.yaml

# Specific Kubernetes version
kubeval --kubernetes-version 1.28.0 k8s/*.yaml

# Ignore missing schemas
kubeval --ignore-missing-schemas k8s/*.yaml
```

### 3. kube-score - Best Practices

**What it checks:**
- Pod security standards
- Container image tags
- Resource requests/limits
- Health checks (probes)
- Network policies
- Service configuration
- Deployment strategy
- Security contexts

**Installation:**
```bash
wget https://github.com/zegl/kube-score/releases/latest/download/kube-score_linux_amd64
chmod +x kube-score_linux_amd64
sudo mv kube-score_linux_amd64 /usr/local/bin/kube-score
```

**Usage:**
```bash
# Score manifests
kube-score score k8s/*.yaml

# CI-friendly output
kube-score score k8s/*.yaml --output-format ci

# Ignore specific tests
kube-score score k8s/*.yaml --ignore-test pod-networkpolicy

# Set exit code threshold
kube-score score k8s/*.yaml --exit-one-on-warning
```

### 4. kubesec - Security Risk Analysis

**What it checks:**
- Security contexts
- Capabilities
- Host namespaces
- Privilege escalation
- Service account tokens
- AppArmor/SELinux profiles
- Read-only root filesystem
- RunAsNonRoot

**Installation:**
```bash
wget https://github.com/controlplaneio/kubesec/releases/latest/download/kubesec_linux_amd64
chmod +x kubesec_linux_amd64
sudo mv kubesec_linux_amd64 /usr/local/bin/kubesec
```

**Usage:**
```bash
# Scan deployment
kubesec scan k8s/deployment.yaml

# Get JSON output
kubesec scan k8s/deployment.yaml | jq

# Check score (higher is better, minimum 5)
kubesec scan k8s/deployment.yaml | jq '.[0].score'

# HTTP API mode
kubesec http 8080 &
curl -X POST --data-binary @k8s/deployment.yaml http://localhost:8080/scan
```

**Score Interpretation:**
- Score < 0: Critical issues, immediate action required
- Score 0-5: Moderate issues, improvements needed
- Score 5-10: Good security posture
- Score > 10: Excellent security posture

### 5. Conftest - OPA Policy Validation

**What it checks:**
- Custom organizational policies (Rego)
- Compliance requirements
- Naming conventions
- Required labels/annotations
- Allowed registries
- Certificate policies
- Service mesh requirements

**Installation:**
```bash
wget https://github.com/open-policy-agent/conftest/releases/latest/download/conftest_linux_amd64
chmod +x conftest_linux_amd64
sudo mv conftest_linux_amd64 /usr/local/bin/conftest
```

**Usage:**
```bash
# Test with policies
conftest test k8s/ --policy ./policies

# Verify policy
conftest verify --policy ./policies

# Show all denials
conftest test k8s/ --policy ./policies --all-namespaces

# Output formats
conftest test k8s/ --policy ./policies --output json
conftest test k8s/ --policy ./policies --output table
```

**Policy Examples:**

See `policies/k8s.rego` for our custom policies including:
- Resource limits required
- No privileged containers
- runAsNonRoot enforced
- Probes required
- No dangerous capabilities
- Certificate DNS name validation
- Service selector validation

### 6. yamllint - YAML Syntax

**What it checks:**
- YAML syntax errors
- Indentation consistency
- Line length
- Trailing whitespace
- Empty lines
- Key duplication

**Installation:**
```bash
pip3 install yamllint
```

**Usage:**
```bash
# Lint all YAML files
yamllint k8s/*.yaml

# Relaxed rules
yamllint -d relaxed k8s/*.yaml

# Custom config
yamllint -c .yamllint k8s/*.yaml
```

## CI/CD Integration

### GitHub Actions

```yaml
name: IaC Security Scan
on: [push, pull_request]
jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install tools
        run: |
          pip3 install checkov yamllint
          # Install other tools...

      - name: Run scans
        run: |
          cd cluster/ai-ops-agent
          ./scan.sh
```

### GitLab CI

```yaml
iac-scan:
  stage: test
  image: python:3.11
  script:
    - pip3 install checkov yamllint
    - cd cluster/ai-ops-agent
    - ./scan.sh
  artifacts:
    reports:
      junit: scan-results.xml
```

### Pre-commit Hook

```bash
# .git/hooks/pre-commit
#!/bin/bash
cd cluster/ai-ops-agent
./scan.sh || exit 1
```

## Policy Development

### Creating Custom Policies

1. **Identify requirement**: What needs to be enforced?
2. **Write Rego policy**: Add to `policies/k8s.rego`
3. **Test policy**: `conftest verify --policy ./policies`
4. **Test against manifests**: `conftest test k8s/ --policy ./policies`

### Policy Template

```rego
package main

# Deny rule example
deny[msg] {
    input.kind == "Deployment"
    # Your condition here
    msg := "Your error message here"
}

# Warn rule example
warn[msg] {
    input.kind == "Deployment"
    # Your condition here
    msg := "Your warning message here"
}
```

## Remediation Guide

### Common Issues and Fixes

**Issue: Missing resource limits**
```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

**Issue: Running as root**
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
```

**Issue: Missing probes**
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8000
  initialDelaySeconds: 10
  periodSeconds: 30

readinessProbe:
  httpGet:
    path: /ready
    port: 8000
  initialDelaySeconds: 5
  periodSeconds: 10
```

**Issue: Using latest tag**
```yaml
# Bad
image: nginx:latest

# Good
image: nginx:1.25.3
```

**Issue: Privileged container**
```yaml
# Remove this
securityContext:
  privileged: true

# Use specific capabilities instead
securityContext:
  capabilities:
    drop:
      - ALL
    add:
      - NET_BIND_SERVICE  # Only if needed
```

## Continuous Improvement

### Regular Tasks

- [ ] Update scanner tools monthly
- [ ] Review and update policies quarterly
- [ ] Analyze scan trends for recurring issues
- [ ] Add new policies based on security findings
- [ ] Document exceptions and justifications

### Metrics to Track

- Scan pass rate over time
- Average security score (kubesec)
- Number of policy violations by type
- Time to remediate issues
- False positive rate

## References

- [Checkov Documentation](https://www.checkov.io/documentation.html)
- [kubeval GitHub](https://github.com/instrumenta/kubeval)
- [kube-score GitHub](https://github.com/zegl/kube-score)
- [kubesec GitHub](https://github.com/controlplaneio/kubesec)
- [Conftest Documentation](https://www.conftest.dev/)
- [OPA Rego Guide](https://www.openpolicyagent.org/docs/latest/policy-language/)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [OWASP Kubernetes Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Kubernetes_Security_Cheat_Sheet.html)
