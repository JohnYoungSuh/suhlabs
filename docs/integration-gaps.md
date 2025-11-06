# Integration Gaps Analysis

**Purpose:** Identify missing integrations needed for production-ready AI Ops platform
**Status:** POC → MVP → Production
**Date:** 2025-11-06

---

## 🎯 Current State (POC)

### What We Have ✅

**Infrastructure:**
- Docker Compose local development
- Backend API (FastAPI)
- LLM client (Ollama)
- Ansible playbooks (DNS, Samba, users)
- Appliance agent (basic)
- Docker-based testing

**Capabilities:**
- Natural language parsing
- Playbook generation
- Local execution on containers
- Basic logging

### What We DON'T Have ❌

- Database persistence
- Authentication/authorization
- Task queue for async execution
- Monitoring & observability
- Real Raspberry Pi deployment
- Customer onboarding
- Billing/subscriptions
- CI/CD pipeline
- Production deployment
- Backup/recovery

---

## 📊 Integration Gaps by Category

### 1. Authentication & Authorization (CRITICAL) 🔐

**Status:** ❌ Missing

**What's Needed:**
- User registration/login
- API key management
- JWT token authentication
- Role-based access control (RBAC)
- Multi-tenancy (customer isolation)
- OAuth2 (optional - for Google/GitHub login)

**Integration Options:**

| Option | Pros | Cons | Effort |
|--------|------|------|--------|
| **Auth0** | Easy, feature-rich, scales | $$$, vendor lock-in | 1 week |
| **Keycloak** | Open-source, self-hosted | Complex setup | 2 weeks |
| **FastAPI Users** | Simple, Python native | Basic features | 1 week |
| **Roll Your Own** | Full control | Security risk | 3 weeks |

**Recommendation:** **FastAPI Users** for MVP, migrate to Auth0 later

**Implementation:**
```python
# backend/api/auth.py
from fastapi_users import FastAPIUsers
from fastapi_users.authentication import JWTStrategy

# User model
class User(SQLAlchemyBaseUserTable[int], Base):
    customer_id = Column(String, ForeignKey("customers.id"))
    api_key = Column(String, unique=True, index=True)

# Endpoints: POST /auth/register, POST /auth/login, POST /api-keys
```

**JIRA Story:** AUTH-001 - Implement authentication with FastAPI Users (5 points)

---

### 2. Database & Persistence (CRITICAL) 💾

**Status:** ❌ Missing

**What's Needed:**
- PostgreSQL schema
- SQLAlchemy models
- Alembic migrations
- Connection pooling
- Backup strategy

**Schema Requirements:**
```sql
-- Core tables
customers (id, email, name, subscription_tier, created_at)
appliances (id, customer_id, ip, status, last_heartbeat)
configs (id, appliance_id, config_type, data, version)
tasks (id, appliance_id, playbook, status, results)

-- AI decisions (for observability)
ai_decisions (id, query, intent, confidence, execution_result)

-- Audit log
audit_log (id, customer_id, action, resource, timestamp)
```

**Integration:**
- Already have PostgreSQL in docker-compose ✅
- Need to create schema and models ❌
- Need Alembic migrations ❌

**Tools:**
- SQLAlchemy ORM
- Alembic for migrations
- asyncpg for async support

**JIRA Epic:** DB-100 - Database schema and persistence (13 points)

---

### 3. Task Queue (HIGH PRIORITY) 📬

**Status:** ❌ Missing

**What's Needed:**
- Async task execution (Ansible playbooks can take 30-60s)
- Job queue with retries
- Task status tracking
- Dead letter queue for failures

**Integration Options:**

| Option | Pros | Cons | Effort |
|--------|------|------|--------|
| **Celery + Redis** | Battle-tested, feature-rich | Heavy, complex | 1 week |
| **RQ (Redis Queue)** | Simple, Python native | Less features | 3 days |
| **ARQ (async RQ)** | FastAPI-native, async | Newer, less mature | 3 days |
| **Dramatiq** | Modern, reliable | Smaller community | 1 week |

**Recommendation:** **ARQ** for MVP (async-native), **Celery** for scale

**Implementation:**
```python
# backend/tasks/worker.py
from arq import create_pool
from arq.connections import RedisSettings

async def execute_ansible_playbook(
    ctx,
    playbook_path: str,
    appliance_id: str
) -> dict:
    # Execute playbook
    result = await ansible_executor.execute(playbook_path, appliance_id)
    return result

# In API
task_id = await redis.enqueue_job(
    'execute_ansible_playbook',
    playbook_path,
    appliance_id
)
```

**JIRA Story:** QUEUE-001 - Implement ARQ task queue (5 points)

