#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==================================="
echo "Deploying Netshoot Debug Pod"
echo "==================================="

# Deploy netshoot pod
echo ""
echo "Deploying netshoot pod..."
kubectl apply -f "${SCRIPT_DIR}/netshoot.yaml"

# Wait for pod to be ready
echo ""
echo "Waiting for netshoot pod to be ready..."
kubectl wait --for=condition=Ready pod/netshoot -n default --timeout=60s

echo ""
echo "✓ Netshoot pod is ready!"
echo ""
echo "Quick Start Commands:"
echo "===================="
echo ""
echo "# Exec into netshoot pod:"
echo "kubectl exec -it netshoot -n default -- bash"
echo ""
echo "# Test DNS resolution:"
echo "kubectl exec -it netshoot -n default -- nslookup ai-ops-agent.default.svc.cluster.local"
echo ""
echo "# Test connectivity:"
echo "kubectl exec -it netshoot -n default -- curl -v http://ai-ops-agent.default.svc.cluster.local:8000"
echo ""
echo "# Check certificate:"
echo "kubectl exec -it netshoot -n default -- openssl s_client -connect ai-ops-agent.default.svc.cluster.local:8000 -showcerts"
echo ""
echo "# View Kubernetes resources:"
echo "kubectl exec -it netshoot -n default -- kubectl get certificates -A"
echo "kubectl exec -it netshoot -n default -- kubectl get secrets -A | grep tls"
echo ""
