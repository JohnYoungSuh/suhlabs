# JIRA Epic & Story Plan - AIOps Substrate MVP

## Epic 1: Backend API (COMPLETED ✅)
**Status:** Done
**Story Points:** 13

### Stories:
- [x] Setup FastAPI project structure
- [x] Create health check endpoint
- [x] Create heartbeat endpoint (appliance check-in)
- [x] Create config endpoint (appliance configuration)
- [x] Create support endpoint (LLM queries)
- [x] Create tasks endpoint (Ansible execution)
- [x] Add Docker Compose for local dev
- [x] Write API documentation

---

## Epic 2: LLM Integration (IN PROGRESS 🔄)
**Status:** In Progress
**Story Points:** 8

### Stories:
- [x] Setup Ollama client
- [x] Implement intent parsing (NL → structured data)
- [x] Implement question answering
- [ ] Connect LLM to API endpoints
- [ ] Add caching for common queries (Redis)
- [ ] Test with Llama 3.2 3B model
- [ ] Add error handling and fallbacks

---

## Epic 3: Database & Persistence (TODO 📋)
**Status:** To Do
**Story Points:** 13

### Stories:
- [ ] Design database schema (customers, appliances, configs)
- [ ] Setup Alembic migrations
- [ ] Create SQLAlchemy models
- [ ] Implement customer CRUD operations
- [ ] Implement appliance registration
- [ ] Implement config storage and versioning
- [ ] Add database tests
- [ ] Setup connection pooling

---

## Epic 4: Ansible Control Plane (IN PROGRESS 🔄)
**Status:** In Progress
**Story Points:** 21

### Stories:
- [x] Create Ansible inventory structure
- [x] Create DNS playbook
- [x] Create Samba playbook
- [x] Create users playbook
- [ ] Create Mail (Postfix) playbook
- [ ] Create PKI (Step-CA) playbook
- [ ] Implement playbook execution from API
- [ ] Add job queue (Celery + RabbitMQ)
- [ ] Add playbook result tracking
- [ ] Test playbooks on simulated appliances
- [ ] Add idempotency checks

---

## Epic 5: Appliance Agent (IN PROGRESS 🔄)
**Status:** In Progress
**Story Points:** 13

### Stories:
- [x] Create Python agent daemon
- [x] Implement heartbeat loop
- [x] Implement config sync loop
- [x] Implement metrics collection
- [ ] Implement config application (DNS, Samba, etc.)
- [ ] Add offline queue (store & forward)
- [ ] Add self-update mechanism
- [ ] Create systemd service unit
- [ ] Add agent logging and debugging
- [ ] Test agent on Docker
- [ ] Test agent on Raspberry Pi

---

## Epic 6: Appliance Services (TODO 📋)
**Status:** To Do
**Story Points:** 21

### Stories:
- [x] Create DNS setup script (dnsmasq)
- [ ] Complete DNS configuration
- [ ] Create Samba setup script
- [ ] Configure Samba shares
- [ ] Create Postfix setup script
- [ ] Configure mail relay
- [ ] Create Step-CA setup script
- [ ] Configure PKI
- [ ] Create service monitoring
- [ ] Test all services on RPi
- [ ] Create backup/restore scripts

---

## Epic 7: Appliance Onboarding UI (TODO 📋)
**Status:** To Do
**Story Points:** 13

### Stories:
- [ ] Create Flask app structure
- [ ] Create setup wizard UI
- [ ] Implement network configuration
- [ ] Implement backend registration
- [ ] Create service status dashboard
- [ ] Add troubleshooting page
- [ ] Add responsive CSS (mobile-friendly)
- [ ] Test on Raspberry Pi browser

---

## Epic 8: Authentication & Security (TODO 📋)
**Status:** To Do
**Story Points:** 13

