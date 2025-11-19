# AI Ops/Sec Agent

**Version**: 2.0.0

Conversational AI agent for infrastructure automation with natural language processing, RAG-based context retrieval, MCP security guardrails, and continuous ML improvement.

## Features

- 🗣️ **Conversational Triggers**: Natural language → Infrastructure actions
  - "Create me an email address" → Ansible playbook execution
  - "Deploy a website" → Terraform + Ansible automation
  - "Rotate Vault secrets" → Security operations

- 🔍 **RAG Pipeline**: Context-aware responses
  - Embeds docs, configs, and logs into Qdrant vector DB
  - Retrieves relevant context for each query
  - Augments LLM prompts with infrastructure knowledge

- 🛡️ **MCP Enforcement**: Security & compliance guardrails
  - Security policies (no prod deletion, MFA required, TLS required)
  - Compliance policies (resource tagging, audit logging)
  - Operational policies (change windows, rollback plans)

- 📊 **Continuous ML Loop**: Query logging and feedback
  - Log all queries, intents, and outcomes
  - User feedback for intent correction
  - Generate fine-tuning datasets for LLM improvement

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   User Interface                        │
│  CLI / API / Slack / WebUI                              │
└───────────────────────┬─────────────────────────────────┘
                        │
         ┌──────────────▼───────────────┐
         │   AI Ops/Sec Agent (FastAPI) │
         │                               │
         │  1. Intent Parser             │
         │  2. RAG Retriever             │
         │  3. MCP Policy Engine         │
         │  4. Execution Engine          │
         │  5. ML Logger                 │
         └──────────────┬───────────────┘
                        │
         ┌──────────────┴───────────────┐
         │                               │
    ┌────▼────┐  ┌──────▼──────┐  ┌────▼────┐
    │ Ollama  │  │   Qdrant    │  │ Ansible │
    │  (LLM)  │  │ (VectorDB)  │  │Terraform│
    └─────────┘  └─────────────┘  └─────────┘
```

## Quick Start

See [`docs/AI-OPS-SEC-QUICKSTART.md`](../../docs/AI-OPS-SEC-QUICKSTART.md) for detailed instructions.

### Deploy

```bash
# Deploy all components
kubectl apply -f deployment/qdrant.yaml
kubectl apply -f deployment/ollama.yaml
kubectl apply -f deployment/ai-ops-agent.yaml
kubectl apply -f deployment/rag-indexer-cronjob.yaml

# Verify
kubectl get pods -n ai-ops
```

### Test

```bash
# Port forward
kubectl port-forward -n ai-ops svc/ai-ops-agent 8000:80

# Test chat endpoint
curl -X POST http://localhost:8000/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Create me an email address for test@suhlabs.io",
    "user_id": "admin",
    "user_email": "admin@suhlabs.io",
    "mfa_enabled": true
  }'
```

## Project Structure

```
cluster/ai-ops-agent/
├── ai_ops_agent/               # Python package
│   ├── __init__.py
│   ├── models.py              # Data models (Intent, ExecutionPlan, etc.)
│   ├── intent/                # Intent parsing and mapping
│   │   ├── parser.py          # NL → Intent parser (Ollama)
│   │   └── mapper.py          # Intent → Execution plan mapper
│   ├── rag/                   # RAG pipeline
│   │   ├── indexer.py         # Document indexer (Qdrant)
│   │   └── retriever.py       # Context retriever
│   ├── mcp/                   # MCP enforcement
│   │   ├── policy_engine.py   # Policy evaluator
│   │   └── approval.py        # Approval workflow
│   └── ml/                    # ML logging and analytics
│       ├── logger.py          # Query/outcome logger
│       └── analytics.py       # Analytics dashboard
├── config/                    # Configuration files
│   ├── intent-mappings.yaml  # NL → Action mappings
│   └── mcp-policies.yaml     # Security/compliance policies
├── deployment/                # Kubernetes manifests
│   ├── qdrant.yaml
│   ├── ollama.yaml
│   ├── ai-ops-agent.yaml
│   └── rag-indexer-cronjob.yaml
├── main.py                    # FastAPI application
├── requirements.txt           # Python dependencies
├── Dockerfile                 # Container image
└── README.md                  # This file
```

## API Endpoints

### Chat (Main conversational interface)

```bash
POST /api/v1/chat
{
  "query": "Create an email address for user@suhlabs.io",
  "user_id": "admin",
  "user_email": "admin@suhlabs.io",
  "mfa_enabled": true
}
```

### Feedback (ML improvement)

```bash
POST /api/v1/feedback
{
  "query_id": "uuid",
  "user_id": "admin",
  "satisfaction_score": 5,
  "intent_was_correct": true
}
```

### Analytics

```bash
GET /api/v1/analytics/accuracy?days=7
GET /api/v1/analytics/errors?limit=10
GET /api/v1/analytics/policy-violations?days=30
GET /api/v1/analytics/satisfaction?days=7
```

### Approvals

```bash
GET /api/v1/approvals/pending?approver_email=admin@suhlabs.io
POST /api/v1/approvals/{approval_id}/approve
```

## Configuration

### Intent Mappings (`config/intent-mappings.yaml`)

Maps natural language intents to Terraform modules and Ansible playbooks.

Example:
```yaml
provision:
  create:
    email:
      playbook: "ansible/playbooks/provision-email.yml"
      default_vars:
        quota: "10GB"
      requires_approval: true
