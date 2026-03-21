# Vault Production Auto-Unseal Guide

This guide details the recommended architecture and operational procedures for running Vault in a high-availability (HA) production environment, focusing on secure initialization and auto-unsealing mechanisms.

## Context

In production, the AI Ops Substrate relies heavily on Vault for PKI certificates and secret injection. If Vault nodes restart (due to upgrades, node replacement, or failure), they must reconstruct the master key to unseal and begin servicing requests. Manual unsealing via Shamir's Secret Sharing is not scalable, hence **Auto-Unseal via an external Hardware Security Module (HSM) or Cloud KMS** is the standard.

## Recommended Architecture

### 1. Trusted Key Management System (KMS/HSM)
Vault delegates the unsealing process to a trusted external system. Recommended options for 2026:
- **On-Premise (Bare Metal/Proxmox):** YubiHSM 2, Thales Luna Network HSM, or SoftHSM (if heavily secured for specific homelab uses, although YubiHSM is preferred).
- **Cloud:** AWS KMS, Azure Key Vault, or GCP Cloud KMS.

### 2. Shamir Secret Sharing (Recovery Keys)
When using Auto-Unseal, the process of initializing Vault produces **Recovery Keys** instead of Unseal Keys. These recover the master key if the HSM is permanently lost or if you need to manually intervene.

**Recommended Configuration:**
- **Threshold:** 3-of-5 (Requires 3 out of 5 key custodians to re-assemble the key).
- **Distribution:** Keys should be securely generated on an air-gapped machine and distributed directly to custodians (e.g., via PGP encrypted messages or secure enterprise password managers). **Never** store these keys in a shared digital location.

### 3. Init Container / Sidecar Pattern (For USB-attached HSMs)
When running Vault on Kubernetes over a hypervisor like Proxmox, passing through a physical USB device (like a YubiHSM) directly to the Vault pod can be unreliable if pods schedule across different physical nodes.

**Standard Pattern:**
Instead of mounting the HSM directly to the Vault pod, run a lightweight proxy/sidecar on the specific node where the HSM is physically attached, and configure Vault's `seal` stanza to communicate with that proxy over the network.
Alternatively, use an **external KMS** (e.g. AWS KMS) that doesn't rely on local USB passthrough for maximum cluster mobility.

## Production Configuration Examples

### Example 1: AWS KMS (Recommended for Hybrid/Cloud)

Update `values.yaml` in the Vault Helm chart:

```yaml
server:
  extraEnvironmentVars:
    AWS_REGION: "us-east-1"
  # Provide AWS credentials via Vault's ServiceAccount using IRSA
  ha:
    enabled: true
    raft:
      config: |
        ui = true
        listener "tcp" {
          tls_disable = 0
          address = "[::]:8200"
          cluster_address = "[::]:8201"
          tls_cert_file = "/vault/userconfig/vault-server-tls/tls.crt"
          tls_key_file  = "/vault/userconfig/vault-server-tls/tls.key"
        }
        storage "raft" {
          path = "/vault/data"
        }
        # Auto-Unseal Stanza
        seal "awskms" {
          region     = "us-east-1"
          kms_key_id = "arn:aws:kms:us-east-1:123456789012:key/xxxx-xxxx-xxxx"
        }
```

### Example 2: YubiHSM 2 via PKCS#11 

If using a YubiHSM, expose it securely to the cluster.

```yaml
server:
  ha:
    raft:
      config: |
        ui = true
        listener "tcp" { ... }
        storage "raft" { ... }
        
        seal "pkcs11" {
          lib            = "/usr/lib/x86_64-linux-gnu/libyubihsm_pkcs11.so"
          slot           = "0"
          pin            = "0001password"  # Inject this via Kubernetes Secret
          key_label      = "vault-master"
          generate_key   = "true"
        }
```
*Note: The PKCS#11 library must be present in the container. Use a custom Vault image, or an InitContainer to copy the library into an `emptyDir` shared with the Vault container.*

## Initializing Production Vault

Once the auto-unseal seal is configured in `values.yaml` and deployed:

1. Initialize Vault:
   ```bash
   kubectl exec -n vault vault-0 -- vault operator init
   ```
2. Save the Output:
   Notice that the output provides **Recovery Keys**, not Unseal keys. 
   ```text
   Recovery Key 1: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   Recovery Key 2: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ...
   Initial Root Token: hvs.xxxxxxxxxxxxxxxxxxxx
   ```
3. Vault is automatically unsealed by the KMS/HSM configured in the `seal` stanza. To verify, run:
   ```bash
   kubectl exec -n vault vault-0 -- vault status
   # Should report "Sealed: false" immediately.
   ```
4. Revoke the root token immediately after creating the necessary admin/automation policies and roles.

## Disaster Recovery

If the HSM/KMS is unavailable, Vault will fail to start. If the HSM is permanently destroyed, you must use the Recovery Keys to regenerate the master key.
```bash
# Provide 3 out of 5 recovery keys
kubectl exec -n vault vault-0 -- vault operator unseal -recovery
```
