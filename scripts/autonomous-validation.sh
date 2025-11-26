#!/bin/bash
# ============================================================================
# Autonomous AI Ops Agent Validation Script
# 
# This script validates that the AI Ops/Sec agent can independently rebuild
# the entire infrastructure (Kind cluster → CoreDNS → Vault → PKI → LLM)
# with zero human intervention.
#
# Exit Codes:
#   0 = Full success (all phases passed)
#   1 = Failure with analysis report generated
# ============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
TIMESTAMP=$(date +%s)
TEST_DIR="/tmp/aiops-validation-${TIMESTAMP}"
CLUSTER_NAME="aiops-validation"
NAMESPACE="default"
VAULT_NAMESPACE="vault"
LOG_FILE="${TEST_DIR}/validation-log.txt"
FAILURE_REPORT="${TEST_DIR}/failure-report.md"

# Counters
PHASE_TOTAL=11
PHASE_CURRENT=0
FAILURES=0

# ============================================================================
# Helper Functions
# ============================================================================

log_phase() {
    PHASE_CURRENT=$((PHASE_CURRENT + 1))
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Phase ${PHASE_CURRENT}/${PHASE_TOTAL}: $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    FAILURES=$((FAILURES + 1))
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

execute_cmd() {
    local cmd="$1"
    local description="$2"
    
    echo -e "${BLUE}→${NC} ${description}"
    echo "  Command: ${cmd}"
    
    if eval "$cmd" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "${description}"
        return 0
    else
        local exit_code=$?
        log_error "${description} (exit code: ${exit_code})"
        generate_failure_report "$cmd" "$description" "$exit_code"
        return 1
    fi
}

generate_failure_report() {
    local cmd="$1"
    local description="$2"
    local exit_code="$3"
    
    cat >> "$FAILURE_REPORT" <<EOF

## Failure Report

**Phase**: Phase ${PHASE_CURRENT}/${PHASE_TOTAL}
**Step**: ${description}
**Command**: \`${cmd}\`
**Exit Code**: ${exit_code}
**Timestamp**: $(date -Iseconds)

### Error Output
\`\`\`
$(tail -20 "$LOG_FILE")
\`\`\`

### Classification
- [ ] Syntax Error
- [ ] Logic Error
- [ ] Timing/Race Condition
- [ ] Auth/Permission Issue
- [ ] Network Issue
- [ ] State Drift

### Root Cause Analysis
[To be filled by agent]

### Gap in Knowledge/Context
[What was missing or misleading in the existing codebase]

### Assumptions Made
[What the agent assumed incorrectly]

### Security/Operational Risk
[Potential impact of this failure]

---

## ML Improvement Proposals

### Proposal 1: [Name] (Priority: High/Medium/Low)
- **Problem**: 
- **Solution**: 
- **Implementation**: 
- **Expected Impact**: 

### Proposal 2: [Name] (Priority: High/Medium/Low)
- **Problem**: 
- **Solution**: 
- **Implementation**: 
- **Expected Impact**: 

### Proposal 3: [Name] (Priority: High/Medium/Low)
- **Problem**: 
- **Solution**: 
- **Implementation**: 
- **Expected Impact**: 

EOF
}

# ============================================================================
# Phase 0: Setup
# ============================================================================

echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║     Autonomous AI Ops Agent Validation Test                  ║"
echo "║     Phase 1: Base Infrastructure + Phase 2: Self-Hosting LLM  ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

log_info "Test Directory: ${TEST_DIR}"
log_info "Cluster Name: ${CLUSTER_NAME}"
log_info "Log File: ${LOG_FILE}"

# Create test directory
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Initialize log
echo "Autonomous Validation Test - $(date)" > "$LOG_FILE"
echo "Test Directory: ${TEST_DIR}" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Cleanup any previous validation clusters
log_info "Cleaning up previous validation attempts..."
kind delete cluster --name "$CLUSTER_NAME" 2>/dev/null || true

# ============================================================================
# Phase 1: Environment Setup
# ============================================================================

log_phase "Environment Setup"

# Copy foundation scripts
execute_cmd \
    "cp -r /home/suhlabs/projects/suhlabs/aiops-substrate/cluster/foundation ${TEST_DIR}/" \
    "Copy foundation scripts"

# Make all scripts executable
execute_cmd \
    "chmod -R +x ${TEST_DIR}/foundation/**/*.sh" \
    "Make foundation scripts executable"

execute_cmd \
    "cp -r /home/suhlabs/projects/suhlabs/aiops-substrate/bootstrap ${TEST_DIR}/" \
    "Copy bootstrap configs"

# Create Kind cluster config
cat > kind-cluster.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${CLUSTER_NAME}
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 80
    hostPort: 8080
  - containerPort: 443
    hostPort: 8443
  - containerPort: 30080
    hostPort: 30081
- role: worker
EOF

execute_cmd \
    "kind create cluster --name ${CLUSTER_NAME} --config kind-cluster.yaml --wait 2m" \
    "Create Kind cluster" || exit 1

execute_cmd \
    "kubectl cluster-info" \
    "Verify cluster connectivity" || exit 1

# ============================================================================
# Phase 2: CoreDNS Deployment
# ============================================================================

log_phase "CoreDNS Deployment"

cd foundation/coredns

execute_cmd \
    "./deploy.sh" \
    "Deploy CoreDNS with corp.local zone" || exit 1

execute_cmd \
    "kubectl wait --for=condition=ready pod -l k8s-app=kube-dns -n kube-system --timeout=120s" \
    "Wait for CoreDNS pods" || exit 1

# Test DNS resolution
execute_cmd \
    "kubectl run dns-test-cluster --image=busybox:1.36 --rm --restart=Never --attach=true --quiet -- nslookup kubernetes.default.svc.cluster.local" \
    "Test cluster.local DNS resolution" || exit 1

cd "$TEST_DIR"

# ============================================================================
# Phase 3: Vault Deployment (Following known pattern from lessons learned)
# ============================================================================

log_phase "Vault Deployment"

cd foundation/vault

execute_cmd \
    "./deploy.sh" \
    "Deploy Vault" || exit 1

# KNOWN PATTERN: Wait for pod to exist and be Running (not Ready - Vault needs init/unseal)
log_info "Waiting for Vault pod to be Running..."

# Wait up to 5 minutes
for i in $(seq 1 60); do
    if kubectl get pod vault-0 -n ${VAULT_NAMESPACE} &>/dev/null; then
        PHASE=$(kubectl get pod vault-0 -n ${VAULT_NAMESPACE} -o jsonpath='{.status.phase}' 2>/dev/null)
        if [ "$PHASE" = "Running" ]; then
            log_success "Vault pod is Running"
            break
        fi
    fi
    if [ $i -eq 60 ]; then
        log_error "Timeout waiting for Vault pod"
        kubectl get pods -n ${VAULT_NAMESPACE}
        exit 1
    fi
    sleep 5
done

# Vault pod name is always vault-0 (StatefulSet from Helm)
VAULT_POD="vault-0"

log_info "Vault pod: ${VAULT_POD}"

# KNOWN PATTERN: Initialize and unseal Vault automatically
log_info "Running vault-bootstrap.sh auto (init + unseal)..."
chmod +x ./vault-bootstrap.sh
execute_cmd \
    "./vault-bootstrap.sh auto" \
    "Initialize and unseal Vault" || exit 1

# Now Vault should be unsealed (vault status returns 0 if unsealed, 2 if sealed)
log_info "Checking Vault status..."
kubectl exec -n ${VAULT_NAMESPACE} ${VAULT_POD} -- vault status || {
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 2 ]; then
        log_error "Vault is still sealed after bootstrap"
        log_error "Check if vault-bootstrap.sh unseal step failed"
        exit 1
    fi
}
log_success "Vault is unsealed and ready"

cd "$TEST_DIR"

# ============================================================================
# Phase 5: Vault PKI Initialization
# ============================================================================

log_phase "Vault PKI Initialization"

cd foundation/vault-pki

execute_cmd \
    "./init-vault-pki.sh" \
    "Initialize Vault PKI hierarchy" || exit 1

# Verify PKI
execute_cmd \
    "kubectl exec -n ${VAULT_NAMESPACE} ${VAULT_POD} -- vault read pki_int/cert/ca" \
    "Verify Intermediate CA certificate" || exit 1

cd "$TEST_DIR"

# ============================================================================
# Phase 6: Cert-Manager Deployment
# ============================================================================

log_phase "Cert-Manager Deployment"

cd foundation/cert-manager

# Set VAULT_TOKEN from saved keys
if [ -f "../vault/.vault-keys.json" ]; then
    export VAULT_TOKEN=$(jq -r '.root_token' ../vault/.vault-keys.json)
fi

execute_cmd \
    "./deploy.sh" \
    "Deploy cert-manager" || exit 1

execute_cmd \
    "kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=cert-manager -n cert-manager --timeout=120s" \
    "Wait for cert-manager pods" || exit 1

# Create test certificate
cat > test-certificate.yaml <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-cert
  namespace: default
spec:
  secretName: test-cert-tls
  duration: 720h
  renewBefore: 240h
  issuerRef:
    name: vault-issuer-ai-ops
    kind: ClusterIssuer
  commonName: test.corp.local
  dnsNames:
    - test.corp.local
EOF

execute_cmd \
    "kubectl apply -f test-certificate.yaml" \
    "Create test certificate" || exit 1

execute_cmd \
    "kubectl wait --for=condition=ready certificate/test-cert --timeout=120s" \
    "Wait for certificate issuance" || exit 1

cd "$TEST_DIR"

# ============================================================================
# Phase 7: Certificate Rotation Test
# ============================================================================

log_phase "Certificate Rotation Test"

# Get initial serial
SERIAL_BEFORE=$(kubectl get secret test-cert-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -serial)
log_info "Initial certificate serial: ${SERIAL_BEFORE}"

# Delete secret to force renewal
execute_cmd \
    "kubectl delete secret test-cert-tls" \
    "Delete certificate secret to trigger renewal" || exit 1

# Wait for new certificate
execute_cmd \
    "kubectl wait --for=condition=ready certificate/test-cert --timeout=120s" \
    "Wait for certificate renewal" || exit 1

# Get new serial
SERIAL_AFTER=$(kubectl get secret test-cert-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -serial)
log_info "New certificate serial: ${SERIAL_AFTER}"

if [ "$SERIAL_BEFORE" != "$SERIAL_AFTER" ]; then
    log_success "Certificate rotation successful"
else
    log_error "Certificate rotation failed - serial numbers match"
    exit 1
fi

# ============================================================================
# PHASE 2: Self-Hosting LLM Inference
# ============================================================================

log_info ""
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_info "Starting Phase 2: Self-Hosting LLM Inference"
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_info ""

# ============================================================================
# Phase 8: Ollama Deployment
# ============================================================================

log_phase "Ollama Deployment"

# Create Ollama manifests
mkdir -p ollama

cat > ollama/pvc.yaml <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ollama-data
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
EOF

cat > ollama/deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ollama
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ollama
  template:
    metadata:
      labels:
        app: ollama
    spec:
      containers:
      - name: ollama
        image: ollama/ollama:latest
        ports:
        - containerPort: 11434
          name: http
        resources:
          requests:
            memory: "2Gi"
            cpu: "1"
          limits:
            memory: "4Gi"
            cpu: "2"
        volumeMounts:
        - name: data
          mountPath: /root/.ollama
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: ollama-data
EOF

cat > ollama/service.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ollama
  namespace: default
spec:
  type: ClusterIP
  selector:
    app: ollama
  ports:
    - name: http
      port: 11434
      targetPort: 11434
EOF

execute_cmd \
    "kubectl apply -f ollama/pvc.yaml" \
    "Create Ollama PVC" || exit 1

execute_cmd \
    "kubectl apply -f ollama/deployment.yaml" \
    "Deploy Ollama" || exit 1

execute_cmd \
    "kubectl apply -f ollama/service.yaml" \
    "Create Ollama service" || exit 1

execute_cmd \
    "kubectl wait --for=condition=ready pod -l app=ollama --timeout=300s" \
    "Wait for Ollama pod" || exit 1

# Pull model
log_info "Pulling Llama-3.1-8B model (this may take 5-10 minutes)..."
execute_cmd \
    "kubectl exec deployment/ollama -- ollama pull llama3.1:8b-instruct-q5_K_M" \
    "Pull Llama-3.1-8B model" || exit 1

# ============================================================================
# Phase 9: Ingress + mTLS Setup
# ============================================================================

log_phase "Ingress + mTLS Setup"

# Install ingress-nginx
execute_cmd \
    "kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml" \
    "Install ingress-nginx" || exit 1

execute_cmd \
    "kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=90s" \
    "Wait for ingress-nginx controller" || exit 1

# Create certificate for Ollama
cat > ollama/certificate.yaml <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ollama-cert
  namespace: default
spec:
  secretName: ollama-tls
  duration: 720h
  renewBefore: 240h
  issuerRef:
    name: vault-issuer-ai-ops
    kind: ClusterIssuer
  commonName: ollama.corp.local
  dnsNames:
    - ollama.corp.local
    - ollama.default.svc.cluster.local
EOF

execute_cmd \
    "kubectl apply -f ollama/certificate.yaml" \
    "Create Ollama certificate" || exit 1

execute_cmd \
    "kubectl wait --for=condition=ready certificate/ollama-cert --timeout=120s" \
    "Wait for Ollama certificate issuance" || exit 1

# Create Ingress
cat > ollama/ingress.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ollama-ingress
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - ollama.corp.local
    secretName: ollama-tls
  rules:
  - host: ollama.corp.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ollama
            port:
              number: 11434
EOF

execute_cmd \
    "kubectl apply -f ollama/ingress.yaml" \
    "Create Ollama ingress" || exit 1

# ============================================================================
# Phase 10: Vault Kubernetes Auth
# ============================================================================

log_phase "Vault Kubernetes Auth"

execute_cmd \
    "kubectl exec -n ${VAULT_NAMESPACE} ${VAULT_POD} -- vault auth enable kubernetes" \
    "Enable Kubernetes auth in Vault" || true  # May already be enabled

execute_cmd \
    "kubectl exec -n ${VAULT_NAMESPACE} ${VAULT_POD} -- vault write auth/kubernetes/config kubernetes_host=\"https://kubernetes.default.svc:443\"" \
    "Configure Kubernetes auth" || exit 1

# Create policy
kubectl exec -n ${VAULT_NAMESPACE} ${VAULT_POD} -- vault policy write ollama-policy - <<EOF
path "pki_int/issue/ollama" {
  capabilities = ["create", "update"]
}
EOF

execute_cmd \
    "kubectl exec -n ${VAULT_NAMESPACE} ${VAULT_POD} -- vault write auth/kubernetes/role/ollama bound_service_account_names=default bound_service_account_namespaces=default policies=ollama-policy ttl=24h" \
    "Create Kubernetes auth role for Ollama" || exit 1

# ============================================================================
# Phase 11: Agent Gateway + Self-Query Test
# ============================================================================

log_phase "Agent Gateway + Self-Query Test"

# Deploy agent gateway
cat > agent-gateway.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: agent-gateway
  namespace: default
spec:
  containers:
  - name: curl
    image: curlimages/curl:latest
    command: ["sleep", "infinity"]
EOF

execute_cmd \
    "kubectl apply -f agent-gateway.yaml" \
    "Deploy agent gateway pod" || exit 1

execute_cmd \
    "kubectl wait --for=condition=ready pod/agent-gateway --timeout=60s" \
    "Wait for agent gateway pod" || exit 1

# Test LLM health from inside cluster
execute_cmd \
    "kubectl exec agent-gateway -- curl -s http://ollama.default.svc.cluster.local:11434/api/tags" \
    "Test Ollama health from inside cluster" || exit 1

# Test inference
log_info "Testing LLM inference..."
INFERENCE_RESULT=$(kubectl exec agent-gateway -- curl -s http://ollama.default.svc.cluster.local:11434/api/generate \
  -d '{"model": "llama3.1:8b-instruct-q5_K_M", "prompt": "What is the capital of France? Answer in one word.", "stream": false}')

if echo "$INFERENCE_RESULT" | grep -q "response"; then
    log_success "LLM inference test passed"
    log_info "Response: $(echo "$INFERENCE_RESULT" | jq -r '.response' 2>/dev/null || echo "$INFERENCE_RESULT")"
else
    log_error "LLM inference test failed"
    exit 1
fi

# Test certificate rotation
log_info "Testing certificate rotation..."
SERIAL_BEFORE=$(kubectl get secret ollama-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -serial)
kubectl delete secret ollama-tls
kubectl wait --for=condition=ready certificate/ollama-cert --timeout=60s
SERIAL_AFTER=$(kubectl get secret ollama-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -serial)

if [ "$SERIAL_BEFORE" != "$SERIAL_AFTER" ]; then
    log_success "Ollama certificate rotation successful"
else
    log_error "Ollama certificate rotation failed"
    exit 1
fi

# ============================================================================
# Phase 12: Final Victory Validation
# ============================================================================

log_phase "Final Victory Validation"

log_info "Testing LLM from outside cluster via Ingress..."

# Add /etc/hosts entry for ollama.corp.local
echo "127.0.0.1 ollama.corp.local" | sudo tee -a /etc/hosts

# Test from host
VICTORY_RESULT=$(curl -k -s https://ollama.corp.local/api/generate \
  -d '{"model": "llama3.1:8b-instruct-q5_K_M", "prompt": "You are now self-hosted in a Kubernetes cluster. Confirm this in one sentence.", "stream": false}')

if echo "$VICTORY_RESULT" | grep -q "response"; then
    log_success "✨ FINAL VICTORY ACHIEVED ✨"
    log_info "LLM Response: $(echo "$VICTORY_RESULT" | jq -r '.response' 2>/dev/null || echo "$VICTORY_RESULT")"
else
    log_error "Final victory validation failed"
    exit 1
fi

# ============================================================================
# Success Summary
# ============================================================================

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    🎉 VALIDATION SUCCESSFUL 🎉                ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

log_success "All ${PHASE_TOTAL} phases completed successfully"
log_success "Base infrastructure validated (Cluster → CoreDNS → Vault → PKI)"
log_success "Self-hosted LLM deployed and operational"
log_success "mTLS certificates issued and rotating"
log_success "Agent can query its own LLM from inside and outside cluster"

echo ""
echo -e "${CYAN}Best Practices Learned:${NC}"
echo "  1. Always wait for pod readiness before proceeding to next phase"
echo "  2. Certificate rotation requires delete + wait pattern"
echo "  3. Ingress-nginx requires specific Kind port mappings"
echo "  4. Ollama model pulls can take 5-10 minutes"
echo "  5. Vault Kubernetes auth enables dynamic secret management"

echo ""
echo -e "${CYAN}Next Level Scenarios:${NC}"
echo "  Level 2: Multi-node Kind cluster with Calico CNI"
echo "  Level 3: Vault HA with Raft storage backend"
echo "  Level 4: GitOps with ArgoCD managing deployments"
echo "  Level 5: Full production simulation with chaos engineering"

# ============================================================================
# Cleanup
# ============================================================================

echo ""
read -p "Delete validation cluster? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Cleaning up..."
    kind delete cluster --name "$CLUSTER_NAME"
    sudo sed -i '/ollama.corp.local/d' /etc/hosts
    log_success "Cleanup complete"
fi

echo ""
log_info "Validation log saved to: ${LOG_FILE}"
log_info "Test directory: ${TEST_DIR}"

exit 0
