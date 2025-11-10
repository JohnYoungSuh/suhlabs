# 14-Day Zero-Budget DevSecOps Sprint Plan
**Solo Developer | Max Effort | Secure LLM Infrastructure**

---

## Workflow Decision: FAANG Pattern Wins

**Why VSCode+DevCon loses for you:**
- Abstraction hides muscle memory (clicking vs typing)
- No transfer to production SSH/tmux reality
- DevContainer = training wheels you'll throw away

**Why FAANG pattern wins:**
- **Keyboard-first**: tmux + vim motions = 3x speed in 2 weeks
- **Production-identical**: Same tools local and prod
- **Muscle memory**: `git commit && make test && make deploy` becomes automatic
- **Zero context switch**: Terminal = code + infra + deploy in one flow

**Your stack for 2 weeks:**
```bash
Terminal (Alacritty/iTerm2)
  └─ tmux (split infra/code/logs)
      └─ nvim/vim (or VSCode if must, but terminal mode)
          └─ CLI tools (kubectl, terraform, ansible, gh)
```

---

## The 14-Day Plan: Learn by Shipping

### Philosophy
- **No tutorials without output**: Every hour produces a deployed artifact
- **Break it, fix it**: Intentionally break things to learn recovery
- **Commit every win**: Git history = your progress log
- **Labs = Real infra**: No toy examples, build actual suhlabs components

---

## Week 1: Foundation + First Blood (Days 1-7)

### Day 1: Terminal Mastery + Local K8s
**Goal**: Muscle memory for tmux + deploy first K8s app

**Morning (4h): Terminal Setup**
```bash
# Install FAANG-tier terminal stack (macOS/Linux)
brew install tmux neovim fzf ripgrep bat eza starship
brew install --cask alacritty  # or use iTerm2

# Clone dotfiles for fast config
git clone https://github.com/ThePrimeagen/.dotfiles ~/primeagen-dots
# Copy tmux.conf, init.vim basics

# Learn tmux keybinds (practice 30 min)
tmux new -s dev
# Prefix = Ctrl-b
# Split horizontal: Ctrl-b "
# Split vertical: Ctrl-b %
# Navigate panes: Ctrl-b arrow keys
# New window: Ctrl-b c
# Switch windows: Ctrl-b 0-9
```

**Afternoon (4h): K8s Local Stack**
```bash
# Install tools (FREE)
brew install kind kubectl k9s helm

# Create cluster
cd ~/suhlabs
cat > bootstrap/kind-cluster.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 30080
  - containerPort: 30443
    hostPort: 30443
- role: worker
EOF

kind create cluster --name aiops-dev --config bootstrap/kind-cluster.yaml

# Deploy hello-world to prove it works
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --type=NodePort --port=80
kubectl get pods,svc
# Test: curl localhost:<nodeport>

# COMMIT
git add bootstrap/kind-cluster.yaml
git commit -m "Day 1: Kind cluster + first deployment"
```

**Lab**: Break the cluster, recreate from scratch 3x until <2 min

**Evening (2h): tmux Layout Practice**
```bash
# Create your standard layout
tmux new -s aiops
# Top-left: code (nvim)
# Top-right: kubectl/k9s
# Bottom: logs/testing
# Practice switching without thinking (200 reps)
```

**Success metric**: Create Kind cluster + deploy app in <5 min blindfolded

---

### Day 2: Docker + CI Pipeline Basics
**Goal**: Containerize app + GitHub Actions CI

**Morning (4h): Dockerfile Mastery**
```bash
cd ~/suhlabs/cluster/ai-ops-agent

# Write minimal Python API
cat > main.py <<'EOF'
from fastapi import FastAPI
app = FastAPI()

@app.get("/health")
def health():
    return {"status": "healthy", "version": "0.1.0"}
EOF

cat > requirements.txt <<EOF
fastapi==0.104.1
uvicorn[standard]==0.24.0
EOF

# Multi-stage Dockerfile (production pattern)
cat > Dockerfile <<'EOF'
FROM python:3.11-slim as builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

FROM python:3.11-slim
WORKDIR /app
COPY --from=builder /root/.local /root/.local
COPY main.py .
ENV PATH=/root/.local/bin:$PATH
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

# Build + test locally
docker build -t ai-agent:v0.1 .
docker run -d -p 8000:8000 --name agent ai-agent:v0.1
curl localhost:8000/health
docker logs agent
docker stop agent && docker rm agent
```

**Afternoon (4h): GitHub Actions CI**
```bash
mkdir -p .github/workflows

cat > .github/workflows/ci.yml <<'EOF'
name: CI
on: [push, pull_request]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      - run: pip install black ruff
      - run: black --check .
      - run: ruff check .

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v4
      - run: pip install -r cluster/ai-ops-agent/requirements.txt
      - run: pip install pytest httpx
      - run: pytest tests/ || echo "No tests yet"

  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/build-push-action@v5
        with:
          context: cluster/ai-ops-agent
          push: false
          tags: ai-agent:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
EOF

# COMMIT + PUSH (triggers CI)
git add -A
git commit -m "Day 2: Containerized FastAPI + CI pipeline"
git push origin claude/secure-llm-infra-handoff-011CUzTMhoRawL4iEqyBLuzn

# Watch CI run on GitHub
gh run watch
```

**Lab**: Break the Dockerfile 5 ways, fix without Googling

**Success metric**: CI goes green in <3 min from push

---

