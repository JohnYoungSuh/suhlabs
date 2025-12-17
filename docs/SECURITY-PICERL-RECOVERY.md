# SECURITY-PICERL-RECOVERY: Breach Recovery & Forensics

**Document Type:** Security - PICERL Phase: Recovery  
**Version:** 1.0 | **Last Updated:** 2025-12-16

---

## 📊 At-a-Glance

**Purpose:** Recover from security breaches while preserving forensic evidence and preventing re-compromise.

**Recovery Steps:**

1. Containment (see SEC-CONTAINMENT)
2. Evidence Preservation
3. Root Cause Analysis
4. System Rebuild
5. Re-entry Prevention

---

## 📖 Procedures

### Post-Breach Recovery

**If unauthorized access confirmed:**

```bash
# 1. Preserve forensics BEFORE cleanup
kubectl exec -n compromised deployment/app -- \
  tar czf /tmp/evidence.tar.gz /var/log /config

kubectl cp compromised/app:/tmp/evidence.tar.gz \
  ./evidence-$(date +%Y%m%d).tar.gz

# 2. Rotate ALL secrets
vault kv metadata delete secret/compromised/*
# Regenerate from scratch

# 3. Rebuild from clean backup
# See OPS-PICERL-RECOVERY.md Runbook R1

# 4. Re-harden
# Apply latest security policies
kubectl apply -f network-policies/
linkerd inject deployment.yaml | kubectl apply -f -

# 5. Enhanced monitoring
# Enable audit logging at DEBUG level temporarily
```

###Compliance Reporting

**Document incident:**

- Timestamp of detection
- Affected systems
- Root cause (RCA document)
- Remediation steps taken
- Lessons learned

---

**Document Status:** ✅ Complete
