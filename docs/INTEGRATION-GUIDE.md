# Integration Guide: AI Agent Code Quality Governance

**Target Repository:** https://github.com/JohnYoungSuh/ai-agent-governance-framework-internal

---

## Quick Start

### 1. Add Policy Documents

Copy these files to your governance framework repository:

```bash
# In your ai-agent-governance-framework-internal repo
mkdir -p policies/code-quality
cp /path/to/suhlabs/docs/ai-agent-code-quality-policy.md policies/code-quality/
cp /path/to/suhlabs/docs/ai-agent-system-prompt.md policies/code-quality/
```

### 2. Update Governance Framework Config

Add to your `governance.yaml` or equivalent:

```yaml
policies:
  code_quality:
    enabled: true
    enforcement_level: mandatory
    policy_file: policies/code-quality/ai-agent-code-quality-policy.md
    system_prompt_file: policies/code-quality/ai-agent-system-prompt.md

    validations:
      - name: yaml_indentation
        tool: yamllint
        severity: error

      - name: shell_script_quality
        tool: shellcheck
        severity: warning

      - name: secret_detection
        tool: gitleaks
        severity: critical

      - name: terraform_security
        tool: tfsec
        severity: high

    auto_fix:
      enabled: true
      scope:
        - indentation
        - trailing_whitespace
        - end_of_file_fixer
```

### 3. Add Pre-Commit Hooks

Create `.pre-commit-config.yaml` in all managed repositories:

```yaml
# Copy this to all repos managed by your governance framework
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.0
    hooks:
      - id: gitleaks

  - repo: https://github.com/adrienverge/yamllint
    rev: v1.33.0
    hooks:
      - id: yamllint
        args: [--strict]

  - repo: https://github.com/koalaman/shellcheck-precommit
    rev: v0.9.0
    hooks:
      - id: shellcheck

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: check-yaml
      - id: check-json
      - id: detect-private-key
      - id: trailing-whitespace
      - id: end-of-file-fixer
```

### 4. GitHub Actions Workflow

Add `.github/workflows/code-quality-enforcement.yml`:

```yaml
name: Code Quality Enforcement

on:
  pull_request:
  push:
    branches: [main, master]

jobs:
  enforce-standards:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run yamllint
        uses: ibiqlik/action-yamllint@v3
        with:
          strict: true

      - name: Run shellcheck
        uses: ludeeus/action-shellcheck@master
        with:
          severity: error

      - name: Secret scanning
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Policy compliance check
        run: |
          # Custom script to verify compliance
          python3 scripts/check_policy_compliance.py
```

---

## Integration Patterns

### Pattern 1: System Prompt Injection (Recommended)

For Claude/GPT-based agents:

```python
# agents/code_generator.py
import os

def load_quality_policy():
    """Load code quality policy as system prompt."""
    policy_path = "policies/code-quality/ai-agent-system-prompt.md"
    with open(policy_path, 'r') as f:
        return f.read()

def generate_code(user_request, context):
    """Generate code with quality enforcement."""
    system_prompt = f"""
    {load_quality_policy()}

    Project Context:
    - Language: {context.language}
    - Framework: {context.framework}
    - Security Level: {context.security_level}
    """

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_request}
    ]

    response = claude_api.complete(messages)

    # Post-generation validation
    validate_output(response.code)

    return response

def validate_output(code):
    """Validate generated code against policies."""
    checks = {
        'secrets': check_for_secrets(code),
        'indentation': check_indentation(code),
        'linting': run_linter(code)
    }

    if not all(checks.values()):
        raise PolicyViolation(f"Failed checks: {checks}")
```

### Pattern 2: RAG-Based Policy Enforcement