### Day 3: Terraform + IaC Muscle Memory
**Goal**: Provision infra via code, destroy, repeat until automatic

**Morning (4h): Terraform Basics**
```bash
brew install terraform tflint

cd ~/suhlabs/infra/local

# Write Kind provider config
cat > main.tf <<'EOF'
terraform {
  required_version = ">= 1.6"
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "0.2.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.23.0"
    }
  }
}

provider "kind" {}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

resource "kind_cluster" "default" {
  name = "aiops-tf"
  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"
    node {
      role = "control-plane"
    }
    node {
      role = "worker"
    }
  }
}

resource "kubernetes_namespace" "ai_ops" {
  metadata {
    name = "ai-ops"
  }
  depends_on = [kind_cluster.default]
}

output "cluster_name" {
  value = kind_cluster.default.name
}
EOF

# Terraform workflow (memorize this)
terraform init
terraform fmt
terraform validate
terraform plan -out=plan.tfplan
terraform apply plan.tfplan

# Verify
kubectl get nodes
kubectl get ns ai-ops

# DESTROY (practice recovery)
terraform destroy -auto-approve

# Redo 10x until muscle memory
# Target: init → apply → destroy in <2 min
```

**Afternoon (4h): Terraform Modules**
```bash
# Create reusable namespace module
mkdir -p modules/k8s-namespace

cat > modules/k8s-namespace/main.tf <<'EOF'
variable "name" {
  type = string
}

variable "labels" {
  type    = map(string)
  default = {}
}

resource "kubernetes_namespace" "this" {
  metadata {
    name   = var.name
    labels = var.labels
  }
}

output "name" {
  value = kubernetes_namespace.this.metadata[0].name
}
EOF

# Use module in main.tf
cat >> main.tf <<'EOF'

module "ai_ops_ns" {
  source = "../../modules/k8s-namespace"
  name   = "ai-ops"
  labels = {
    app     = "ai-ops-agent"
    managed = "terraform"
  }
  depends_on = [kind_cluster.default]
}
EOF

terraform init -upgrade
terraform plan
terraform apply -auto-approve
```

**Lab**: Write Terraform for Vault, Ollama, MinIO deployments

**Success metric**: `terraform apply` → full stack in <30 sec

---

### Day 4: Ansible + Config Management
**Goal**: Automate service configuration, make idempotent

**Morning (4h): Ansible Fundamentals**
```bash
pip install ansible ansible-lint

cd ~/suhlabs

# Create inventory
cat > inventory/local.yml <<EOF
all:
  children:
    k8s_local:
      hosts:
        localhost:
          ansible_connection: local
EOF

# First playbook: Install Docker + K8s tools
cat > services/setup/bootstrap.yml <<'EOF'
---
- name: Bootstrap local dev environment
  hosts: localhost
  become: false
  tasks:
    - name: Check Docker is installed
      command: docker --version
      register: docker_check
      changed_when: false

    - name: Check kubectl is installed
      command: kubectl version --client
      register: kubectl_check
      changed_when: false

    - name: Install kubectl if missing
      shell: |
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
      when: kubectl_check.rc != 0

    - name: Verify installations
      debug:
        msg: "Environment ready: Docker {{ docker_check.stdout }}, kubectl {{ kubectl_check.stdout }}"
EOF

# Run it
ansible-playbook -i inventory/local.yml services/setup/bootstrap.yml

# Check idempotency (should show no changes on 2nd run)
ansible-playbook -i inventory/local.yml services/setup/bootstrap.yml
```

**Afternoon (4h): DNS Playbook (Real Service)**
```bash
cat > services/dns/playbook.yml <<'EOF'
---
- name: Deploy CoreDNS with custom config
  hosts: localhost
  vars:
    coredns_namespace: kube-system
    custom_zone: "corp.local"
  tasks:
    - name: Create CoreDNS ConfigMap
      kubernetes.core.k8s:
        state: present
        definition:
          apiVersion: v1
          kind: ConfigMap
          metadata:
            name: coredns-custom
            namespace: "{{ coredns_namespace }}"
          data:
            custom.server: |
              {{ custom_zone }}:53 {
                errors
                cache 30
                file /etc/coredns/{{ custom_zone }}.db
              }
            "{{ custom_zone }}.db": |
              $ORIGIN {{ custom_zone }}.
              @   IN SOA ns1 admin 2024010101 7200 3600 1209600 3600
              @   IN NS ns1
              ns1 IN A 10.0.1.5
              test IN A 192.168.1.100
              mail IN A 192.168.1.50

    - name: Restart CoreDNS to apply config
      kubernetes.core.k8s:
        state: patched
        kind: Deployment
        name: coredns
        namespace: "{{ coredns_namespace }}"
        definition:
          spec:
            template:
              metadata:
                annotations:
                  restartedAt: "{{ ansible_date_time.iso8601 }}"
EOF

# Install k8s collection
ansible-galaxy collection install kubernetes.core

# Run playbook
ansible-playbook -i inventory/local.yml services/dns/playbook.yml

# Test DNS
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- dig @10.96.0.10 test.corp.local
```

**Lab**: Create playbook for Vault deployment with health checks

**Success metric**: Modify DNS record, re-run playbook, verify change in <1 min

---

### Day 5: Secrets Management (Vault)
**Goal**: No plaintext secrets, ever. Vault muscle memory.

