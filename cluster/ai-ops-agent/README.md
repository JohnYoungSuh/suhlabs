# AI Ops Agent

Natural language infrastructure automation agent with automatic TLS certificate management.

## Overview

The AI Ops Agent is a FastAPI-based service that provides infrastructure automation capabilities through a REST API. It automatically receives TLS certificates from Vault PKI via cert-manager.

## Features

- **FastAPI REST API** - Modern, fast web framework
- **Auto TLS Certificates** - cert-manager issues certificates from Vault PKI
- **Health/Readiness Probes** - Kubernetes-native health checking
- **Non-root Container** - Security best practices
- **Multi-stage Docker Build** - Optimized image size

## Prerequisites

Before deploying AI Ops Agent, ensure you have:

- ✅ Kubernetes cluster running
- ✅ CoreDNS deployed (for service discovery)
- ✅ Vault deployed and unsealed
- ✅ Vault PKI initialized (Root CA + Intermediate CA)
- ✅ cert-manager installed and configured with Vault

## Quick Start

```bash
cd cluster/ai-ops-agent

# Build and deploy (includes Docker build, load to cluster, and kubectl apply)
./deploy.sh
```

The deployment script will:
1. Build Docker image `ai-ops-agent:0.1.0`
2. Load image into cluster (kind/k3d/minikube)
3. Apply Kubernetes manifests
4. Wait for certificate to be issued
5. Wait for deployment to be ready

## Manual Deployment

### Step 1: Build Docker Image

```bash
docker build -t ai-ops-agent:0.1.0 .
docker tag ai-ops-agent:0.1.0 ai-ops-agent:latest
```

### Step 2: Load Image into Cluster

**For kind:**
```bash
kind load docker-image ai-ops-agent:0.1.0
```

**For k3d:**
```bash
k3d image import ai-ops-agent:0.1.0
```

**For minikube:**
```bash
minikube image load ai-ops-agent:0.1.0
```

### Step 3: Deploy to Kubernetes

```bash
# Apply manifests in order
kubectl apply -f k8s/certificate.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/deployment.yaml
```

### Step 4: Verify Deployment

```bash
# Check pods
kubectl get pods -l app=ai-ops-agent

# Check certificate (should show READY=True)
kubectl get certificate ai-ops-agent-cert

# Check service
kubectl get svc ai-ops-agent
```

## Testing

### Port Forward to Access Locally

```bash
kubectl port-forward svc/ai-ops-agent 8000:8000
```

### Test Endpoints

```bash
# Root endpoint
curl http://localhost:8000
# Response: {"service":"AI Ops Agent","version":"0.1.0","status":"operational"}

# Health check
curl http://localhost:8000/health
# Response: {"status":"healthy","timestamp":"...","environment":"production"}

# Readiness check
curl http://localhost:8000/ready
# Response: {"ready":true}
```

## TLS Certificate

The AI Ops Agent automatically receives a TLS certificate from Vault PKI via cert-manager.

### Certificate Details

- **Issuer**: Vault PKI Intermediate CA (vault-issuer-ai-ops)
- **Common Name**: ai-ops-agent.default.svc.cluster.local
- **DNS Names**:
  - ai-ops-agent
  - ai-ops-agent.default.svc.cluster.local
  - ai-ops-agent.corp.local
- **Lifetime**: 30 days
- **Auto-renewal**: 10 days before expiry
- **Key Algorithm**: RSA 2048
- **Key Rotation**: Automatic on renewal

### View Certificate

```bash
# Get certificate from secret
kubectl get secret ai-ops-agent-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout

# Check certificate expiry
kubectl get secret ai-ops-agent-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -dates
```

### Certificate Files Available in Pod

The certificate is mounted at `/etc/tls/` with environment variables:

- `TLS_CERT_FILE=/etc/tls/tls.crt` - Certificate
- `TLS_KEY_FILE=/etc/tls/tls.key` - Private key
- `TLS_CA_FILE=/etc/tls/ca.crt` - CA certificate

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     AI Ops Agent Pod                        │
│                                                               │
│  ┌────────────────────────────────────────────────┐         │
│  │  Container: ai-ops-agent                       │         │
│  │  - FastAPI app on :8000                        │         │
│  │  - TLS cert mounted at /etc/tls/               │         │
│  │  - Non-root user (UID 1000)                    │         │
│  └────────────────────────────────────────────────┘         │
│                          ↑                                   │
│                          │ Volume Mount                      │
│  ┌────────────────────────────────────────────────┐         │
│  │  Secret: ai-ops-agent-tls                      │         │
│  │  - tls.crt (certificate)                       │         │
│  │  - tls.key (private key)                       │         │
│  │  - ca.crt (CA certificate)                     │         │
│  └────────────────────────────────────────────────┘         │
│                          ↑                                   │
└──────────────────────────┼───────────────────────────────────┘
                           │ Created by
                           │
                ┌──────────▼──────────┐
                │  cert-manager       │
                │  Certificate CRD    │
                └──────────┬──────────┘
                           │ Requests cert from
                           │
                ┌──────────▼──────────┐
                │  Vault PKI          │
                │  (Intermediate CA)  │
                └─────────────────────┘