---

### 4. Monitoring & Observability (HIGH PRIORITY) 📊

**Status:** ❌ Missing (documented in `observability-architecture.md`)

**What's Needed:**
- Structured logging (Loki)
- Metrics (Prometheus)
- Distributed tracing (Tempo/Jaeger)
- Dashboards (Grafana)
- Alerts (Prometheus Alertmanager)

**Integration:**
- Prometheus: Scrape `/metrics` endpoint
- Loki: Collect logs from containers
- Grafana: Visualize metrics + logs
- Alertmanager: Send to Slack/PagerDuty

**Already in docker-compose:** ✅ prometheus, grafana services defined

**Missing:**
- ❌ Metrics instrumentation in code
- ❌ Structured logging
- ❌ Grafana dashboards
- ❌ Alert rules

**JIRA Epic:** OBS-100 - Observability implementation (21 points)
- See `observability-architecture.md` for details

---

### 5. Secrets Management (MEDIUM PRIORITY) 🔑

**Status:** ❌ Missing (Vault in old design, not current)

**What's Needed:**
- Secure storage for:
  - Database credentials
  - API keys
  - SSH keys (for Ansible)
  - Customer secrets

**Integration Options:**

| Option | Pros | Cons | Effort |
|--------|------|------|--------|
| **HashiCorp Vault** | Industry standard, feature-rich | Complex, resource-heavy | 1 week |
| **AWS Secrets Manager** | Managed, integrated | AWS-only, $$$| 3 days |
| **Kubernetes Secrets** | Built-in, simple | Not for non-k8s | N/A |
| **Environment Variables** | Simple | Insecure, not scalable | 1 day |

**Recommendation:**
- **MVP:** Environment variables + .env files (gitignored)
- **Production:** HashiCorp Vault (when on Proxmox/AWS)

**JIRA Story:** SEC-001 - Implement Vault integration (3 points)

---

### 6. CI/CD Pipeline (MEDIUM PRIORITY) 🚀

**Status:** ❌ Missing

**What's Needed:**
- Automated testing on push
- Docker image building
- Security scanning
- Deployment automation

**GitHub Actions Workflow:**
```yaml
# .github/workflows/ci.yml
name: CI/CD

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run tests
        run: |
          docker-compose up -d postgres redis
          pytest backend/tests

  build:
    runs-on: ubuntu-latest
    steps:
      - name: Build Docker images
        run: |
          docker build -t aiops-backend:${{ github.sha }} backend/
          docker build -t aiops-appliance:${{ github.sha }} appliance/

  security:
    runs-on: ubuntu-latest
    steps:
      - name: Scan for vulnerabilities
        run: |
          trivy image aiops-backend:latest
          snyk test

  deploy:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to staging
        run: |
          # Deploy to Proxmox or AWS
```

**JIRA Epic:** CI-100 - CI/CD pipeline (8 points)

---

### 7. Backup & Recovery (MEDIUM PRIORITY) 💾

**Status:** ❌ Missing

**What's Needed:**
- Database backups (daily)
- Appliance config backups
- Disaster recovery plan
- Backup testing

**Integration Options:**

| Component | Backup Strategy | Frequency | Retention |
|-----------|----------------|-----------|-----------|
| **PostgreSQL** | pg_dump to S3/Minio | Daily | 30 days |
| **Appliance configs** | Sync to backend DB | Hourly | 7 days |
| **Ansible playbooks** | Git repository | On change | Forever |
| **Ollama models** | S3/Minio | On update | 3 versions |

**Implementation:**
```bash
# scripts/backup.sh
#!/bin/bash
pg_dump aiops | gzip > backup-$(date +%Y%m%d).sql.gz
aws s3 cp backup-*.sql.gz s3://aiops-backups/

# Cron: 0 2 * * * /opt/aiops/scripts/backup.sh
```

**JIRA Story:** BACKUP-001 - Implement automated backups (3 points)

---

### 8. Appliance Onboarding & Provisioning (HIGH PRIORITY) 📱

**Status:** ❌ Missing

**What's Needed:**
- Raspberry Pi image builder
- First-boot setup wizard
- Backend registration
- Network configuration
- SSH key provisioning

**Onboarding Flow:**
```
1. Flash SD card with custom image
2. Boot Raspberry Pi
3. Connect to Wi-Fi (or Ethernet)
4. Visit http://appliance.local
5. Enter registration code
6. Appliance registers with backend
7. Backend provisions SSH keys
8. Services start automatically
```

**Image Builder:**
- Base: Raspbian Lite (64-bit)
- Pre-installed: dnsmasq, samba, postfix, agent
- Auto-start: onboarding web UI on port 80
- Size: ~2 GB compressed image

