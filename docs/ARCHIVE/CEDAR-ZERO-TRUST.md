# CEDAR Analysis: Zero-Trust Networking Design (Day 8)

## C: Context & Constraints
*   **Context**: We are building an "AI Ops Substrate" appliance. It must be secure by default ("Zero Trust") but usable by non-technical operators.
*   **Constraints**:
    *   **Resource Limited**: Target hardware is consumer-grade (NUC/Edge), so overhead must be minimal.
    *   **Zero-Touch**: The user should not have to manually manage certificates or complex mesh configs.
    *   **Environment**: Runs on K3s (local/prod) and Kind (dev).
    *   **Timeline**: Day 8 of a 14-day sprint.

## E: Evaluation
We evaluated the security posture of the current "open" cluster network.
*   **Current State**: "Flat" network. Any pod can talk to any pod (e.g., a compromised web frontend could attack Vault directly).
*   **Risk**: High. Lateral movement is trivial.
*   **Requirement**: We need Mutual TLS (mTLS) for identity/encryption and Network Policies for traffic control.

## D: Design
We selected a **Linkerd-based Service Mesh** with a **Default-Deny Network Policy** strategy.

### 1. Service Mesh: Linkerd
*   **Architecture**: Sidecar proxy (Rust-based) injected into every pod.
*   **Identity**: Uses Kubernetes ServiceAccounts.
*   **Trust Root**: Anchored to our existing Vault PKI (via cert-manager) for a unified trust chain.
*   **mTLS**: Automatic, zero-config encryption for all TCP traffic between meshed pods.

### 2. Network Policies
*   **Strategy**: "Allow-List" approach.
*   **Base Policy**: `default-deny-all` (Blocks all Ingress/Egress).
*   **Core Allow**: `allow-dns` (UDP/53 to CoreDNS).
*   **Specific Allow**: Explicit rules for Agent -> Vault, Agent -> Ollama.

## A: Alternatives & Trade-offs

| Alternative | Pros | Cons | Verdict |
| :--- | :--- | :--- | :--- |
| **Istio** | Industry standard, massive feature set. | Heavy resource usage (Envoy), complex config, steep learning curve. | **Rejected** (Too heavy/complex). |
| **Cilium (eBPF)** | Extremely performant, transparent encryption. | Complex kernel dependencies, harder to debug for non-experts. | **Rejected** (Complexity risk). |
| **Manual mTLS** | No sidecar overhead. | Developer hell. Every app needs cert logic. | **Rejected** (Not zero-touch). |
| **Linkerd** | Lightweight (Rust), simple ("it just works"), K3s native. | Fewer features than Istio (e.g., less complex egress control). | **Selected** (Best fit). |

## R: Results & Validation
*   **Implementation**:
    *   `cluster/foundation/linkerd/deploy.sh`: Automates installation.
    *   `network-policies/*.yaml`: Defines the security posture.
*   **Validation Plan** (`verify-zero-trust.sh`):
    1.  **Health**: `linkerd check` passes.
    2.  **Encryption**: `linkerd viz tap` confirms `tls=true`.
    3.  **Enforcement**: `curl` from a test pod to `google.com` FAILS (Egress blocked). `curl` to `vault` FAILS (unless allowed).
    4.  **Functionality**: DNS resolution WORKS.

**Conclusion**: The Linkerd + Default Deny design meets the "Zero Trust" requirement with minimal resource impact and operational complexity, fitting the "Appliance" model perfectly.