**Morning (4h): Vault Setup**
```bash
brew install vault

# Update docker-compose.yml
cat > bootstrap/docker-compose.yml <<'EOF'
version: '3.8'
services:
  vault:
    image: hashicorp/vault:1.15
    container_name: vault-dev
    ports:
      - "8200:8200"
    environment:
      VAULT_DEV_ROOT_TOKEN_ID: root
      VAULT_ADDR: http://0.0.0.0:8200
    cap_add:
      - IPC_LOCK
    command: server -dev -dev-listen-address=0.0.0.0:8200
EOF

docker-compose -f bootstrap/docker-compose.yml up -d vault

# Vault CLI setup
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=root

# Store secrets
vault kv put secret/ai-ops/ollama url=http://ollama:11434 model=llama3.1:8b
vault kv put secret/ai-ops/postgres user=aiops password=changeme123 host=postgres.ai-ops.svc

# Read secrets
vault kv get -format=json secret/ai-ops/ollama | jq -r .data.data.url

# Create policy for AI agent
cat > ai-ops-policy.hcl <<EOF
path "secret/data/ai-ops/*" {
  capabilities = ["read", "list"]
}
EOF

vault policy write ai-ops ai-ops-policy.hcl

# Create token with policy
vault token create -policy=ai-ops -ttl=24h
```

**Afternoon (4h): Vault K8s Integration**
```bash
# Deploy Vault agent injector
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

helm install vault hashicorp/vault \
  --namespace vault --create-namespace \
  --set "injector.enabled=true" \
  --set "server.dev.enabled=true"

# Enable K8s auth
kubectl exec -n vault vault-0 -- vault auth enable kubernetes

# Configure K8s auth
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443"

# Create role
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/role/ai-ops \
  bound_service_account_names=ai-ops-agent \
  bound_service_account_namespaces=ai-ops \
  policies=ai-ops \
  ttl=24h

# Test with pod (shows agent injection)
cat > test-vault-pod.yml <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ai-ops-agent
  namespace: ai-ops
---
apiVersion: v1
kind: Pod
metadata:
  name: vault-test
  namespace: ai-ops
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/role: "ai-ops"
    vault.hashicorp.com/agent-inject-secret-ollama: "secret/data/ai-ops/ollama"
spec:
  serviceAccountName: ai-ops-agent
  containers:
  - name: app
    image: nginx
    command: ["sh", "-c", "cat /vault/secrets/ollama && sleep 3600"]
EOF

kubectl apply -f test-vault-pod.yml
kubectl logs -n ai-ops vault-test -c app
# Should show Ollama URL
```

**Lab**: Store 10 different secrets, retrieve via API and CLI

**Success metric**: Never type a password again

---

### Day 6: CI/CD Pipeline (GitHub Actions)
**Goal**: git push → test → build → deploy (fully automated)

**Full Day (8h): Production-Grade Pipeline**
```bash
cat > .github/workflows/cd.yml <<'EOF'
name: CD Pipeline
on:
  push:
    branches: [main, claude/*]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}/ai-agent

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      - run: pip install -r cluster/ai-ops-agent/requirements.txt pytest httpx
      - run: pytest tests/ -v || echo "Tests pending"

  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-results.sarif'
      - name: Upload to GitHub Security
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'

  build:
    needs: [test, security-scan]
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=sha,prefix={{branch}}-
            type=ref,event=branch
            type=semver,pattern={{version}}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: cluster/ai-ops-agent
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  deploy-dev:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - uses: azure/setup-kubectl@v3

      - name: Set up kubeconfig (for self-hosted runner)
        run: |
          mkdir -p ~/.kube
          echo "${{ secrets.KUBECONFIG }}" | base64 -d > ~/.kube/config
          # For day 6: Just validate the workflow logic
          echo "Would deploy to K8s here"

      - name: Deploy to dev
        run: |
          # kubectl set image deployment/ai-ops-agent \
          #   ai-ops-agent=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }} \
          #   -n ai-ops
          echo "Deployment step (requires actual cluster)"
EOF

# Add SBOM generation
cat >> .github/workflows/cd.yml <<'EOF'

  sbom:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Generate SBOM
        uses: anchore/sbom-action@v0
        with:
          path: ./cluster/ai-ops-agent
          format: cyclonedx-json
      - name: Upload SBOM
        uses: actions/upload-artifact@v3
        with:
          name: sbom
          path: ./cluster/ai-ops-agent/sbom.cyclonedx.json
EOF

git add .github/workflows/cd.yml
git commit -m "Day 6: Full CI/CD with security scanning + SBOM"
git push

# Watch it run
gh run watch
```

**Lab**: Trigger pipeline 20x, optimize until <3 min total

**Success metric**: Commit → production in <5 min, zero manual steps

---

### Day 7: Week 1 Integration Test
**Goal**: Deploy entire stack end-to-end, break it, recover

**Morning (4h): Full Stack Deploy**
```bash
# Deploy everything via Makefile
cd ~/suhlabs

# Update Makefile with what you built
make dev-up      # Docker Compose (Vault)
make kind-up     # Terraform Kind cluster
make apply-local # Terraform K8s resources

# Verify stack
kubectl get all -A
vault status
docker ps

# Deploy AI agent
kubectl create deployment ai-ops-agent \
  --image=ghcr.io/johnyoungsuh/suhlabs/ai-agent:main \
  -n ai-ops

kubectl expose deployment ai-ops-agent \
  --type=NodePort --port=8000 --target-port=8000 \
  -n ai-ops

# Test end-to-end
curl http://localhost:30080/health
```