```python
# agents/rag_policy_enforcer.py
from langchain.vectorstores import Chroma
from langchain.embeddings import OpenAIEmbeddings

class PolicyEnforcer:
    def __init__(self):
        self.policy_db = self._load_policies()

    def _load_policies(self):
        """Load policies into vector database."""
        policy_docs = [
            load_document("ai-agent-code-quality-policy.md"),
            load_document("ai-agent-system-prompt.md")
        ]

        return Chroma.from_documents(
            documents=policy_docs,
            embedding=OpenAIEmbeddings()
        )

    def get_relevant_rules(self, task_description):
        """Retrieve relevant policy rules for task."""
        return self.policy_db.similarity_search(
            task_description,
            k=5
        )

    def enforce(self, code_generation_task):
        """Enforce policies during code generation."""
        relevant_rules = self.get_relevant_rules(
            code_generation_task.description
        )

        enhanced_prompt = f"""
        Relevant Policy Rules:
        {format_rules(relevant_rules)}

        Task: {code_generation_task.description}

        Generate code following the above rules.
        """

        return self.agent.execute(enhanced_prompt)
```

### Pattern 3: Post-Generation Validator

```python
# agents/validators.py
import yaml
import subprocess
from typing import Dict, List

class CodeQualityValidator:
    """Validate generated code against policies."""

    def validate_yaml(self, content: str) -> Dict:
        """Validate YAML indentation and syntax."""
        try:
            # Parse YAML
            yaml.safe_load(content)

            # Check indentation
            lines = content.split('\n')
            for i, line in enumerate(lines, 1):
                if line.strip() and not line.startswith('#'):
                    indent = len(line) - len(line.lstrip())
                    if indent % 2 != 0:
                        return {
                            'valid': False,
                            'error': f'Line {i}: Invalid indentation (must be multiple of 2)'
                        }

            # Run yamllint
            result = subprocess.run(
                ['yamllint', '-'],
                input=content.encode(),
                capture_output=True
            )

            return {
                'valid': result.returncode == 0,
                'output': result.stdout.decode()
            }

        except yaml.YAMLError as e:
            return {'valid': False, 'error': str(e)}

    def check_secrets(self, content: str) -> List[str]:
        """Check for hardcoded secrets."""
        secret_patterns = [
            r'password\s*[:=]\s*["\'](?!.*\$\{)(.+)["\']',
            r'api[_-]?key\s*[:=]\s*["\'](?!.*\$\{)(.+)["\']',
            r'token\s*[:=]\s*["\'](?!.*\$\{)(.+)["\']',
            r'secret\s*[:=]\s*["\'](?!.*\$\{)(.+)["\']',
        ]

        findings = []
        for pattern in secret_patterns:
            matches = re.finditer(pattern, content, re.IGNORECASE)
            for match in matches:
                findings.append({
                    'pattern': pattern,
                    'value': match.group(1),
                    'line': content[:match.start()].count('\n') + 1
                })

        return findings

    def validate_shell_script(self, content: str) -> Dict:
        """Validate shell script with shellcheck."""
        result = subprocess.run(
            ['shellcheck', '-'],
            input=content.encode(),
            capture_output=True
        )

        return {
            'valid': result.returncode == 0,
            'output': result.stdout.decode(),
            'warnings': result.stderr.decode()
        }
```

---

## Monitoring & Metrics

### Dashboard Metrics

Add these to your governance dashboard:

```python
# metrics/code_quality_metrics.py
from dataclasses import dataclass
from datetime import datetime

@dataclass
class CodeQualityMetrics:
    """Track code quality over time."""

    timestamp: datetime

    # Generation metrics
    files_generated: int
    generation_success_rate: float

    # Quality metrics
    linting_pass_rate: float
    secret_leaks_prevented: int
    indentation_fixes: int

    # Security metrics
    security_scans_passed: int
    security_scans_failed: int
    critical_vulnerabilities: int

    # Compliance
    policy_compliance_score: float
    policy_violations: List[str]

    def to_dashboard_format(self):
        """Format for dashboard display."""
        return {
            'quality_score': self.linting_pass_rate * 100,
            'security_score': (
                self.security_scans_passed /
                (self.security_scans_passed + self.security_scans_failed)
            ) * 100,
            'compliance_score': self.policy_compliance_score * 100,
            'alerts': [
                f"Secret leaks prevented: {self.secret_leaks_prevented}",
                f"Critical vulnerabilities: {self.critical_vulnerabilities}"
            ]
        }
```

### Alerting Rules

