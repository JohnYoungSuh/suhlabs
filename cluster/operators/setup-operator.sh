#!/usr/bin/env bash
set -e

echo "[INFO] Setting up Operator Directory..."
mkdir -p /Ubuntu/home/suhlabs/projects/suhlabs/aiops-substrate/cluster/operators/ai-ops-operator
cd /Ubuntu/home/suhlabs/projects/suhlabs/aiops-substrate/cluster/operators/ai-ops-operator

export PATH=$PATH:/usr/local/go/bin

if ! command -v go &> /dev/null; then
    echo "[INFO] Installing Go..."
    curl -OL https://golang.org/dl/go1.22.1.linux-amd64.tar.gz
    sudo tar -C /usr/local -xzf go1.22.1.linux-amd64.tar.gz
    export PATH=$PATH:/usr/local/go/bin
fi

if ! command -v kubebuilder &> /dev/null; then
    echo "[INFO] Installing Kubebuilder..."
    curl -sL -o kubebuilder https://go.kubebuilder.io/dl/latest/$(go env GOOS)/$(go env GOARCH)
    chmod +x kubebuilder
    sudo mv kubebuilder /usr/local/bin/
fi

echo "[INFO] Initializing Kubebuilder Project..."
if [ ! -f "go.mod" ]; then
    kubebuilder init --domain corp.local --repo github.com/suhlabs/ai-ops-operator
fi

echo "[INFO] Creating API AIOpsAgent..."
if [ ! -f "api/v1alpha1/aiopsagent_types.go" ]; then
    kubebuilder create api --group aiops --version v1alpha1 --kind AIOpsAgent --resource --controller
fi

echo "[SUCCESS] Operator scaffolded!"