### Stories:
- [ ] Implement JWT authentication
- [ ] Create user registration/login
- [ ] Add API key management
- [ ] Setup Vault for secrets
- [ ] Implement mTLS (appliance ↔ backend)
- [ ] Add rate limiting (Redis)
- [ ] Add CORS configuration
- [ ] Security audit

---

## Epic 9: Monitoring & Observability (TODO 📋)
**Status:** To Do
**Story Points:** 8

### Stories:
- [ ] Add Prometheus metrics endpoint
- [ ] Setup Prometheus server
- [ ] Create Grafana dashboards
- [ ] Implement structured logging
- [ ] Add tracing (OpenTelemetry - optional)
- [ ] Setup alerting rules
- [ ] Create runbooks

---

## Epic 10: Testing & Quality (TODO 📋)
**Status:** To Do
**Story Points:** 13

### Stories:
- [ ] Write backend API tests (pytest)
- [ ] Write LLM integration tests
- [ ] Write Ansible playbook tests
- [ ] Write agent tests
- [ ] Create integration test suite
- [ ] Setup CI/CD pipeline (GitHub Actions)
- [ ] Add code coverage reports
- [ ] Load testing (Locust)

---

## Epic 11: Raspberry Pi Image (TODO 📋)
**Status:** To Do
**Story Points:** 8

### Stories:
- [ ] Create base Raspbian image
- [ ] Pre-install all services
- [ ] Configure auto-start on boot
- [ ] Create first-boot setup script
- [ ] Add image builder automation
- [ ] Test image on RPi 4
- [ ] Test image on RPi 5
- [ ] Document flashing process

---

## Epic 12: Documentation (IN PROGRESS 🔄)
**Status:** In Progress
**Story Points:** 5

### Stories:
- [x] Write main README
- [x] Write backend README
- [x] Write appliance README
- [x] Write performance analysis
- [ ] Write API documentation (OpenAPI)
- [ ] Write deployment guide
- [ ] Write troubleshooting guide
- [ ] Create video tutorials

---

## Summary

**Total Story Points:** 149

**Completed:** 21 points (14%)
**In Progress:** 42 points (28%)
**To Do:** 86 points (58%)

### MVP Definition (Phase 1)
**Target:** 80 story points (first 7 epics)
**Timeline:** 2-3 months
**Goal:** Working prototype that can manage 1-10 test appliances

### Current Sprint Priorities
1. Epic 3: Database & Persistence (must have for MVP)
2. Epic 2: Complete LLM integration
3. Epic 4: Complete Ansible execution from API
4. Epic 5: Complete agent config application
5. Epic 6: Complete DNS + Samba services

---

## How to Import into JIRA

1. Create Epics for each section
2. Add Story Points to each Epic
3. Create Stories under each Epic
4. Set Epic Link for all stories
5. Prioritize stories by MVP needs
6. Assign to team members
7. Move to sprint backlog

---

## Labels to Use

- `backend` - Backend API work
- `llm` - LLM integration
- `ansible` - Ansible playbooks
- `appliance` - Raspberry Pi appliance
- `agent` - Appliance agent
- `database` - Database work
- `security` - Security-related
- `testing` - Tests and QA
- `docs` - Documentation
- `mvp` - Required for MVP
- `p0` - Critical priority
- `p1` - High priority
- `p2` - Medium priority
- `p3` - Low priority

---

## Sprint Planning Suggestion

**Sprint 1 (2 weeks):** Epic 3 (Database)
**Sprint 2 (2 weeks):** Epic 2 (LLM) + Epic 4 (Ansible execution)
**Sprint 3 (2 weeks):** Epic 5 (Agent) + Epic 6 (Services)
**Sprint 4 (2 weeks):** Epic 7 (UI) + Epic 8 (Security basics)
**Sprint 5 (2 weeks):** Epic 9 (Monitoring) + Epic 10 (Testing)
**Sprint 6 (2 weeks):** Epic 11 (RPi Image) + Buffer for issues

Total: 12 weeks to MVP