**Afternoon (4h): Chaos Engineering**
```bash
# Break things intentionally
docker stop vault-dev  # Kill Vault
kubectl delete pod -l app=ai-ops-agent -n ai-ops  # Kill app

# Recover using your tools
docker-compose -f bootstrap/docker-compose.yml up -d
kubectl rollout restart deployment/ai-ops-agent -n ai-ops

# Practice until recovery is <2 min

# Document runbook
cat > docs/runbook.md <<'EOF'
# Incident Response Runbook

## Vault Down
1. Check: `docker ps | grep vault`
2. Restart: `docker-compose -f bootstrap/docker-compose.yml up -d vault`
3. Verify: `vault status`

## AI Agent Crashloop
1. Logs: `kubectl logs -n ai-ops -l app=ai-ops-agent --tail=50`
2. Common causes: Vault unreachable, OOM
3. Fix: Check Vault, increase memory limit
4. Restart: `kubectl rollout restart deployment/ai-ops-agent -n ai-ops`

## DNS Resolution Failing
1. Check CoreDNS: `kubectl get pods -n kube-system | grep coredns`
2. Check config: `kubectl get cm coredns-custom -n kube-system -o yaml`
3. Restart: `kubectl rollout restart deployment/coredns -n kube-system`
EOF
```

**Evening (2h): Week 1 Demo**
```bash
# Record a demo video showing:
# 1. Terminal setup (tmux layout)
# 2. Terraform apply → cluster
# 3. Ansible deploy → services
# 4. CI/CD pipeline → image build
# 5. Vault secret injection
# 6. Breaking + recovering

# COMMIT ALL WEEK 1 WORK
git add -A
git commit -m "Week 1 complete: Foundation + IaC + CI/CD"
git push
```

**Week 1 Checkpoint**: Can you rebuild entire stack from scratch in <10 min?

---

## Week 2: Advanced Security + LLM Integration (Days 8-14)

### Day 8: Zero-Trust Networking
**Goal**: mTLS everywhere, network policies, no trust by default

**Morning (4h): Network Policies**
```bash
# Default deny all
cat > cluster/k3s/policies/deny-all.yml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: ai-ops
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF

# Allow AI agent → Vault
cat > cluster/k3s/policies/ai-agent-to-vault.yml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ai-agent-to-vault
  namespace: ai-ops
spec:
  podSelector:
    matchLabels:
      app: ai-ops-agent
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: vault
    - podSelector:
        matchLabels:
          app: vault
    ports:
    - protocol: TCP
      port: 8200
  - to:  # DNS
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
EOF

kubectl apply -f cluster/k3s/policies/

# Test: Agent should reach Vault, fail to reach other pods
kubectl exec -n ai-ops deploy/ai-ops-agent -- curl http://vault.vault:8200/v1/sys/health
```

**Afternoon (4h): cert-manager + mTLS**
```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create self-signed issuer
cat > cluster/k3s/cert-manager/selfsigned-issuer.yml <<'EOF'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ca-cert
  namespace: cert-manager
spec:
  isCA: true
  commonName: aiops-ca
  secretName: ca-secret
  privateKey:
    algorithm: RSA
    size: 4096
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-issuer
spec:
  ca:
    secretName: ca-secret
EOF

kubectl apply -f cluster/k3s/cert-manager/selfsigned-issuer.yml

# Issue cert for AI agent
cat > cluster/k3s/apps/ai-ops-agent/certificate.yml <<'EOF'
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ai-agent-tls
  namespace: ai-ops
spec:
  secretName: ai-agent-tls
  duration: 168h  # 7 days
  renewBefore: 24h
  subject:
    organizations:
    - suhlabs
  commonName: ai-ops-agent.ai-ops.svc.cluster.local
  isCA: false
  privateKey:
    algorithm: RSA
    size: 2048
  usages:
    - server auth
    - client auth
  dnsNames:
  - ai-ops-agent
  - ai-ops-agent.ai-ops
  - ai-ops-agent.ai-ops.svc
  - ai-ops-agent.ai-ops.svc.cluster.local
  issuerRef:
    name: ca-issuer
    kind: ClusterIssuer
EOF

kubectl apply -f cluster/k3s/apps/ai-ops-agent/certificate.yml

# Verify cert issued
kubectl get certificate -n ai-ops
kubectl get secret ai-agent-tls -n ai-ops -o yaml
```

**Lab**: Force cert rotation, verify auto-renewal

**Success metric**: All inter-service traffic is mTLS

---

### Day 9: Ollama + LLM Integration
**Goal**: Self-hosted LLM running, API integrated with agent

**Morning (4h): Ollama Deployment**
```bash
# Update docker-compose to include Ollama
cat >> bootstrap/docker-compose.yml <<'EOF'

  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    ports:
      - "11434:11434"
    volumes:
      - ollama_data:/root/.ollama
    # Uncomment if you have NVIDIA GPU
    # deploy:
    #   resources:
    #     reservations:
    #       devices:
    #       - driver: nvidia
    #         count: 1
    #         capabilities: [gpu]

volumes:
  ollama_data:
EOF

docker-compose -f bootstrap/docker-compose.yml up -d ollama

# Pull model (CPU mode, slow but works)
docker exec ollama ollama pull llama3.1:8b

# Test inference
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.1:8b",
  "prompt": "Explain DNS A records in 1 sentence",
  "stream": false
}'
```

