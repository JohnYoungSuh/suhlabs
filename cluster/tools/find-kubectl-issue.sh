#!/bin/bash
# Script to find pods using bitnami/kubectl:1.28 image

echo "=========================================="
echo "Finding Pods with bitnami/kubectl:1.28"
echo "=========================================="
echo ""

echo "Checking all pods in cluster..."
echo ""

# Check all running pods
kubectl get pods -A -o json | jq -r '
  .items[] |
  select(.spec.initContainers != null) |
  select(.spec.initContainers[].image | contains("kubectl:1.28")) |
  "Namespace: \(.metadata.namespace)\nPod: \(.metadata.name)\nInit Container: \(.spec.initContainers[] | select(.image | contains("kubectl:1.28")) | .name)\nImage: \(.spec.initContainers[] | select(.image | contains("kubectl:1.28")) | .image)\n---"
'

echo ""
echo "Checking deployments..."
kubectl get deployments -A -o json | jq -r '
  .items[] |
  select(.spec.template.spec.initContainers != null) |
  select(.spec.template.spec.initContainers[].image | contains("kubectl:1.28")) |
  "Namespace: \(.metadata.namespace)\nDeployment: \(.metadata.name)\nImage: \(.spec.template.spec.initContainers[] | select(.image | contains("kubectl:1.28")) | .image)\n---"
'

echo ""
echo "Checking for recent image pull failures..."
kubectl get events -A --field-selector reason=Failed,reason=FailedPull,reason=ErrImagePull \
  | grep kubectl

echo ""
echo "=========================================="
echo "Recommendations:"
echo "=========================================="
echo "1. Delete the pod to force recreation with new image:"
echo "   kubectl delete pod <pod-name> -n <namespace>"
echo ""
echo "2. Or recreate the deployment:"
echo "   kubectl rollout restart deployment/<deployment-name> -n <namespace>"
echo ""
echo "3. For ai-ops-agent specifically:"
echo "   cd cluster/ai-ops-agent"
echo "   kubectl delete -f k8s/deployment.yaml"
echo "   kubectl apply -f k8s/deployment.yaml"