```

### MCP Policies (`config/mcp-policies.yaml`)

Security, compliance, and operational guardrails.

Example:
```yaml
security:
  no_production_deletion:
    enabled: true
    severity: critical
    message: "Direct deletion of production resources is not allowed"
```

## Development

### Local Development

```bash
# Install dependencies
pip install -r requirements.txt

# Run locally (requires Ollama and Qdrant running)
export OLLAMA_HOST=http://localhost:11434
export QDRANT_HOST=http://localhost:6333
python main.py
```

### Build Docker Image

```bash
docker build -t ai-ops-agent:2.0.0 .
```

### Run Tests

```bash
# TODO: Add pytest tests
pytest tests/
```

## ML Improvement Loop

### How It Works

1. **Query Logging**: Every user query is logged with parsed intent
2. **Outcome Tracking**: Execution results (success/failure) are logged
3. **User Feedback**: Users can rate responses and correct intent parsing
4. **Fine-tuning Dataset**: Corrected intents generate training examples
5. **Model Improvement**: Periodically fine-tune LLM with collected data

### View Logs

```bash
# Inside agent container
cat /var/log/ai-ops/queries.jsonl
cat /var/log/ai-ops/executions.jsonl
cat /var/log/ai-ops/outcomes.jsonl
cat /var/log/ai-ops/feedback.jsonl
```

## Roadmap

### MVP (Current)
- [x] Conversational intent parsing
- [x] RAG pipeline with Qdrant
- [x] MCP policy enforcement
- [x] ML logging and analytics
- [x] Kubernetes deployment
- [ ] Actual Terraform/Ansible execution
- [ ] Authentication/authorization

### Future Enhancements
- [ ] Slack bot integration
- [ ] Terraform execution engine
- [ ] Ansible playbook runner
- [ ] PostgreSQL for ML logs
- [ ] Prometheus metrics
- [ ] Grafana dashboards
- [ ] Multi-tenancy support
- [ ] LLM fine-tuning pipeline
- [ ] Voice interface (optional)
- [ ] Mobile app (optional)

## Security Considerations

- **Authentication**: Add OAuth/LDAP/SAML integration
- **Authorization**: RBAC with least privilege
- **Secrets**: Never log secrets; use Vault references
- **Audit**: All operations logged for compliance
- **Network**: mTLS for service-to-service communication
- **Container**: Non-root user, read-only filesystem

## Contributing

1. Read the architecture: `docs/ai-ops-sec-automation-architecture.md`
2. Create a feature branch
3. Implement and test
4. Submit PR with detailed description

## License

Apache 2.0

## Support

- **Documentation**: `docs/AI-OPS-SEC-QUICKSTART.md`
- **Architecture**: `docs/ai-ops-sec-automation-architecture.md`
- **Issues**: Submit via GitHub Issues
- **Questions**: See logs, check architecture doc

---

Built with ❤️ for the suhlabs infrastructure stack.