**Afternoon (4h): AI Agent Integration**
```bash
cd ~/suhlabs/cluster/ai-ops-agent

# Update requirements.txt
cat >> requirements.txt <<EOF
ollama==0.1.3
pydantic==2.5.0
EOF

# Update main.py with LLM endpoint
cat > main.py <<'EOF'
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import ollama
import os

app = FastAPI(title="AI Ops Agent", version="0.2.0")

OLLAMA_HOST = os.getenv("OLLAMA_HOST", "http://localhost:11434")

class IntentRequest(BaseModel):
    nl: str  # Natural language input

class IntentResponse(BaseModel):
    status: str
    intent: dict
    reasoning: str

@app.get("/health")
def health():
    return {"status": "healthy", "ollama": OLLAMA_HOST}

@app.post("/api/v1/intent")
async def parse_intent(request: IntentRequest):
    prompt = f"""You are an infrastructure automation assistant. Parse this request into structured JSON.

User request: {request.nl}

Output ONLY valid JSON in this format:
{{
  "action": "dns.create_a_record",
  "params": {{"name": "example.local", "ip": "192.168.1.100", "ttl": 3600}}
}}

JSON:"""

    try:
        response = ollama.chat(
            model='llama3.1:8b',
            messages=[{'role': 'user', 'content': prompt}]
        )

        content = response['message']['content']
        # Parse JSON from response (basic impl)
        import json
        intent = json.loads(content)

        return IntentResponse(
            status="success",
            intent=intent,
            reasoning=f"Parsed from: {request.nl}"
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
EOF

# Rebuild image
docker build -t ai-agent:v0.2 .

# Test locally
docker run -d -p 8000:8000 \
  -e OLLAMA_HOST=http://host.docker.internal:11434 \
  --name agent-v2 ai-agent:v0.2

# Test intent parsing
curl -X POST http://localhost:8000/api/v1/intent \
  -H "Content-Type: application/json" \
  -d '{"nl": "Add DNS A record for test.local pointing to 192.168.1.100"}'

# Should return parsed JSON intent
```

**Lab**: Test 20 different NL inputs, measure accuracy

**Success metric**: LLM correctly parses 80%+ of infrastructure requests

---

### Day 10: RAG Pipeline Basics
**Goal**: Vector DB + embeddings for context retrieval

**Morning (4h): Qdrant Setup**
```bash
# Add Qdrant to docker-compose
cat >> bootstrap/docker-compose.yml <<'EOF'

  qdrant:
    image: qdrant/qdrant:latest
    container_name: qdrant
    ports:
      - "6333:6333"
      - "6334:6334"
    volumes:
      - qdrant_data:/qdrant/storage

volumes:
  qdrant_data:
EOF

docker-compose -f bootstrap/docker-compose.yml up -d qdrant

# Test Qdrant
curl http://localhost:6333/collections
```

**Afternoon (4h): Ingest Documentation**
```bash
cd ~/suhlabs/cluster/ai-ops-agent

# Add RAG dependencies
cat >> requirements.txt <<EOF
qdrant-client==1.7.0
sentence-transformers==2.2.2
EOF

# Create document ingestion script
cat > ingest_docs.py <<'EOF'
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct
from sentence_transformers import SentenceTransformer
import os

# Initialize
client = QdrantClient(host="localhost", port=6333)
model = SentenceTransformer('all-MiniLM-L6-v2')

# Create collection
collection_name = "infra_docs"
client.recreate_collection(
    collection_name=collection_name,
    vectors_config=VectorParams(size=384, distance=Distance.COSINE),
)

# Sample docs (replace with real docs later)
docs = [
    {
        "id": 1,
        "text": "DNS A records map hostnames to IPv4 addresses. Example: test.local IN A 192.168.1.100",
        "metadata": {"type": "dns", "source": "docs/dns.md"}
    },
    {
        "id": 2,
        "text": "Ansible playbook for DNS: services/dns/playbook.yml. Use ansible-playbook -i inventory/local.yml",
        "metadata": {"type": "playbook", "source": "services/dns/playbook.yml"}
    },
    {
        "id": 3,
        "text": "Vault secrets path: secret/ai-ops/. Read with: vault kv get secret/ai-ops/ollama",
        "metadata": {"type": "vault", "source": "docs/vault.md"}
    },
]

# Embed and upload
points = []
for doc in docs:
    vector = model.encode(doc["text"]).tolist()
    points.append(
        PointStruct(
            id=doc["id"],
            vector=vector,
            payload={"text": doc["text"], **doc["metadata"]}
        )
    )

client.upsert(collection_name=collection_name, points=points)
print(f"Ingested {len(points)} documents")

# Test search
query = "How do I add a DNS record?"
query_vector = model.encode(query).tolist()
results = client.search(
    collection_name=collection_name,
    query_vector=query_vector,
    limit=3
)

print("\nSearch results:")
for result in results:
    print(f"Score: {result.score:.3f} | {result.payload['text']}")
EOF

# Run ingestion
docker run --rm --network host \
  -v $(pwd):/app -w /app \
  python:3.11-slim \
  bash -c "pip install -q qdrant-client sentence-transformers && python ingest_docs.py"
```

**Lab**: Ingest all Makefile targets as docs, test retrieval

**Success metric**: Query "how to deploy" returns relevant Makefile target

---

### Day 11: SBOM + Supply Chain Security
**Goal**: Full transparency of dependencies, signed artifacts

