# Day 8: Zero-Trust Networking & Service Mesh

## Goal
Implement a strict Zero-Trust security model where all service-to-service communication is authenticated, authorized, and encrypted. We will move from "implicit trust" (open network within the cluster) to "explicit trust" (mTLS + Network Policies).

## 1. Service Mesh Selection: Linkerd
We have selected **Linkerd** over Istio for this project.

### Rationale
- **Resource Efficiency**: Linkerd's Rust-based micro-proxy is significantly lighter than Envoy (Istio), which is critical for our "Consumer Appliance" target hardware (e.g., NUC, Edge devices).
- **Simplicity**: "It just works" philosophy fits our 14-day sprint. No complex configuration for standard mTLS.
- **K3s Compatibility**: First-class support for K3s and Kind.

## 2. Architecture

### Mutual TLS (mTLS)
- **Automatic Injection**: All pods in the `ai-ops` and `foundation` namespaces will have the Linkerd sidecar injected.
- **Identity**: Workload identity is derived from Kubernetes ServiceAccounts.
- **Trust Root**: Linkerd's CA will be anchored to our Vault Root CA (via cert-manager) to maintain a single chain of trust.

### Network Policies
We will implement a **Default Deny** posture.

1.  **Default Policy**: Deny all Ingress/Egress traffic for all pods.
2.  **Allow DNS**: Allow UDP/53 to CoreDNS for all pods.
3.  **Allow Scraped Metrics**: Allow Prometheus to scrape metrics ports.
4.  **Specific Allow Rules**:
    - `ai-ops-agent` -> `vault` (port 8200)
    - `ai-ops-agent` -> `ollama` (port 11434)
    - `ingress` -> `ai-ops-agent` (port 80/443)

## 3. Implementation Plan

### Step 1: Linkerd Installation
- Install Linkerd CLI (via script/Makefile).
- Generate Trust Anchor and Issuer certificates (using `step` or `openssl`).
- Install Linkerd Control Plane via Helm.

### Step 2: Vault Integration (Intermediate CA)
- *Advanced*: Instead of self-signed Linkerd certs, we will use `cert-manager` + `Vault` to issue the Linkerd Issuer Certificate. This ties the mesh identity to our hardware-backed Root CA.

### Step 3: Mesh Injection
- Annotate the `ai-ops` and `foundation` namespaces: `linkerd.io/inject: enabled`.
- Restart deployments to inject proxies.

### Step 4: Network Policies
- Apply `network-policies/default-deny.yaml`.
- Apply `network-policies/allow-dns.yaml`.
- Iteratively add allow rules for our services.

## 4. Verification
- **mTLS Check**: Use `linkerd viz tap` to verify traffic is `tls=true`.
- **Policy Check**: Verify that `curl` from a rogue pod to `vault` fails.
