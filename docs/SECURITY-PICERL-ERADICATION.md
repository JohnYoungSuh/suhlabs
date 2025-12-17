# SECURITY-PICERL-ERADICATION: Patching & Remediation

**Document Type:** Security - PICERL Phase: Eradication  
**Version:** 1.0 | **Last Updated:** 2025-12-16

---

## 📊 At-a-Glance

**Purpose:** Remove security vulnerabilities through patching, secret rotation, and configuration hardening.

**Patch Cadence:**

- **Critical CVEs:** Within 24 hours
- **High CVEs:** Within 7 days
- **Medium/Low:** Monthly maintenance window

---

## 📖 Procedures

### Secret Rotation

**Vault Secret Rotation:**

```bash
#1. Generate new secret
NEW_SECRET=$(openssl rand -base64 32)

# 2. Update in Vault
vault kv patch secret/homeassistant/db password="$NEW_SECRET"

# 3. Restart service to pick up new secret
kubectl rollout restart deployment/homeassistant -n homeassistant

# 4. Verify
kubectl logs deployment/homeassistant -n homeassistant | grep "Connected to database"
```

### Certificate Renewal

**Force cert renewal:**

```bash
# Renew before expiry
cmctl renew homeassistant-tls -n homeassistant

# Verify new cert
kubectl get certificate homeassistant-tls -n homeassistant
```

### Vulnerability Scanning

**Scan container images:**

```bash
# Using Trivy
trivy image ghcr.io/johnyoungsuh/ai-ops-agent:2.0.0

# Using Grype
grype ghcr.io/johnyoungsuh/ai-ops-agent:2.0.0
```

---

**Document Status:** ✅ Complete