**JIRA Epic:** PROVISION-100 - Appliance provisioning (13 points)

---

### 9. Billing & Subscriptions (LOW PRIORITY for POC) 💳

**Status:** ❌ Missing (not needed for POC)

**What's Needed:**
- Subscription management
- Payment processing
- Usage tracking
- Invoicing

**Integration Options:**

| Option | Pros | Cons | Effort |
|--------|------|------|--------|
| **Stripe** | Easy, reliable, global | 2.9% + $0.30 fee | 1 week |
| **Paddle** | Handles VAT/taxes | Higher fees | 1 week |
| **Manual** | No fees | Not scalable | 2 days |

**Recommendation:** **Stripe** when ready to monetize

**Defer until:** Post-MVP (after 50+ paying customers)

---

### 10. Alerting & Notifications (MEDIUM PRIORITY) 🔔

**Status:** ❌ Missing

**What's Needed:**
- Customer notifications (email, SMS)
- System alerts (Slack, PagerDuty)
- Appliance status updates
- Task completion notifications

**Integration Options:**

| Channel | Service | Cost | Use Case |
|---------|---------|------|----------|
| **Email** | SendGrid, AWS SES | $0.10/1k | Transactional emails |
| **SMS** | Twilio | $0.0075/SMS | Critical alerts |
| **Slack** | Slack API | Free | Dev team alerts |
| **Push** | Firebase | Free | Mobile app |
| **PagerDuty** | PagerDuty | $19/user/mo | On-call alerts |

**Implementation:**
```python
# backend/notifications/email.py
from sendgrid import SendGridAPIClient

async def send_task_complete(customer_email: str, task_result: dict):
    message = {
        "to": customer_email,
        "from": "noreply@aiops.example.com",
        "subject": "Task Completed Successfully",
        "text": f"Your DNS record has been added: {task_result}"
    }
    sg = SendGridAPIClient(settings.SENDGRID_API_KEY)
    sg.send(message)
```

**JIRA Story:** NOTIFY-001 - Implement email notifications (5 points)

---

### 11. Customer Dashboard (HIGH PRIORITY for MVP) 🖥️

**Status:** ❌ Missing

**What's Needed:**
- Web UI for customers
- View appliance status
- Submit commands via UI (not just API)
- View task history
- Manage settings

**Tech Stack:**
- React or Vue.js
- Tailwind CSS
- Axios for API calls
- React Query for caching

**Pages:**
```
/dashboard          - Overview (appliances, recent tasks)
/appliances         - List of appliances
/appliances/:id     - Appliance details
/tasks              - Task history
/tasks/:id          - Task details
/settings           - Account settings
/help               - Documentation
```

**JIRA Epic:** UI-100 - Customer dashboard (21 points)

---

### 12. Real Raspberry Pi Testing (HIGH PRIORITY) 🥧

**Status:** ❌ Missing (currently Docker only)

**What's Needed:**
- Test on actual Raspberry Pi 4
- Measure real resource usage
- Test network connectivity
- Test SSH from backend
- Performance benchmarking

**Blockers:**
- Need physical Raspberry Pi 4 (4GB RAM)
- Need 64GB USB SSD
- Need test network setup

**JIRA Story:** TEST-001 - Raspberry Pi hardware testing (3 points)

---

### 13. Error Handling & Retries (MEDIUM PRIORITY) ⚠️

**Status:** ❌ Missing

**What's Needed:**
- Retry logic for transient failures
- Circuit breakers
- Graceful degradation
- User-friendly error messages

**Scenarios:**
- LLM API timeout → Retry 3 times
- Ansible SSH failure → Retry with backoff
- Appliance offline → Queue task, retry later
- Database connection lost → Reconnect pool

**Libraries:**
- `tenacity` for retries
- `pybreaker` for circuit breakers

**JIRA Story:** ERROR-001 - Implement error handling (5 points)

---

### 14. Rate Limiting (MEDIUM PRIORITY) 🚦

**Status:** ❌ Missing

**What's Needed:**
- Prevent abuse
- Fair resource allocation
- DDoS protection

**Implementation:**
```python
# backend/api/middleware.py
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

@app.post("/api/v1/dns/add")
@limiter.limit("10/minute")  # 10 requests per minute
async def add_dns_record(request: Request):
    ...
```

**Limits:**
- API endpoints: 100 requests/minute per customer
- LLM queries: 20 requests/minute per customer
- Ansible execution: 10 concurrent tasks per appliance

**JIRA Story:** RATE-001 - Implement rate limiting (3 points)

---

### 15. Documentation (HIGH PRIORITY) 📚