```

## Configuration

### Environment Variables

Set in `k8s/deployment.yaml`:

- `ENVIRONMENT=production` - Environment name
- `TLS_CERT_FILE=/etc/tls/tls.crt` - Certificate path
- `TLS_KEY_FILE=/etc/tls/tls.key` - Private key path
- `TLS_CA_FILE=/etc/tls/ca.crt` - CA certificate path

### Resource Limits

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

### Probes

**Liveness Probe:**
- Endpoint: `/health`
- Initial delay: 10s
- Period: 30s

**Readiness Probe:**
- Endpoint: `/ready`
- Initial delay: 5s
- Period: 10s

## Troubleshooting

### Pod Not Starting

```bash
# Check pod status
kubectl get pods -l app=ai-ops-agent

# Check pod events
kubectl describe pod -l app=ai-ops-agent

# View logs
kubectl logs -l app=ai-ops-agent
```

Common issues:
- Image not found → Load image into cluster
- Certificate not ready → Check cert-manager logs
- Container crash → Check application logs

### Certificate Not Issued

```bash
# Check certificate status
kubectl describe certificate ai-ops-agent-cert

# Check certificate request
kubectl get certificaterequest

# Check cert-manager logs
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager
```

Common issues:
- ClusterIssuer not ready → Check Vault connectivity
- Vault auth failed → Verify Kubernetes auth configuration
- DNS names not allowed → Check Vault PKI role allowed_domains

### Service Not Accessible

```bash
# Check service
kubectl get svc ai-ops-agent

# Check endpoints
kubectl get endpoints ai-ops-agent

# Test from within cluster
kubectl run -it --rm debug --image=curlimages/curl -- \
  curl http://ai-ops-agent.default.svc.cluster.local:8000
```

## Development

### Local Development

```bash
# Install dependencies
pip install -r requirements.txt

# Run locally
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Test
curl http://localhost:8000
```

### Build and Test

```bash
# Build image
docker build -t ai-ops-agent:dev .

# Run container locally
docker run -p 8000:8000 ai-ops-agent:dev

# Test
curl http://localhost:8000
```

## Security

### Container Security

- ✅ Non-root user (UID 1000)
- ✅ Read-only TLS volume mount
- ✅ Multi-stage build (minimal attack surface)
- ✅ No package manager in runtime image
- ✅ Health checks enabled

### Network Security

- ✅ ClusterIP service (not externally exposed)
- ✅ TLS certificates available for mTLS
- ✅ Service-to-service encryption ready

### Secrets Management

- ✅ TLS certificates from Vault PKI
- ✅ Automatic certificate rotation
- ✅ Kubernetes secrets for certificate storage
- ✅ No secrets in environment variables or config

## Next Steps

**Future Enhancements:**

1. **Add TLS to FastAPI** - Configure uvicorn with TLS
2. **Implement mTLS** - Mutual TLS for service-to-service communication
3. **Add Ollama Integration** - Connect to Ollama for AI capabilities
4. **Add Vault Integration** - Read/write secrets from Vault
5. **Add Monitoring** - Prometheus metrics endpoint
6. **Add Ingress** - Expose externally with TLS

## Files

```
cluster/ai-ops-agent/
├── Dockerfile              # Multi-stage Docker build
├── main.py                 # FastAPI application
├── requirements.txt        # Python dependencies
├── deploy.sh              # Deployment script
├── README.md              # This file
└── k8s/
    ├── certificate.yaml   # Certificate resource (cert-manager)
    ├── deployment.yaml    # Deployment manifest
    └── service.yaml       # Service manifest
```

## Learning Outcomes

By deploying the AI Ops Agent, you learn:

- ✅ Building and deploying containerized applications
- ✅ Kubernetes Deployments, Services, and Secrets
- ✅ cert-manager certificate automation
- ✅ Vault PKI integration
- ✅ Health and readiness probes
- ✅ Security best practices (non-root, multi-stage builds)

## References

- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [cert-manager Certificate Resources](https://cert-manager.io/docs/usage/certificate/)
- [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Docker Multi-stage Builds](https://docs.docker.com/build/building/multi-stage/)

---

**Status**: AI Ops Agent v0.1.0 - Foundation deployment ready
