# SECURITY-PICERL-IDENTIFICATION: Threat Detection & SIEM

**Document Type:** Security - PICERL Phase: Identification  
**Version:** 1.0 | **Last Updated:** 2025-12-16

---

## 📊 At-a-Glance

**Purpose:** Detect security threats before they become breaches through SIEM, audit logging, and anomaly detection.

**Security Monitoring Stack:**

- **SIEM:** Governance framework OTEL emitters
- **Audit:** Vault audit logs
- **Network:** Linkerd mTLS metrics
- **Compliance:** Policy violation tracking

---

## 📖 Procedures

### SIEM Deployment

See [DESIGN-v2-GOVERNANCE.md](DESIGN-v2-GOVERNANCE.md) for:

- OTEL SIEM emitter sidecar
- PKI validator sidecar
- Governance policy agent

### Security Metrics

**Key Indicators:**

- Failed authentication attempts (Vault audit log)
- mTLS handshake failures (Linkerd metrics)
- Policy violations (Governance SIEM)
- Certificate expiry warnings (cert-manager)

---

**Document Status:** ✅ Complete - See DESIGN-v2-GOVERNANCE.md for implementation
