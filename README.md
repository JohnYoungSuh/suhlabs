# AIOps Substrate

**Multi-tenant SaaS platform for managing home server appliances**

> LLM-powered customer support + Ansible automation for family IT infrastructure

---

## 🎯 What is this?

AIOps Substrate is a **cloud-managed home appliance platform** that provides essential IT services for families:

- **DNS Server** (ad-blocking, local domain resolution)
- **File Sharing** (Samba/NAS)
- **Mail Relay** (Postfix)
- **PKI/Certificates** (Step-CA)

**The Innovation:** Customers interact with an LLM chatbot that translates natural language requests into Ansible playbooks, automatically configuring their home appliance.

### Example User Interaction

```
Customer: "Add user John to my file share"
         ↓
Backend LLM: Parses intent → generates Ansible playbook
         ↓
Ansible: SSHs to home appliance → creates user → configures Samba
         ↓
Customer: "John can now access \\appliance\family"
```

---

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────────┐
│  BACKEND (Cloud/Datacenter) - Multi-tenant SaaS      │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────┐ │
│  │ Management   │  │ LLM Agent    │  │ Ansible    │ │
│  │ API          │  │ (Ollama)     │  │ Control    │ │
│  │ (FastAPI)    │  │ Llama 3.2 3B │  │ Plane      │ │
│  └──────────────┘  └──────────────┘  └────────────┘ │
│         │                  │                │        │
│         ▼                  ▼                ▼        │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────┐ │
│  │ PostgreSQL   │  │ Redis        │  │ Prometheus │ │
│  └──────────────┘  └──────────────┘  └────────────┘ │
└──────────────────────────────────────────────────────┘
                         │
                    INTERNET
                         │
┌──────────────────────────────────────────────────────┐
│  HOME APPLIANCES (Raspberry Pi) - Per Customer       │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────┐ │
│  │ DNS Server   │  │ Samba/NAS    │  │ Mail Relay │ │
│  │ (dnsmasq)    │  │ (file share) │  │ (Postfix)  │ │
│  └──────────────┘  └──────────────┘  └────────────┘ │
│  ┌──────────────┐  ┌──────────────┐                 │
│  │ PKI/Certs    │  │ Agent        │                 │
│  │ (Step-CA)    │  │ (Phone Home) │                 │
│  └──────────────┘  └──────────────┘                 │
└──────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start

### Prerequisites

- **Docker Desktop** (20.10+)
- **Docker Compose** (v2+)
- **Make**
- **8GB RAM minimum** (16GB recommended)
- **20GB free disk space**

### Local Development (1 minute)

```bash
# 1. Clone repository
git clone https://github.com/your-org/suhlabs.git
cd suhlabs

# 2. Pull LLM model (one-time, ~2GB download)
make ollama-model

# 3. Start everything (backend + 3 simulated appliances)
make dev-up

# 4. Open in browser
open http://localhost:8000/docs  # API documentation
```

**You now have:**
- Backend API at `http://localhost:8000`
- 3 simulated appliances (001, 002, 003)
- PostgreSQL, Redis, Ollama LLM all running

---

## 📁 Project Structure

```
suhlabs/
├── backend/              # Multi-tenant SaaS backend
│   ├── api/             # FastAPI management API
│   ├── llm/             # Ollama LLM integration
│   ├── ansible/         # Playbooks for appliances
│   └── k8s/             # Kubernetes manifests
│
├── appliance/           # Raspberry Pi software
│   ├── agent/           # Phone-home agent
│   ├── services/        # DNS, Samba, Mail, PKI
│   ├── ui/              # Onboarding web interface
│   └── Dockerfile       # Container for testing
│
├── infra/               # Infrastructure as Code
│   ├── local/           # Docker Compose (dev)
│   ├── proxmox/         # Proxmox VMs (production)
│   └── aws/             # AWS EKS (scale)
│
├── docs/                # Documentation
│   ├── architecture.md
│   ├── performance-analysis.md
│   └── gaps.md
│
├── docker-compose.yml   # Local development stack
├── Makefile             # Build and deployment automation
└── README.md            # You are here
```

---

## 🛠️ Development Workflow

### Start Development Environment

```bash
make dev-up          # Start full stack
make dev-logs        # View logs
make dev-status      # Check service status
make dev-down        # Stop everything
```

### Work on Backend

```bash
make backend-up      # Start backend only
make backend-logs    # View API logs
make backend-shell   # Shell into API container
make test-backend    # Test API endpoints
```

### Work on Appliances

```bash
make appliances-up    # Start simulated appliances
make appliances-logs  # View appliance logs
make appliance-shell  # Shell into appliance (choose 1-3)
make test-appliance   # Test appliance services
```

### Testing

```bash
make test             # Run all tests
make test-integration # Test backend ↔ appliance communication
make test-llm         # Test LLM integration
```

### Code Quality

```bash
make lint            # Lint Python, Ansible, Terraform
make format          # Auto-format code
make validate        # Validate configurations
```

---

## 🎓 Tutorial: Add a New Feature

Let's add a new service configuration capability.

### 1. Update Backend API

