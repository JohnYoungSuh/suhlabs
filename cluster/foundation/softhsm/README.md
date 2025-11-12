# SoftHSM Foundation Service

Software-based Hardware Security Module (HSM) for Vault PKI development.

## What is SoftHSM?

**SoftHSM** is a software implementation of an HSM (Hardware Security Module):
- **For Learning**: Teaches HSM concepts without hardware
- **For Development**: Test HSM integration locally
- **PKCS#11 Compatible**: Same interface as real HSMs (YubiHSM, AWS CloudHSM, etc.)
- **Not for Production**: Keys stored on disk (encrypted, but not hardware-protected)

## Why Use SoftHSM?

1. **Learn HSM Concepts**: Understand key storage, sealing, PKCS#11
2. **Test Vault Integration**: Vault works same way with real HSM
3. **Zero Cost**: No hardware purchase needed
4. **Easy Upgrade Path**: Switch to YubiHSM later with minimal config changes

## Quick Start

```bash
cd cluster/foundation/softhsm

# Initialize SoftHSM
./init-softhsm.sh

# Deploy Vault with SoftHSM
kubectl apply -f vault-deployment.yaml

# Wait for Vault to be ready
kubectl wait --for=condition=ready pod -l app=vault -n vault --timeout=300s

# Check Vault status
kubectl exec -n vault deploy/vault -- vault status
```

## HSM Token Configuration

**Token Label**: `vault-hsm`
**Slot**: 0
**PIN**: 1234 (user PIN)
**SO PIN**: 5678 (security officer PIN)

### Security Note

⚠️ **These PINs are for development only!**

Production HSM should have:
- Random 12+ character PINs
- PINs stored in real secrets management
- Physical access controls

## Vault + SoftHSM Integration

### How It Works

```
┌──────────────┐
│    Vault     │
└──────┬───────┘
       │ PKCS#11
       │ Interface
       ▼
┌──────────────┐     ┌─────────────┐
│   SoftHSM    │────▶│  /vault/    │
│   (Process)  │     │  softhsm/   │
└──────────────┘     │  tokens/    │
                     └─────────────┘
                     Encrypted Keys
                     on Disk
```

**Auto-Unseal**:
- Vault generates root key in HSM
- HSM encrypts the key with PIN
- Vault can auto-unseal using HSM
- No manual unseal keys needed

### Benefits

1. **Auto-Unseal**: Vault restarts don't need manual unseal
2. **Key Protection**: Root key never in memory unencrypted
3. **Production Pattern**: Same config as YubiHSM

## Initializing Vault

After deployment, initialize Vault:

```bash
# Initialize Vault (generates keys in HSM)
kubectl exec -n vault deploy/vault -- vault operator init

# Output will show:
# - Recovery Keys (use these for emergency)
# - Root Token (use for initial setup)

# Save these securely!
```

### Important: Recovery vs Unseal Keys

With HSM seal:
- **Recovery Keys**: For disaster recovery only
- **No Unseal Keys**: HSM auto-unseals Vault
- **Root Key in HSM**: Protected by HSM, never exposed

## Verifying HSM Integration

```bash
# Check Vault seal status
kubectl exec -n vault deploy/vault -- vault status

# Look for:
# Seal Type: pkcs11
# Initialized: true
# Sealed: false  (auto-unsealed!)

# List HSM tokens
kubectl exec -n vault deploy/vault -- sh -c \
  "export SOFTHSM2_CONF=/vault/config/softhsm2.conf && softhsm2-util --show-slots"

# Should show vault-hsm token
```

## Troubleshooting

### Vault Pod CrashLooping

```bash
# Check logs
kubectl logs -n vault deploy/vault

# Common issues:
# 1. SoftHSM not initialized
#    Fix: Check initContainer logs
#
# 2. PKCS#11 library not found
#    Fix: Verify /usr/lib/softhsm/libsofthsm2.so exists
#
# 3. Token not found
#    Fix: Re-run init-softhsm.sh
```

### Can't Initialize Vault

```bash
# Error: "unseal key must be provided"
# This means HSM seal not working

# Check HSM config
kubectl exec -n vault deploy/vault -- cat /vault/config/vault.hcl

# Verify seal stanza is correct
```

### Keys Not Persisting

```bash
# Check PVC exists
kubectl get pvc -n vault

# HSM tokens stored in vault-softhsm PVC
# If PVC deleted, keys are lost!
```

## Upgrade Path: SoftHSM → YubiHSM

When ready for production:

### Step 1: Get YubiHSM 2

Purchase: ~$650 for YubiHSM 2
- USB HSM device
- FIPS 140-2 Level 3
- Hardware key protection

### Step 2: Update Vault Config

```hcl
seal "pkcs11" {
  lib = "/usr/lib/x86_64-linux-gnu/pkcs11/yubihsm_pkcs11.so"  # Changed
  slot = "0"
  pin = "REAL_PIN_FROM_SECRETS"  # Changed
  key_label = "vault-root-key"
  hmac_key_label = "vault-hmac-key"
}
```

### Step 3: Migrate Keys

```bash
# Generate new root key in YubiHSM
vault operator rekey -target=recovery

# Old keys in SoftHSM still work for recovery
```

## Learning Outcomes

By setting up SoftHSM + Vault, you learn:

- ✅ HSM concepts (slots, tokens, PINs)
- ✅ PKCS#11 interface standard
- ✅ Vault auto-unseal mechanism
- ✅ Key hierarchy (root key → encryption keys)
- ✅ Recovery procedures

## Security Comparison

| Feature | SoftHSM (Dev) | YubiHSM (Prod) |
|---------|---------------|----------------|
| Key Storage | Disk (encrypted) | Hardware chip |
| Key Extraction | Possible | Impossible |
| Physical Security | None | Tamper-evident |
| FIPS 140-2 | No | Level 3 |
| Cost | Free | $650 |
| Performance | Fast | Very Fast |
| Use Case | Dev/Learning | Production |

## Next Steps

After SoftHSM is deployed:

1. **Hour 3**: Initialize Vault PKI engine
2. **Day 5**: Configure cert-manager to use Vault
3. **Day 8+**: Deploy services with automatic certificates

## Reference

- [SoftHSM Documentation](https://www.opendnssec.org/softhsm/)
- [PKCS#11 Specification](http://docs.oasis-open.org/pkcs11/pkcs11-base/v2.40/os/pkcs11-base-v2.40-os.html)
- [Vault HSM Auto-Unseal](https://developer.hashicorp.com/vault/docs/concepts/seal#auto-unseal)
- [YubiHSM 2 Product Page](https://www.yubico.com/product/yubihsm-2/)

---

**Status**: Foundation service for Day 4 (Hour 2)