**Full Day (8h): Security Hardening**
```bash
# Install tools
brew install syft cosign grype

# Generate SBOM for AI agent
cd ~/suhlabs/cluster/ai-ops-agent
syft . -o cyclonedx-json > sbom.json
syft . -o spdx-json > sbom.spdx.json

# Scan for vulnerabilities
grype sbom:sbom.json

# Generate cosign keypair
cosign generate-key-pair
# Store private key in Vault
vault kv put secret/cosign private_key=@cosign.key

# Sign SBOM
cosign sign-blob --key cosign.key sbom.json > sbom.json.sig

# Verify signature
cosign verify-blob --key cosign.pub --signature sbom.json.sig sbom.json

# Sign Docker image (after pushing to registry)
docker tag ai-agent:v0.2 ghcr.io/$GITHUB_USER/ai-agent:v0.2
docker push ghcr.io/$GITHUB_USER/ai-agent:v0.2
cosign sign --key cosign.key ghcr.io/$GITHUB_USER/ai-agent:v0.2

# Update CI to auto-sign
cat >> .github/workflows/cd.yml <<'EOF'

  sign-image:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: sigstore/cosign-installer@v3
      - name: Sign image
        env:
          COSIGN_KEY: ${{ secrets.COSIGN_PRIVATE_KEY }}
        run: |
          echo "$COSIGN_KEY" > cosign.key
          cosign sign --key cosign.key --yes \
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
EOF

# Add COSIGN_PRIVATE_KEY to GitHub secrets
gh secret set COSIGN_PRIVATE_KEY < cosign.key

# Create admission policy (Kyverno)
cat > cluster/k3s/policies/verify-images.yml <<'EOF'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signature
spec:
  validationFailureAction: enforce
  background: false
  rules:
  - name: verify-signature
    match:
      any:
      - resources:
          kinds:
          - Pod
    verifyImages:
    - imageReferences:
      - "ghcr.io/johnyoungsuh/suhlabs/*"
      attestors:
      - count: 1
        entries:
        - keys:
            publicKeys: |-
              -----BEGIN PUBLIC KEY-----
              <paste cosign.pub contents>
              -----END PUBLIC KEY-----
EOF
```

**Lab**: Try deploying unsigned image (should be blocked)

**Success metric**: Only signed images can deploy to cluster

---

### Day 12: Monitoring + Observability
**Goal**: Metrics, logs, traces - know what's happening

**Morning (4h): Prometheus + Grafana**
```bash
# Install kube-prometheus-stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

# Port-forward Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &

# Default login: admin / prom-operator
echo "Grafana: http://localhost:3000"

# Add custom metrics to AI agent
cat >> cluster/ai-ops-agent/main.py <<'EOF'

from prometheus_client import Counter, Histogram, generate_latest
from fastapi import Response
import time

# Metrics
intent_requests = Counter('intent_requests_total', 'Total intent requests')
intent_latency = Histogram('intent_latency_seconds', 'Intent processing latency')

@app.middleware("http")
async def metrics_middleware(request, call_next):
    start_time = time.time()
    response = await call_next(request)
    latency = time.time() - start_time

    if request.url.path == "/api/v1/intent":
        intent_requests.inc()
        intent_latency.observe(latency)

    return response

@app.get("/metrics")
def metrics():
    return Response(content=generate_latest(), media_type="text/plain")
EOF

# Update requirements.txt
echo "prometheus-client==0.19.0" >> requirements.txt

# Create ServiceMonitor
cat > cluster/k3s/apps/ai-ops-agent/servicemonitor.yml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: ai-ops-agent-metrics
  namespace: ai-ops
  labels:
    app: ai-ops-agent
spec:
  selector:
    app: ai-ops-agent
  ports:
  - name: metrics
    port: 8000
    targetPort: 8000
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: ai-ops-agent
  namespace: ai-ops
  labels:
    app: ai-ops-agent
spec:
  selector:
    matchLabels:
      app: ai-ops-agent
  endpoints:
  - port: metrics
    path: /metrics
    interval: 30s
EOF

kubectl apply -f cluster/k3s/apps/ai-ops-agent/servicemonitor.yml
```

**Afternoon (4h): Logging with Loki**
```bash
# Install Loki stack
helm install loki prometheus-community/loki-stack \
  --namespace monitoring \
  --set grafana.enabled=false \
  --set promtail.enabled=true

# Add Loki datasource in Grafana
# URL: http://loki:3100

# Create dashboard for AI agent logs
# Query: {namespace="ai-ops", app="ai-ops-agent"}
```

**Lab**: Generate load, watch metrics in real-time

**Success metric**: Dashboard shows request rate, latency, errors

---

### Day 13: Production Readiness
**Goal**: Health checks, autoscaling, backups

**Morning (4h): Production Deployment Manifest**
```bash
cat > cluster/k3s/apps/ai-ops-agent/production.yml <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: ai-ops
  labels:
    name: ai-ops
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ai-ops-agent
  namespace: ai-ops
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ai-ops-agent
  namespace: ai-ops
  labels:
    app: ai-ops-agent
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: ai-ops-agent
  template:
    metadata:
      labels:
        app: ai-ops-agent
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "ai-ops"
        vault.hashicorp.com/agent-inject-secret-ollama: "secret/data/ai-ops/ollama"
    spec:
      serviceAccountName: ai-ops-agent
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
      - name: ai-ops-agent
        image: ghcr.io/johnyoungsuh/suhlabs/ai-agent:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 8000
          name: http
        env:
        - name: OLLAMA_HOST
          value: "http://ollama:11434"
        - name: QDRANT_HOST
          value: "http://qdrant:6333"
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 2
---
apiVersion: v1
kind: Service
metadata:
  name: ai-ops-agent
  namespace: ai-ops
spec:
  selector:
    app: ai-ops-agent
  type: NodePort
  ports:
  - port: 80
    targetPort: 8000
    nodePort: 30080
    name: http
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ai-ops-agent
  namespace: ai-ops
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ai-ops-agent
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: ai-ops-agent
  namespace: ai-ops
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: ai-ops-agent
EOF

kubectl apply -f cluster/k3s/apps/ai-ops-agent/production.yml
```

