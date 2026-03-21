#!/usr/bin/env bash
set -e

# Deploy script for Observability Stack: kube-prometheus-stack and Loki

echo "[INFO] Deploying Observability Stack (kube-prometheus-stack + Loki)"

# Add required helm repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Create namespace
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -

echo "[INFO] Deploying Loki and Promtail..."
helm upgrade --install loki grafana/loki-stack \
  --namespace observability \
  -f values-loki.yaml \
  --create-namespace \
  --wait

echo "[INFO] Deploying kube-prometheus-stack..."
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace observability \
  -f values-kube-prometheus-stack.yaml \
  --create-namespace \
  --wait

echo "[INFO] Applying Custom Alerting Rules..."
kubectl apply -f alerts/ai-ops-alerts.yaml -n observability

echo "[SUCCESS] Observability stack deployed successfully!"
echo "Access Grafana via: kubectl port-forward -n observability svc/prometheus-grafana 8080:80"
echo "Default credentials: admin / prom-operator (unless changed in values)"
