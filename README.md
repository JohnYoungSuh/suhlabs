# AIOps Substrate: Self-Hosted Secure LLM Infrastructure

Production-grade AI operations platform built with 100% open-source tools and zero cloud costs. A 14-day sprint implementing enterprise DevSecOps practices from first principles.

[![Status](https://img.shields.io/badge/Status-Days%201--6%20Complete-brightgreen)]()
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Infrastructure as Code](https://img.shields.io/badge/IaC-Terraform%20%7C%20Ansible-purple)]()
[![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-blue)]()

---

## 🎯 Project Overview

Building a self-hosted AI infrastructure platform with enterprise-grade security and automation:

- **Zero-touch certificate management** - Automated certificate issuance, renewal, and rotation
- **Infrastructure as Code** - 100% reproducible deployments using Terraform and Ansible
- **Production security** - Two-tier PKI, mTLS, HSM integration, and secret management
- **Self-hosted AI/LLM** - Own your data and infrastructure (Ollama, Qdrant)
- **Zero licensing costs** - Built entirely with open-source tools

## 📊 Current Status: Days 1-6 Complete ✅

### ✅ Day 1-3: Foundation & IaC
- Kubernetes cluster (Kind for local dev)
- Docker environment setup
- Infrastructure as Code patterns
- VS Code workspace configuration

### ✅ Day 4: Foundation Services
- **CoreDNS**: Custom DNS with corp.local zone
- **SoftHSM**: Software HSM for Vault auto-unseal
- **Vault PKI**: Two-tier CA hierarchy (Root + Intermediate)
  - Root CA: 10-year, 4096-bit (offline security)
  - Intermediate CA: 5-year, 2048-bit (online operations)
  - Three PKI roles: ai-ops-agent, kubernetes, cert-manager
- **Verification**: 33 automated tests

### ✅ Day 5: Cert-Manager Integration
- **Automated certificate issuance** from Vault PKI
- **Three ClusterIssuers** for different security zones
- **Certificate lifecycle management**: 30-day certs, auto-renew at 20 days
- **Zero-touch operations**: No manual certificate management
- **Comprehensive verification**: 9 test suites

### ✅ Day 6: CI/CD Pipeline (Just Completed!)
- **GitHub Actions CD pipeline**: Automated testing, building, and deployment
- **Security scanning**: Trivy filesystem and image vulnerability scanning
- **SBOM generation**: CycloneDX and SPDX formats for supply chain security
- **Container publishing**: Automated push to GitHub Container Registry
- **GitHub Security integration**: Vulnerability findings in Security tab
- **Pipeline duration**: ~9 minutes (with cache), 7 parallel jobs

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  AIOps Substrate Stack                   │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐ │
│  │  AI/LLM     │  │  Vector DB   │  │  AI Ops Agent  │ │
│  │  (Ollama)   │  │  (Qdrant)    │  │  (FastAPI)     │ │
│  └─────────────┘  └──────────────┘  └────────────────┘ │
│         ↓                ↓                    ↓          │
│  ┌──────────────────────────────────────────────────┐  │
│  │         Automatic Certificate Management         │  │
│  │         (cert-manager + Vault PKI)               │  │
│  └──────────────────────────────────────────────────┘  │
│         ↓                                                │
│  ┌─────────────────────────────────────────────────┐   │
│  │           Foundation Services Layer              │   │
│  │  ┌──────────┐  ┌────────┐  ┌──────────────────┐│   │
│  │  │ CoreDNS  │  │ Vault  │  │    SoftHSM       ││   │
│  │  │  (DNS)   │  │ (PKI)  │  │  (Auto-unseal)   ││   │
│  │  └──────────┘  └────────┘  └──────────────────┘│   │
│  └─────────────────────────────────────────────────┘   │
│         ↓                                                │
│  ┌─────────────────────────────────────────────────┐   │
│  │        Kubernetes Orchestration (Kind)          │   │
│  └─────────────────────────────────────────────────┘   │
│         ↓                                                │
│  ┌─────────────────────────────────────────────────┐   │
│  │    Infrastructure as Code (Terraform/Ansible)   │   │
│  └─────────────────────────────────────────────────┘   │
│         ↓                                                │
│  ┌─────────────────────────────────────────────────┐   │
│  │    CI/CD Pipeline (GitHub Actions)              │   │
│  │    • Security Scanning (Trivy)                  │   │
│  │    • SBOM Generation (Syft)                     │   │
│  │    • Automated Testing & Deployment             │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- Docker or Podman
- kubectl
- kind (Kubernetes in Docker)
- Terraform
- Ansible
- Vault CLI
- Make

### Setup

```bash
# 1. Clone the repository
git clone https://github.com/JohnYoungSuh/suhlabs.git
cd suhlabs

# 2. Open VS Code workspace
code suhlabs.code-workspace

# 3. Create Kind cluster
make kind-up

# 4. Deploy foundation services
cd cluster/foundation

# Deploy CoreDNS with custom DNS zone
cd coredns && ./deploy.sh && cd ..

# Deploy Vault with SoftHSM
cd softhsm && ./init-softhsm.sh && cd ..

# Initialize Vault PKI (Root + Intermediate CA)
cd vault-pki && ./init-vault-pki.sh && cd ..

# 5. Deploy cert-manager with Vault integration
cd cert-manager
export VAULT_TOKEN=<your-root-token>
./deploy.sh

# 6. Test automatic certificate issuance
kubectl apply -f test-certificate.yaml

# 7. Verify everything works
./verify-cert-manager.sh
```

## 🛠️ Tech Stack

### Infrastructure
- **Kubernetes**: Kind (local) → K3s (production on Proxmox)
- **Container Runtime**: Docker
- **Service Mesh**: (Coming: Istio with mTLS)

### Security
- **PKI**: HashiCorp Vault with two-tier CA
- **Certificate Management**: cert-manager (automated)
- **HSM**: SoftHSM (dev) → YubiHSM 2 (production)
- **mTLS**: Automatic certificate-based service auth
- **Secret Management**: Vault with Kubernetes integration

### Automation
- **IaC**: Terraform for infrastructure provisioning
- **Configuration Management**: Ansible for service deployment
- **CI/CD**: GitHub Actions with automated testing and deployment
- **Security Scanning**: Trivy for vulnerability detection
- **SBOM**: Syft/Anchore for Software Bill of Materials
- **Verification**: Bash scripts with comprehensive testing

### AI/ML (Coming)
- **LLM Runtime**: Ollama (self-hosted)
- **Vector Database**: Qdrant
- **Embeddings**: sentence-transformers
- **RAG Pipeline**: Custom implementation

### Observability (Coming)
- **Metrics**: Prometheus
- **Visualization**: Grafana
- **Logging**: Loki + Promtail
- **Tracing**: (TBD)

## 📁 Project Structure

```
suhlabs/
├── ansible/                    # Ansible automation
│   ├── playbooks/             # Verification playbooks
│   ├── inventory/             # Inventory definitions
│   └── README.md              # Ansible documentation
├── bootstrap/                  # Bootstrap configuration
│   ├── kind-cluster.yaml      # Kind cluster config
│   └── docker-compose.yml     # Local services
├── cluster/                    # Kubernetes resources
│   ├── foundation/            # Foundation services
│   │   ├── coredns/          # Custom DNS
│   │   ├── softhsm/          # HSM integration
│   │   ├── vault-pki/        # PKI infrastructure
│   │   └── cert-manager/     # Certificate automation ✨ NEW
│   └── ai-ops-agent/         # AI Ops Agent (coming)
├── docs/                       # Documentation
│   ├── DAY-4-COMPLETE.md      # Day 4 completion summary
│   ├── DAY-5-COMPLETE.md      # Day 5 completion summary
│   ├── DAY-6-COMPLETE.md      # Day 6 completion summary ✨ NEW
│   ├── CI-CD-PIPELINE.md      # CI/CD pipeline guide ✨ NEW
│   ├── lessons-learned.md     # Lessons and decisions
│   └── 14-DAY-SPRINT.md      # Sprint plan
├── infra/                      # Terraform infrastructure
│   ├── local/                 # Local development
│   └── proxmox/              # Production deployment
├── .github/workflows/          # CI/CD workflows ✨ NEW
│   ├── ci.yml                 # Basic CI workflow
│   └── cd.yml                 # Production CD pipeline ✨ NEW
├── Makefile                    # Common operations
├── suhlabs.code-workspace     # VS Code workspace
└── README.md                   # This file
```

## 📋 Day-by-Day Progress

### Week 1: Foundation + First Blood ✅

| Day | Focus | Status | Key Deliverables |
|-----|-------|--------|------------------|
| 1-3 | Terminal Setup + K8s + IaC | ✅ | Kind cluster, Terraform, Ansible, workspace |
| 4 | Foundation Services | ✅ | CoreDNS, SoftHSM, Vault PKI (2-tier CA) |
| 5 | Cert-Manager | ✅ | Automated certificate lifecycle management |
| 6 | CI/CD Pipeline | ✅ | GitHub Actions, security scanning, SBOM |
| 7 | Week 1 Integration | 🔄 Next | Full stack deploy end-to-end |

### Week 2: Advanced Security + LLM Integration 📅

| Day | Focus | Status | Key Deliverables |
|-----|-------|--------|------------------|
| 8 | Zero-Trust Networking | 📅 | mTLS, network policies |
| 9 | Ollama + LLM | 📅 | Self-hosted LLM, API integration |
| 10 | RAG Pipeline | 📅 | Vector DB, embeddings, retrieval |
| 11 | SBOM + Supply Chain | 📅 | Signed artifacts, vulnerability scanning |
| 12 | Monitoring | 📅 | Prometheus, Grafana, Loki |
| 13 | Production Ready | 📅 | Health checks, autoscaling, backups |
| 14 | Integration + Demo | 📅 | End-to-end demo, documentation |

## 🎓 Key Features & Learning Outcomes

### Zero-Touch Certificate Management
Every service gets automatically-issued, automatically-renewed certificates:

```yaml
# Define a certificate
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-app
spec:
  secretName: my-app-tls
  issuerRef:
    name: vault-issuer
    kind: ClusterIssuer
  commonName: my-app.corp.local
  duration: 720h        # 30 days
  renewBefore: 240h     # Renew 10 days before expiry
```

**Result**: Certificate issued in <30 seconds, renewed automatically at day 20.

### Two-Tier PKI Architecture
- **Root CA** (offline, air-gapped): 10-year lifetime, 4096-bit
- **Intermediate CA** (online, operational): 5-year lifetime, 2048-bit
- **Short-lived certificates**: 30-day lifetime (reduces blast radius)
- **Least privilege**: Separate PKI roles per service type

### Infrastructure as Code
Everything is version controlled and reproducible:

```bash
# Deploy entire stack from code
make dev-up        # Local services (Vault, etc.)
make kind-up       # Kubernetes cluster
make apply-local   # Apply all infrastructure

# Destroy and recreate in minutes
make kind-down && make kind-up
```

## 🔒 Security Highlights

- ✅ Two-tier PKI with offline Root CA
- ✅ Short-lived certificates (30 days)
- ✅ Automatic certificate rotation
- ✅ HSM integration for key protection
- ✅ Vault for secret management
- ✅ Separate PKI roles (least privilege)
- ✅ Automated security scanning (Trivy)
- ✅ SBOM generation for supply chain transparency
- ✅ CI/CD pipeline with GitHub Actions
- 🔄 mTLS between all services (coming Day 8)
- 🔄 Network policies (zero-trust) (coming Day 8)
- 🔄 Signed container images (coming Day 11)

## 📖 Documentation

Comprehensive documentation for each component:

- **[Foundation Services](cluster/foundation/README.md)** - CoreDNS, SoftHSM, Vault PKI
- **[Cert-Manager Guide](cluster/foundation/cert-manager/README.md)** - Certificate automation (400+ lines)
- **[CI/CD Pipeline Guide](docs/CI-CD-PIPELINE.md)** - GitHub Actions, security scanning, SBOM (500+ lines)
- **[Day 4 Complete](docs/DAY-4-COMPLETE.md)** - Foundation services summary
- **[Day 5 Complete](docs/DAY-5-COMPLETE.md)** - Cert-manager integration summary
- **[Day 6 Complete](docs/DAY-6-COMPLETE.md)** - CI/CD pipeline summary
- **[Lessons Learned](docs/lessons-learned.md)** - Decisions and rationale (620+ lines)
- **[14-Day Sprint Plan](docs/14-DAY-SPRINT.md)** - Complete roadmap
- **[Ansible README](ansible/README.md)** - Automation guide (70+ sections)

## 🧪 Testing & Verification

Every component has comprehensive verification:

```bash
# Verify foundation services (33 tests)
cd cluster/foundation
./verify-all.sh

# Verify cert-manager (9 test suites)
cd cluster/foundation/cert-manager
./verify-cert-manager.sh

# Verify Vault PKI (9 tests)
cd cluster/foundation/vault-pki
./verify-pki.sh
```

**Test Coverage:**
- CoreDNS: 7 tests (DNS resolution, pods, deployment)
- Vault: 9 tests (status, seal, PKI, service)
- SoftHSM: 3 tests (token, slots, configuration)
- Vault PKI: 9 tests (CA chain, roles, certificate issuance)
- cert-manager: 9 tests (pods, CRDs, issuers, certificates, renewal)
- **Total: 37 automated tests**

## 💡 Why This Project?

### The Problem
Most AI/LLM infrastructure tutorials:
- Rely on expensive cloud services ($$$)
- Use external CAs (no control)
- Have manual certificate management (error-prone)
- Skip production-grade security
- Are not reproducible (snowflake servers)

### The Solution
Build from first principles with:
- ✅ Zero cloud costs (self-hosted)
- ✅ Full PKI control (your CA, your rules)
- ✅ Zero-touch automation (no manual ops)
- ✅ Enterprise security patterns
- ✅ 100% reproducible (IaC)

## 🎯 Use Cases

1. **Learning DevSecOps**: Hands-on with PKI, Kubernetes, IaC
2. **Self-hosted AI**: Own your LLM infrastructure and data
3. **Homelab**: Production patterns on home hardware
4. **Cost savings**: Avoid $300+/month cloud bills
5. **Compliance**: Keep sensitive data on-premises

## 🚦 Getting Started Paths

### Path 1: Quick Demo (15 minutes)
```bash
# Just see what we've built
cd cluster/foundation/cert-manager
./verify-cert-manager.sh
```

### Path 2: Full Local Setup (1-2 hours)
Follow the [Quick Start](#-quick-start) guide above.

### Path 3: Production Deployment (Day 14+)
Deploy to Proxmox following the production guides (coming).

## 🤝 Contributing

This is a learning project and documentation contributions are welcome! Areas for contribution:

- 📝 Documentation improvements
- 🐛 Bug reports and fixes
- 💡 Architecture suggestions
- 🔒 Security enhancements
- 📊 Monitoring dashboards

## 📈 Stats

- **Lines of Code**: ~7,500+ (infrastructure + documentation + CI/CD)
- **Files Created**: 25+
- **Automated Tests**: 40+ (37 infrastructure + 3 application)
- **Documentation**: 3,500+ lines
- **Time Investment**: ~18 hours (Days 4-6)
- **CI/CD Pipeline**: ~9 minutes (cached)
- **Cloud Cost**: $0 💰

## 🗺️ Roadmap

### Short Term (Day 7)
- [x] GitHub Actions CI/CD pipeline
- [x] Security scanning (Trivy, Grype)
- [x] SBOM generation (Syft)
- [ ] Full stack integration testing
- [ ] Week 1 demo and documentation

### Medium Term (Days 8-12)
- [ ] mTLS between all services
- [ ] Deploy Ollama with LLM
- [ ] RAG pipeline with Qdrant
- [ ] Prometheus + Grafana monitoring

### Long Term (Days 13-14+)
- [ ] Production deployment to Proxmox
- [ ] High availability setup
- [ ] Disaster recovery procedures
- [ ] Performance optimization

## 📚 References

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [HashiCorp Vault](https://www.vaultproject.io/)
- [cert-manager](https://cert-manager.io/)
- [Terraform](https://www.terraform.io/)
- [Ansible](https://www.ansible.com/)
- [Kind](https://kind.sigs.k8s.io/)

## 📝 License

Apache 2.0 - See [LICENSE](LICENSE) file for details.

## 👤 Author

**John Young Suh**
- Building production-grade infrastructure from first principles
- Following a 14-day DevSecOps sprint
- Learning by shipping, documenting everything

---

**⭐ Star this repo if you're building similar infrastructure!**

**💬 Questions? Open an issue or discussion!**

---

*Last updated: Day 6 complete - Production CI/CD pipeline with security scanning and SBOM generation ✨*
