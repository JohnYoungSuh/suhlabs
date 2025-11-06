# Backend - Multi-tenant SaaS Management Platform

This directory contains the backend services that manage all home appliances.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Backend (Cloud/Datacenter)                             │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ Management  │  │ LLM Agent    │  │ Ansible      │   │
│  │ API         │  │ (Ollama)     │  │ Control      │   │
│  │ (FastAPI)   │  │              │  │ Plane        │   │
│  └─────────────┘  └──────────────┘  └──────────────┘   │
│         │                  │                │           │
│         └──────────────────┴────────────────┘           │
│                      │                                  │
│         ┌────────────┴────────────┐                     │
│         ▼                         ▼                     │
│  ┌─────────────┐         ┌──────────────┐              │
│  │ PostgreSQL  │         │ Redis        │              │
│  │ (Customer   │         │ (Cache)      │              │
│  │  Database)  │         │              │              │
│  └─────────────┘         └──────────────┘              │
└─────────────────────────────────────────────────────────┘
```

## Components

### `/api` - Management API (FastAPI)
REST API for appliance management and customer interaction.

**Key Endpoints:**
- `POST /api/v1/heartbeat` - Appliance health check-in
- `GET /api/v1/appliance/{id}/config` - Retrieve appliance configuration
- `POST /api/v1/support` - LLM-powered customer support
- `POST /api/v1/tasks` - Execute tasks on appliances

**Tech Stack:** FastAPI, Pydantic, SQLAlchemy, Alembic

### `/llm` - LLM Integration (Ollama)
Natural language processing for customer support and intent parsing.

**Capabilities:**
- Parse customer requests: "Add user John" → Ansible playbook
- Answer support questions: "How do I access my files?"
- Generate automation scripts from natural language

**Models:**
- Development: Llama 3.2 3B (low resource)
- Production: Llama 3.1 8B (better accuracy)

### `/ansible` - Automation Control Plane
Ansible playbooks and inventory for managing appliances.

**Structure:**
```
ansible/
├── playbooks/
│   ├── dns.yml           # DNS configuration
│   ├── samba.yml         # File sharing setup
│   ├── mail.yml          # Mail server config
│   ├── pki.yml           # PKI/certificate management
│   └── users.yml         # User management
├── inventory/
│   └── appliances.yml    # Dynamic appliance inventory
├── roles/                # Reusable Ansible roles
└── ansible.cfg           # Ansible configuration
```

### `/k8s` - Kubernetes Manifests
Kubernetes deployment configurations for production.

**Components:**
- Deployments (API, LLM, workers)
- Services (load balancing)
- Ingress (SSL termination)
- ConfigMaps & Secrets
- HPA (autoscaling)

## Development

### Local Development (Docker Compose)
```bash
# Start all backend services locally
cd backend
docker-compose up -d

# Services available at:
# - API: http://localhost:8000
# - Ollama: http://localhost:11434
# - PostgreSQL: localhost:5432
# - Redis: localhost:6379
```

### Run API locally
```bash
cd backend/api
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

### Test LLM integration
```bash
cd backend/llm
python test_client.py
```

### Run Ansible playbook
```bash
cd backend/ansible
ansible-playbook -i inventory/appliances.yml playbooks/dns.yml
```

## Deployment

### Docker Compose (Small Scale: 1-100 customers)
```bash
make backend-up
```

### Kubernetes (Medium/Large Scale: 100+ customers)
```bash
# Proxmox (k3s)
make deploy-backend ENV=proxmox

# AWS (EKS)
make deploy-backend ENV=aws
```

## Environment Variables

```bash
# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/aiops

# Redis
REDIS_URL=redis://localhost:6379/0

# Ollama
OLLAMA_API_URL=http://localhost:11434
OLLAMA_MODEL=llama3.2:3b

# Security
SECRET_KEY=your-secret-key
JWT_SECRET=your-jwt-secret

# Ansible
ANSIBLE_VAULT_PASSWORD=your-vault-password
```

## Testing

```bash
# API tests
cd backend/api
pytest tests/

# Integration tests
cd backend/tests
pytest integration/

# Load testing
locust -f backend/tests/load_test.py
```

## Monitoring

- **Metrics:** Prometheus (`/metrics` endpoint)
- **Logs:** JSON structured logging
- **Tracing:** OpenTelemetry (optional)
- **Health:** `/health` endpoint

## Scaling

| Customers | API Replicas | LLM Instances | Database | Redis |
|-----------|--------------|---------------|----------|-------|
| 1-100 | 1-2 | 1 (CPU) | Single | Single |
| 100-1k | 3-5 | 1-2 (GPU optional) | HA | Cluster |
| 1k-10k | 10-20 | 3-5 (GPU) | Cluster | Cluster |

## Security

- **Authentication:** JWT tokens
- **Authorization:** Role-based access control (RBAC)
- **Secrets:** HashiCorp Vault or Kubernetes Secrets
- **TLS:** All external communication encrypted
- **Rate Limiting:** Redis-based rate limiting
