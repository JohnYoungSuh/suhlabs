# AIOpsAgent Operator

This operator manages the lifecycle of AI Ops Agents, ensuring they are deployed correctly with required vault secret injection annotations to securely communicate with infrastructure.

## Usage

Define a Custom Resource `aiopsagent-sample.yaml`:

```yaml
apiVersion: aiops.corp.local/v1alpha1
kind: AIOpsAgent
metadata:
  name: secure-ai-agent
  namespace: default
spec:
  replicas: 1
  image: "ai-ops-agent:latest"
  vaultSecretPath: "secret/data/ai-ops-agent"
```

Apply the CR:
```bash
kubectl apply -f aiopsagent-sample.yaml
```

View the Agent Status:
```bash
kubectl get aiopsagents -o yaml
```

## Running Tests

Integration tests can be run using the provided Makefile:
```bash
make test
```