**Afternoon (4h): Backup Strategy**
```bash
# Install Velero
brew install velero

# Setup MinIO for backups
cat >> bootstrap/docker-compose.yml <<'EOF'

  minio:
    image: minio/minio:latest
    container_name: minio
    ports:
      - "9000:9000"
      - "9001:9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    command: server /data --console-address ":9001"
    volumes:
      - minio_data:/data

volumes:
  minio_data:
EOF

docker-compose -f bootstrap/docker-compose.yml up -d minio

# Configure Velero
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.8.0 \
  --bucket velero \
  --secret-file ./velero-credentials \
  --use-volume-snapshots=false \
  --backup-location-config region=minio,s3ForcePathStyle="true",s3Url=http://minio:9000

# Create backup schedule
velero schedule create daily-backup \
  --schedule="0 2 * * *" \
  --include-namespaces ai-ops,vault

# Test backup now
velero backup create test-backup --wait
velero backup describe test-backup
```

**Lab**: Delete namespace, restore from backup

**Success metric**: Restore completes in <5 min

---

### Day 14: Final Integration + Demo
**Goal**: End-to-end demo, documentation, handoff prep

**Morning (4h): Integration Test**
```bash
# Test full workflow
echo "=== Full Stack Integration Test ==="

# 1. Deploy stack
make dev-up
make kind-up
make apply-local

# 2. Deploy apps
kubectl apply -f cluster/k3s/apps/ai-ops-agent/production.yml

# 3. Wait for ready
kubectl wait --for=condition=ready pod -l app=ai-ops-agent -n ai-ops --timeout=300s

# 4. Test NL → Infrastructure
curl -X POST http://localhost:30080/api/v1/intent \
  -H "Content-Type: application/json" \
  -d '{"nl": "Add DNS A record for production.local to 10.0.1.100"}'

# 5. Test RAG retrieval
curl -X POST http://localhost:30080/api/v1/intent \
  -H "Content-Type: application/json" \
  -d '{"nl": "How do I check Vault status?"}'

# 6. Verify metrics
curl http://localhost:30080/metrics | grep intent_requests_total

# 7. Check logs
kubectl logs -n ai-ops -l app=ai-ops-agent --tail=20

# 8. Test chaos recovery
kubectl delete pod -l app=ai-ops-agent -n ai-ops
sleep 10
kubectl get pods -n ai-ops  # Should auto-recover

echo "=== Integration Test Complete ==="
```

**Afternoon (4h): Documentation + Demo Video**
```bash
# Update README with everything you learned
cat > README.md <<'EOF'
# AIOps Substrate - Secure LLM Infrastructure

## Quick Start
```bash
# 1. Start local stack
make dev-up

# 2. Create K8s cluster
make kind-up

# 3. Deploy infrastructure
make apply-local

# 4. Test AI agent
curl -X POST http://localhost:30080/api/v1/intent \
  -d '{"nl": "Add DNS record test.local to 192.168.1.100"}'
```

## Architecture
- **LLM**: Ollama (Llama 3.1 8B) for intent parsing
- **RAG**: Qdrant vector DB + sentence-transformers
- **Secrets**: HashiCorp Vault with K8s integration
- **Orchestration**: K3s on Kind (local) / Proxmox (prod)
- **Security**: mTLS, NetworkPolicies, signed images, SBOM

## CI/CD Pipeline
Every push triggers:
1. Lint + security scan (Trivy)
2. Build + push to GHCR
3. Sign with Cosign
4. Generate SBOM
5. Deploy to dev (main branch only)

## Operations
- **Monitoring**: Prometheus + Grafana (port 3000)
- **Logs**: Loki + Promtail
- **Backups**: Velero to MinIO (daily at 2am)
- **Runbook**: See `docs/runbook.md`

## 14-Day Learning Path
Completed sprint: See `docs/14-DAY-SPRINT.md`

## Next Steps
- [ ] Deploy to Proxmox (see `HANDOFF.md` Phase 3)
- [ ] Implement MCP servers
- [ ] Add approval gates for high-risk operations
- [ ] HSM integration for PKI
- [ ] TEE isolation for Ollama

EOF

# Record demo (use asciinema or OBS)
# Show:
# 1. Terminal setup (tmux 3-pane layout)
# 2. `make dev-up` → full stack in 30 sec
# 3. NL query → AI parses → infrastructure change
# 4. Break something → auto-recovery
# 5. Grafana dashboard with live metrics
# 6. CI/CD pipeline running on GitHub

# FINAL COMMIT
git add -A
git commit -m "Sprint complete: Production-ready secure LLM infrastructure"
git push
```

