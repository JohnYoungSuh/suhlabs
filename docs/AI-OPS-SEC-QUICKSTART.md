# AI Ops/Sec Automation - Quick Start Guide

**Version**: 2.0.0
**Date**: 2025-11-16

## Overview

The AI Ops/Sec Agent is a conversational AI system that translates natural language requests into secure, reproducible infrastructure operations.

**Key Capabilities:**
- 🗣️ **Conversational Interface**: "Create me an email address" → Automated provisioning
- 🔍 **RAG Pipeline**: Context-aware responses using embedded docs/configs/logs
- 🛡️ **MCP Guardrails**: Security, compliance, and operational policies
- 📊 **Continuous ML**: Query logging and feedback for LLM fine-tuning

## Architecture Components

```
User Request
    ↓
Intent Parser (Ollama + LLM)
    ↓
RAG Retriever (Qdrant Vector DB)
    ↓
MCP Policy Engine (Security Guardrails)
    ↓
Action Mapper (Terraform/Ansible)
    ↓
Execution Engine
    ↓
ML Logger (Continuous Improvement)
```

## Quick Start

### 1. Deploy Infrastructure Components

```bash
# Deploy Qdrant vector database
kubectl apply -f cluster/ai-ops-agent/deployment/qdrant.yaml

# Deploy Ollama LLM runtime
kubectl apply -f cluster/ai-ops-agent/deployment/ollama.yaml

# Wait for Ollama to be ready
kubectl wait --for=condition=ready pod -l app=ollama -n ai-ops --timeout=300s

# Pull LLM models
kubectl apply -f cluster/ai-ops-agent/deployment/ollama.yaml  # Job included

# Deploy AI Ops Agent
kubectl apply -f cluster/ai-ops-agent/deployment/ai-ops-agent.yaml

# Deploy RAG indexer cron job
kubectl apply -f cluster/ai-ops-agent/deployment/rag-indexer-cronjob.yaml
```

### 2. Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n ai-ops

# Expected output:
# NAME                            READY   STATUS    RESTARTS   AGE
# ai-ops-agent-xxxxx              1/1     Running   0          2m
# ollama-xxxxx                    1/1     Running   0          5m
# qdrant-xxxxx                    1/1     Running   0          5m

# Check agent health
kubectl port-forward -n ai-ops svc/ai-ops-agent 8000:80
curl http://localhost:8000/health
```

### 3. Test Conversational Interface

```bash
# Example 1: Create an email address
curl -X POST http://localhost:8000/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Create me an email address for john@suhlabs.io",
    "user_id": "admin",
    "user_email": "admin@suhlabs.io",
    "mfa_enabled": true
  }'

# Example 2: Deploy a website
curl -X POST http://localhost:8000/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Deploy a family website at family.suhlabs.io",
    "user_id": "admin",
    "user_email": "admin@suhlabs.io",
    "mfa_enabled": true
  }'

# Example 3: Rotate secrets
curl -X POST http://localhost:8000/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Rotate the Vault secrets",
    "user_id": "admin",
    "user_email": "admin@suhlabs.io",
    "mfa_enabled": true
  }'

# Example 4: Query information
curl -X POST http://localhost:8000/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{
    "query": "How do I check the logs?",
    "user_id": "admin",
    "user_email": "admin@suhlabs.io"
  }'