```yaml
# alerts/code_quality_alerts.yaml
alerts:
  - name: secret_leak_attempt
    condition: secret_leaks_prevented > 0
    severity: critical
    action: notify_security_team

  - name: low_linting_pass_rate
    condition: linting_pass_rate < 0.9
    severity: warning
    action: notify_team_lead

  - name: policy_violation
    condition: policy_violations.length > 0
    severity: high
    action: block_merge

  - name: critical_vulnerability
    condition: critical_vulnerabilities > 0
    severity: critical
    action:
      - block_merge
      - create_jira_ticket
      - notify_security_team
```

---

## Rollout Plan

### Phase 1: Pilot (Week 1-2)
- [ ] Add policies to governance framework repo
- [ ] Deploy to 1-2 pilot repositories
- [ ] Monitor metrics and gather feedback
- [ ] Refine policies based on feedback

### Phase 2: Gradual Rollout (Week 3-4)
- [ ] Deploy to 25% of repositories
- [ ] Train teams on new policies
- [ ] Set up monitoring dashboards
- [ ] Document common issues and solutions

### Phase 3: Full Deployment (Week 5-6)
- [ ] Deploy to all repositories
- [ ] Make policies mandatory in CI/CD
- [ ] Enable auto-fix where safe
- [ ] Establish ongoing maintenance process

### Phase 4: Optimization (Week 7+)
- [ ] Review metrics and effectiveness
- [ ] Optimize validation performance
- [ ] Add additional language support
- [ ] Iterate on policies based on data

---

## Troubleshooting

### Issue: False Positives in Secret Detection

**Solution:**
```yaml
# .gitleaks.toml
[allowlist]
description = "Allowed patterns"
regexes = [
  '''placeholder-.*''',  # Allow placeholder values
  '''\$\{VAULT_.*\}''',  # Allow Vault placeholders
]
```

### Issue: Indentation Conflicts Between Tools

**Solution:**
```yaml
# .yamllint.yml
rules:
  indentation:
    spaces: 2
    indent-sequences: true
    check-multi-line-strings: false
```

### Issue: Legacy Code Doesn't Meet Standards

**Solution:**
```python
# Add exemption metadata
# legacy_exemption.yaml
exemptions:
  - path: "legacy/**"
    reason: "Pre-existing code - will refactor in Q2 2025"
    approved_by: "tech-lead@example.com"
    expires: "2025-06-30"
```

---

## Testing Your Integration

### Test Script

```bash
#!/bin/bash
# test_integration.sh

echo "Testing Code Quality Governance Integration..."

# Test 1: YAML Validation
echo "Test 1: YAML indentation..."
cat > test.yaml <<EOF
spec:
  containers:
    - name: test
      image: nginx
EOF

yamllint test.yaml && echo "✅ PASS" || echo "❌ FAIL"

# Test 2: Secret Detection
echo "Test 2: Secret detection..."
cat > test-secret.yaml <<EOF
password: "hardcoded-secret"
EOF

gitleaks detect --source=. --no-git && echo "❌ FAIL (should detect)" || echo "✅ PASS"

# Test 3: Shell Script Validation
echo "Test 3: ShellCheck..."
cat > test.sh <<'EOF'
#!/bin/bash
set -euo pipefail
local result
result=$(command)
EOF

shellcheck test.sh && echo "✅ PASS" || echo "❌ FAIL"

# Cleanup
rm -f test.yaml test-secret.yaml test.sh

echo "Integration tests complete!"
```

---

## Support & Maintenance

### Regular Reviews

**Monthly:**
- Review policy compliance metrics
- Update policies based on new threats
- Retrain AI agents on policy changes

**Quarterly:**
- Full policy audit
- Update tool versions
- Benchmark against industry standards

### Getting Help

1. **Policy Questions:** Open issue in governance framework repo
2. **Tool Issues:** Check tool documentation
3. **Integration Help:** Contact platform team
4. **Security Concerns:** Email security@example.com

---

## Additional Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CIS Kubernetes Benchmarks](https://www.cisecurity.org/benchmark/kubernetes)
- [yamllint Documentation](https://yamllint.readthedocs.io/)
- [ShellCheck Wiki](https://www.shellcheck.net/wiki/)
- [Terraform Security Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)

---

**Version:** 1.0
**Last Updated:** 2025-11-20
**Maintainer:** Platform Engineering Team
**Repository:** github.com/JohnYoungSuh/ai-agent-governance-framework-internal
