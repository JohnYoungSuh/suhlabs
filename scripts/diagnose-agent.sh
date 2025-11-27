#!/bin/bash
# AI Ops Agent Diagnostic Script

echo "=== AI Ops Agent Diagnostics ==="
echo ""

echo "1. Checking if agent pod is running..."
kubectl get pods -n default -l app=ai-ops-agent
echo ""

echo "2. Checking agent pod status..."
kubectl describe pod -n default -l app=ai-ops-agent | grep -A 10 "Status:"
echo ""

echo "3. Checking agent logs (last 50 lines)..."
kubectl logs -n default -l app=ai-ops-agent --tail=50
echo ""

echo "4. Checking if Ollama is accessible from agent..."
kubectl exec -n default -l app=ai-ops-agent -- curl -s http://172.19.0.1:11434/api/tags || echo "Ollama not accessible"
echo ""

echo "5. Checking agent service..."
kubectl get svc -n default ai-ops-agent
echo ""

echo "6. Testing agent health endpoint..."
curl -s http://localhost:30080/health | jq || echo "Health endpoint not responding"
echo ""

echo "7. Checking if Ollama is running on host..."
docker ps | grep ollama || echo "Ollama container not running"
echo ""

echo "=== End Diagnostics ==="