```

## Response Types

### 1. **Allowed** (Executed immediately)
```json
{
  "response": "✅ Execution Approved\n\n**Action:** Creating email...",
  "intent": {...},
  "execution_plan": {...},
  "policy_decision": "allowed",
  "query_id": "uuid"
}
```

### 2. **Requires Approval**
```json
{
  "response": "⏳ Approval Required\n\nRequest ID: APR-...",
  "approval_required": true,
  "approval_id": "APR-20251116-...",
  "policy_decision": "requires_approval"
}
```

### 3. **Denied** (Policy violation)
```json
{
  "response": "❌ Request Denied\n\n- MFA required...",
  "policy_decision": "denied"
}
```

### 4. **Informational** (No action needed)
```json
{
  "response": "Based on the suhlabs infrastructure...",
  "intent": {...}
}
```

## Intent Mappings

See `config/intent-mappings.yaml` for full mappings.

**Provision:**
- `create email` → `ansible/playbooks/provision-email.yml`
- `create website` → `infra/modules/static-website` + Ansible
- `create cluster` → `infra/modules/k8s-cluster`
- `create database` → `infra/modules/database`

**Security:**
- `rotate secrets` → `ansible/playbooks/rotate-vault-secrets.yml`
- `issue cert` → `ansible/playbooks/issue-certificate.yml`
- `enable mtls` → `ansible/playbooks/enable-mtls.yml`

**Identity:**
- `create user` → `ansible/playbooks/create-user.yml`
- `grant access` → `ansible/playbooks/grant-access.yml`

**Compliance:**
- `scan vulnerabilities` → `ansible/playbooks/scan-vulnerabilities.yml`
- `generate sbom` → `ansible/playbooks/generate-sbom.yml`

## MCP Policy Enforcement

### Security Policies

| Policy | Action |
|--------|--------|
| **no_production_deletion** | DENY deletion in production |
| **require_mfa** | DENY if MFA not enabled |
| **tls_required** | DENY websites without TLS |
| **secrets_encryption** | DENY plain text secrets |

### Compliance Policies

| Policy | Action |
|--------|--------|
| **resource_tagging** | DENY untagged resources |
| **audit_logging** | REQUIRE_APPROVAL for privileged ops |

### Operational Policies

| Policy | Action |
|--------|--------|
| **change_windows** | DENY production changes outside windows |
| **rollback_required** | REQUIRE_APPROVAL without rollback plan |

Edit policies in `config/mcp-policies.yaml`.

## RAG Pipeline

### How It Works

1. **Indexing** (Every 6 hours via CronJob):
   - Scans `docs/`, `infra/`, `ansible/`, `cluster/`
   - Chunks text into 512-token chunks
   - Generates embeddings with `nomic-embed-text`
   - Stores vectors in Qdrant

2. **Retrieval** (On each query):
   - Embeds user query
   - Searches Qdrant for top-5 similar chunks
   - Augments LLM context with retrieved docs

3. **Generation**:
   - Ollama generates response with context
   - Returns context-aware answer

### Manual Re-indexing

```bash
# Trigger manual indexing
kubectl create job --from=cronjob/rag-indexer rag-indexer-manual -n ai-ops

# Check indexing logs
kubectl logs -l app=rag-indexer -n ai-ops
```

## Analytics & ML Improvement

### View Analytics

```bash
# Intent classification accuracy
curl http://localhost:8000/api/v1/analytics/accuracy?days=7

# Common error patterns
curl http://localhost:8000/api/v1/analytics/errors?limit=10

# Policy violation trends
curl http://localhost:8000/api/v1/analytics/policy-violations?days=30

# User satisfaction
curl http://localhost:8000/api/v1/analytics/satisfaction?days=7
```

### Submit Feedback

```bash
curl -X POST http://localhost:8000/api/v1/feedback \
  -H "Content-Type: application/json" \
  -d '{
    "query_id": "uuid-from-chat-response",
    "user_id": "admin",
    "satisfaction_score": 5,
    "feedback_text": "Great! Worked perfectly",
    "intent_was_correct": true
  }'
```

### Correct Intent Parsing

If intent was wrong, provide correction:

```bash
curl -X POST http://localhost:8000/api/v1/feedback \
  -H "Content-Type: application/json" \
  -d '{
    "query_id": "uuid",
    "user_id": "admin",
    "satisfaction_score": 2,
    "intent_was_correct": false,
    "corrected_intent": {
      "category": "provision",
      "action": "create",
      "resource_type": "website",
      "entities": {"domain": "example.com"}
    }
  }'
```

This creates fine-tuning examples for LLM improvement.

## Approval Workflow

### List Pending Approvals

```bash
curl http://localhost:8000/api/v1/approvals/pending?approver_email=admin@suhlabs.io
```

### Approve a Request

```bash
curl -X POST http://localhost:8000/api/v1/approvals/APR-xxx/approve \
  -H "Content-Type: application/json" \
  -d '{
    "approver_email": "admin@suhlabs.io"
  }'