**Status:** ⚠️ Partial (READMEs exist, but incomplete)

**What's Needed:**
- API documentation (auto-generated from OpenAPI)
- User guides (how to use the platform)
- Developer docs (how to contribute)
- Architecture docs (system design)
- Troubleshooting guides
- Video tutorials

**Tools:**
- OpenAPI/Swagger for API docs
- MkDocs for user/dev docs
- Loom for video tutorials

**JIRA Epic:** DOCS-100 - Complete documentation (8 points)

---

## 📊 Priority Matrix

### Must Have (MVP)
| Integration | Priority | Effort | Dependency |
|-------------|----------|--------|------------|
| Database schema | P0 | 13 pts | None |
| Authentication | P0 | 5 pts | Database |
| Task queue | P0 | 5 pts | Redis |
| Observability | P0 | 21 pts | None |
| Appliance onboarding | P0 | 13 pts | Database |
| Customer dashboard | P0 | 21 pts | Auth, DB |
| **Total** | | **78 pts** | |

### Should Have (MVP+)
| Integration | Priority | Effort | Dependency |
|-------------|----------|--------|------------|
| CI/CD pipeline | P1 | 8 pts | None |
| Error handling | P1 | 5 pts | None |
| Notifications | P1 | 5 pts | None |
| Rate limiting | P1 | 3 pts | Redis |
| Backup/recovery | P1 | 3 pts | Database |
| RPi testing | P1 | 3 pts | Hardware |
| **Total** | | **27 pts** | |

### Nice to Have (Post-MVP)
| Integration | Priority | Effort | Dependency |
|-------------|----------|--------|------------|
| Secrets management | P2 | 3 pts | None |
| Billing/subscriptions | P3 | 13 pts | Stripe |
| **Total** | | **16 pts** | |

**Grand Total:** 121 story points (~6-8 weeks with 1 developer)

---

## 🛠️ Implementation Roadmap

### Sprint 1 (2 weeks): Foundation
- ✅ Project restructure (done)
- ✅ Ansible POC (in progress)
- 📋 Database schema
- 📋 Authentication

### Sprint 2 (2 weeks): Core Features
- 📋 Task queue
- 📋 Observability (basic)
- 📋 Error handling

### Sprint 3 (2 weeks): Customer-Facing
- 📋 Customer dashboard
- 📋 Appliance onboarding
- 📋 Notifications

### Sprint 4 (2 weeks): Production Ready
- 📋 CI/CD pipeline
- 📋 Backup/recovery
- 📋 Rate limiting
- 📋 Documentation
- 📋 RPi testing

**Total:** 8 weeks to production-ready MVP

---

## 🔗 Integration Dependencies Graph

```
Authentication
    ↓
Database ──→ Task Queue ──→ Observability
    ↓            ↓              ↓
Appliance    Dashboard    Monitoring
Onboarding       ↓              ↓
    ↓        Notifications  Alerting
    ↓            ↓              ↓
RPi Testing  CI/CD ──────→ Production
```

---

## ✅ Checklist: Are We Production Ready?

### Security
- [ ] Authentication & authorization
- [ ] Secrets management
- [ ] Rate limiting
- [ ] Input validation
- [ ] Security audit

### Reliability
- [ ] Database backups
- [ ] Error handling & retries
- [ ] Monitoring & alerts
- [ ] Disaster recovery plan
- [ ] Load testing

### Scalability
- [ ] Task queue
- [ ] Connection pooling
- [ ] Caching (Redis)
- [ ] Horizontal scaling support

### Usability
- [ ] Customer dashboard
- [ ] Documentation
- [ ] Onboarding flow
- [ ] Support channels

### Operations
- [ ] CI/CD pipeline
- [ ] Logging & observability
- [ ] Deployment automation
- [ ] Runbooks

**Current Score:** 5/25 (20%) ❌
**MVP Target:** 18/25 (72%) ✅
**Production Target:** 25/25 (100%) ✅

---

## 🚀 Next Steps

1. **Complete Ansible POC** (this week)
2. **Implement database schema** (Sprint 1)
3. **Add authentication** (Sprint 1)
4. **Setup observability** (Sprint 2)
5. **Build customer dashboard** (Sprint 3)
6. **Production deployment** (Sprint 4)

**Estimated Time to Production:** 8 weeks (with aggressive timeline)

---

## 🔗 Related Documents

- [Ansible POC JIRA](./ansible-poc-jira.md) - Current focus
- [Observability Architecture](./observability-architecture.md) - Detailed monitoring plan
- [Micro LLM Strategy](./micro-llm-strategy.md) - Future optimization
- [MVP Analysis](./mvp-analysis.md) - Project scope analysis