```python
# backend/api/main.py
@app.post("/api/v1/appliance/{appliance_id}/service/dns")
async def configure_dns(appliance_id: str, zone: str, ip: str):
    # Generate Ansible playbook
    # Execute on appliance
    return {"status": "success"}
```

### 2. Create Ansible Playbook

```yaml
# backend/ansible/playbooks/dns.yml
- name: Add DNS record
  hosts: all
  tasks:
    - name: Add A record to dnsmasq
      lineinfile:
        path: /etc/dnsmasq.d/custom.conf
        line: "address=/{{ zone }}/{{ ip }}"
      notify: restart dnsmasq
```

### 3. Update Appliance Agent

```python
# appliance/agent/agent.py
async def apply_dns_config(self, config):
    # Write DNS config file
    # Reload dnsmasq
    pass
```

### 4. Test End-to-End

```bash
# Start stack
make dev-up

# Test API
curl -X POST http://localhost:8000/api/v1/appliance/001/service/dns \
  -H "Content-Type: application/json" \
  -d '{"zone": "test.local", "ip": "192.168.1.100"}'

# Verify on appliance
make appliance-shell  # Choose 1
cat /etc/dnsmasq.d/custom.conf
```

---

## 📊 Performance & Scaling

### Home Appliance (Raspberry Pi)

**Hardware:** Raspberry Pi 4 (4GB RAM), 64GB USB SSD

| Component | RAM | Storage | CPU |
|-----------|-----|---------|-----|
| OS + Services | 1-1.5 GB | 15 GB | 30-50% |
| Headroom | 2.5 GB | 49 GB | 50-70% |

**Verdict:** ✅ Runs comfortably on RPi 4 (4GB)

### Backend Scaling

| Customers | Monthly Cost | Infrastructure |
|-----------|--------------|----------------|
| 1-100 | $200-400 | Single server (Docker Compose) |
| 100-1k | $800-1,500 | 2-3 servers (k3s cluster) |
| 1k-10k | $5k-15k | Kubernetes cluster (Proxmox/AWS) |

**Cost per customer:** $20 → $1 as you scale

See [docs/performance-analysis.md](docs/performance-analysis.md) for detailed analysis.

---

## 🚢 Deployment

### Local (Development)

```bash
make dev-up
```

**Runs on:** Your laptop (Docker Desktop)
**Use for:** Development, testing, demos

### Proxmox (Production for 1-1000 customers)

```bash
cd infra/proxmox
terraform init
terraform apply

# Deploy backend services
make deploy-proxmox
```

**Runs on:** Your own hardware (k3s cluster)
**Use for:** Small-medium deployments, cost-conscious

### AWS (Scale for 1000+ customers)

```bash
cd infra/aws
terraform init
terraform apply

# Deploy to EKS
make deploy-aws
```

**Runs on:** AWS EKS (managed Kubernetes)
**Use for:** Large scale, global reach

---

## 🔒 Security

- **Authentication:** JWT tokens for API access
- **Secrets:** Vault or Kubernetes secrets
- **TLS:** All external communication encrypted
- **Appliance ↔ Backend:** mTLS or VPN tunnel
- **Updates:** Signed with cosign, verified on appliance
- **Firewall:** UFW on appliances, Security Groups on cloud

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests (`make test`)
5. Commit with descriptive message
6. Push to your fork
7. Open a Pull Request

---

## 📚 Documentation

- **[Architecture](docs/architecture.md)** - System design and components
- **[Performance Analysis](docs/performance-analysis.md)** - Detailed resource requirements
- **[Known Gaps](docs/gaps.md)** - Features to be implemented
- **[Backend README](backend/README.md)** - Backend development guide
- **[Appliance README](appliance/README.md)** - Appliance development guide

---

## 🎯 Roadmap

### Phase 1: MVP (Current)
- [x] Backend API (FastAPI)
- [x] LLM integration (Ollama)
- [x] Appliance agent
- [x] Docker Compose local dev
- [x] Basic Ansible playbooks
- [x] Performance analysis

### Phase 2: Beta (Next 3 months)
- [ ] Complete all service integrations (DNS, Samba, Mail, PKI)
- [ ] Web UI for customers
- [ ] Database schema and migrations
- [ ] Prometheus monitoring
- [ ] Raspberry Pi image builder
- [ ] 10-50 beta testers

### Phase 3: Production (6-12 months)
- [ ] Proxmox deployment automation
- [ ] CI/CD pipeline
- [ ] Backup and recovery
- [ ] Customer billing integration
- [ ] 100-1000 customers

### Phase 4: Scale (Year 2+)
- [ ] AWS/EKS deployment
- [ ] Multi-region support
- [ ] Advanced LLM features
- [ ] Mobile app
- [ ] 1000+ customers

---

## 📜 License

[Your License Here]

---

## 🙏 Acknowledgments

- **Ollama** for local LLM inference
- **FastAPI** for excellent Python web framework
- **Raspberry Pi** for affordable hardware
- **Ansible** for automation capabilities

---

## 💬 Support

- **Issues:** [GitHub Issues](https://github.com/your-org/suhlabs/issues)
- **Discussions:** [GitHub Discussions](https://github.com/your-org/suhlabs/discussions)
- **Email:** support@yourdomain.com

---

**Made with ❤️ for families who need simple IT infrastructure**