```

## Logs and Debugging

### View Agent Logs

```bash
# Agent logs
kubectl logs -l app=ai-ops-agent -n ai-ops -f

# Ollama logs
kubectl logs -l app=ollama -n ai-ops

# Qdrant logs
kubectl logs -l app=qdrant -n ai-ops
```

### ML Logs (JSONL format)

```bash
# Get ML logs PVC
kubectl exec -it deployment/ai-ops-agent -n ai-ops -- sh

# Inside container:
cat /var/log/ai-ops/queries.jsonl
cat /var/log/ai-ops/executions.jsonl
cat /var/log/ai-ops/outcomes.jsonl
cat /var/log/ai-ops/feedback.jsonl
cat /var/log/ai-ops/policy_violations.jsonl
```

## Example Workflows

### Workflow 1: Provision Email with Auto-Approval

```bash
curl -X POST http://localhost:8000/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Create an email address for support@suhlabs.io",
    "user_id": "admin",
    "user_email": "admin@suhlabs.io",
    "mfa_enabled": true
  }'

# Response includes execution plan
# For MVP: Manually run the Ansible playbook
ansible-playbook ansible/playbooks/provision-email.yml \
  -e email=support@suhlabs.io \
  -e quota=10GB
```

### Workflow 2: Production Change (Requires Approval)

```bash
# Request production change
curl -X POST http://localhost:8000/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Update the production database to version 16",
    "user_id": "developer",
    "user_email": "dev@suhlabs.io",
    "mfa_enabled": true
  }'

# Response:
# {
#   "approval_required": true,
#   "approval_id": "APR-20251116-abc123"
# }

# Approver grants approval
curl -X POST http://localhost:8000/api/v1/approvals/APR-20251116-abc123/approve \
  -d '{"approver_email": "admin@suhlabs.io"}'

# Execute (after approval)
```

### Workflow 3: Policy Violation (Denied)

```bash
# Try to delete production resource
curl -X POST http://localhost:8000/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Delete the production database",
    "user_id": "developer",
    "user_email": "dev@suhlabs.io"
  }'

# Response:
# {
#   "response": "❌ Request Denied\n\n- Direct deletion of production resources is not allowed",
#   "policy_decision": "denied"
# }
```

## Troubleshooting

### Ollama Not Responding

```bash
# Check Ollama pod
kubectl get pods -l app=ollama -n ai-ops

# Check if models are pulled
kubectl exec -it deployment/ollama -n ai-ops -- ollama list

# Pull models manually
kubectl exec -it deployment/ollama -n ai-ops -- ollama pull mistral
kubectl exec -it deployment/ollama -n ai-ops -- ollama pull nomic-embed-text
```

### Qdrant Connection Issues

```bash
# Check Qdrant pod
kubectl get pods -l app=qdrant -n ai-ops

# Check Qdrant collections
kubectl port-forward -n ai-ops svc/qdrant 6333:6333
curl http://localhost:6333/collections
```

### Agent Errors

```bash
# Check agent logs
kubectl logs -l app=ai-ops-agent -n ai-ops --tail=100

# Common issues:
# - Missing config files: Check config/ directory is mounted
# - Permission errors: Check /var/log/ai-ops permissions
# - Import errors: Verify all dependencies installed
```

## Next Steps

1. **Create Ansible Playbooks**: Implement actual execution playbooks in `ansible/playbooks/`
2. **Add Authentication**: Integrate with your auth system (OAuth, LDAP, etc.)
3. **Enable PostgreSQL**: Replace JSONL logs with PostgreSQL for production
4. **Add Observability**: Prometheus metrics, Grafana dashboards
5. **Fine-tune LLM**: Use collected feedback to fine-tune the intent parser
6. **Add Slack Bot**: Create Slack integration for conversational interface

## References

- **Architecture**: `docs/ai-ops-sec-automation-architecture.md`
- **Intent Mappings**: `config/intent-mappings.yaml`
- **MCP Policies**: `config/mcp-policies.yaml`
- **API Documentation**: http://localhost:8000/docs (FastAPI Swagger UI)

---

**Questions?** Check the logs, review the architecture doc, or submit an issue.