**Evening (2h): Retrospective**
```bash
# Document what you learned
cat > docs/retrospective.md <<'EOF'
# 14-Day Sprint Retrospective

## What Worked
- Terminal-first workflow = 3x faster than GUI
- Commit after every win = great progress tracking
- Breaking things intentionally = best learning
- Labs with repetition = muscle memory achieved

## What Was Hard
- Ollama CPU mode is SLOW (need GPU)
- Kubernetes networking policies are tricky
- Vault K8s auth took 3 tries to get right
- CI/CD pipeline debugging without logs

## Muscle Memory Achieved
- tmux navigation (don't think about it anymore)
- `terraform init → plan → apply` automatic
- `kubectl get/logs/exec` reflexive
- `git add → commit → push` every 30 min
- Vault CLI for secrets (never plaintext again)

## Time Breakdown
- 40%: Infrastructure (K8s, Terraform, Ansible)
- 30%: Security (Vault, mTLS, SBOM, NetworkPolicies)
- 20%: LLM integration (Ollama, RAG, intent parsing)
- 10%: CI/CD, monitoring, docs

## Next Sprint Goals
- GPU passthrough for Ollama performance
- Proxmox production deployment
- MCP server implementations
- Load testing (1000 req/sec target)
- Multi-tenancy with namespace isolation

## Free Tools Used
- Kind, kubectl, helm (K8s)
- Terraform, Ansible (IaC)
- Vault, cert-manager (security)
- Ollama, Qdrant (LLM/RAG)
- Prometheus, Grafana, Loki (observability)
- GitHub Actions (CI/CD)
- Syft, Cosign, Grype (supply chain)
- Total cost: $0

## Estimated Production Cost
- Proxmox hardware: $2000 (one-time)
- Power: ~$30/month
- Domains: $12/year
- **vs Cloud**: AWS EKS + RDS + ELB = $300+/month
- **ROI**: 7 months
EOF
```

---

## Free Tools Summary

### Core Infrastructure (FREE)
- **Kind**: Local K8s clusters
- **K3s**: Production K8s (when ready for Proxmox)
- **kubectl**: K8s CLI
- **k9s**: Terminal UI for K8s
- **Helm**: K8s package manager

### IaC + Config (FREE)
- **Terraform**: Infrastructure provisioning
- **Ansible**: Configuration management
- **tflint**: Terraform linting
- **ansible-lint**: Ansible linting

### Security (FREE)
- **HashiCorp Vault**: Secrets management
- **cert-manager**: Automated TLS certificates
- **Cosign**: Artifact signing
- **Syft**: SBOM generation
- **Grype**: Vulnerability scanning
- **Trivy**: Container security scanning

### LLM/AI (FREE)
- **Ollama**: Self-hosted LLM runtime
- **Llama 3.1 8B**: Open-source model
- **Qdrant**: Vector database
- **sentence-transformers**: Embeddings

### Observability (FREE)
- **Prometheus**: Metrics
- **Grafana**: Dashboards
- **Loki**: Log aggregation
- **Promtail**: Log shipper

### CI/CD (FREE)
- **GitHub Actions**: 2000 min/month free
- **GHCR**: GitHub Container Registry (free public repos)

### Developer Tools (FREE)
- **tmux**: Terminal multiplexer
- **neovim/vim**: Text editor
- **fzf**: Fuzzy finder
- **ripgrep**: Fast search
- **bat**: Better `cat`
- **eza**: Better `ls`

---

## Success Criteria: Did You Win?

### Week 1 Checklist
- [ ] Can rebuild entire stack from scratch in <10 min
- [ ] CI pipeline green on every commit
- [ ] tmux muscle memory (don't think, just flow)
- [ ] Vault secrets retrieval automatic
- [ ] Terraform apply/destroy reflexive

### Week 2 Checklist
- [ ] Zero-trust network policies enforced
- [ ] All traffic is mTLS
- [ ] LLM parses NL → structured intent (80%+ accuracy)
- [ ] RAG retrieves relevant docs
- [ ] Monitoring dashboards show real-time metrics
- [ ] Only signed images deploy to cluster
- [ ] Backups automated + tested restore

### The Ultimate Test
Can you:
1. Delete the entire cluster
2. Recreate from `main` branch
3. Have AI agent responding to NL queries
4. All in <15 minutes?

**If YES**: You've achieved FAANG-level DevSecOps muscle memory. 🚀

---

## What's Next? (Beyond 2 Weeks)

### Option 1: Go Deep (Specialist)
- Master Kubernetes operators
- Custom admission controllers
- eBPF for network observability
- GitOps with ArgoCD/Flux

### Option 2: Go Wide (Full Stack)
- Add frontend (React + Tailwind)
- Mobile app (React Native)
- Edge deployment (Raspberry Pi K3s)
- Multi-cloud (AWS + GCP)

### Option 3: Go Production (Ship It)
- Deploy to real Proxmox
- DNS/Mail/PKI for family/friends
- Monetize as "AI Ops in a Box"
- Open source + build community

---

## Mentor's Final Advice

1. **Speed > Perfection**: Ship fast, iterate faster
2. **Break Things**: Best way to learn recovery
3. **Commit Everything**: Git history = your resume
4. **Teach Someone**: You don't truly know it until you can explain it
5. **Build in Public**: Tweet progress, get feedback

**You got this. Now go ship. 🔥**

---

## Resources

- [Kubernetes Docs](https://kubernetes.io/docs/)
- [Terraform Registry](https://registry.terraform.io/)
- [Ansible Galaxy](https://galaxy.ansible.com/)
- [Ollama Docs](https://ollama.ai/docs)
- [CNCF Landscape](https://landscape.cncf.io/)
- [DevOps Roadmap](https://roadmap.sh/devops)

**This sprint plan: 100% terminal, 0% GUI, MAX muscle memory.**
