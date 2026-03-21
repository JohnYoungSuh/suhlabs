#!/usr/bin/env bash
set -e

echo "[INFO] Deploying ArgoCD for GitOps..."

# Create namespace
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Add required helm repos
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Deploy ArgoCD
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --set server.extraArgs="{--insecure}" \
  --wait

echo "[INFO] Applying ArgoCD Applications..."
kubectl apply -f applications.yaml -n argocd

echo "[SUCCESS] ArgoCD deployed successfully!"
echo "Access ArgoCD UI via: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "Default username: admin"
echo "Get initial password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo"
