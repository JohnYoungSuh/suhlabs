# SECURITY-PICERL-LESSONS: Security Post-Mortems

**Document Type:** Security - PICERL Phase: Lessons Learned  
**Version:** 1.0 | **Last Updated:** 2025-12-16

---

## 📊 Security Learnings

### Vault PKI Lessons

**What Worked:**

- 2-tier CA (Root offline, Intermediate online)
- cert-manager automation (30-day rotation)
- Linkerd mTLS (transparent encryption)

**What Didn't Work:**

- Manual Vault unsealing (YubiHSM needed)
- Flat network initially (needed default-deny policies)

**Action Items:**

- [x] Implement YubiHSM auto-unseal for production
- [x] Deploy Linkerd service mesh
- [x] Create default-deny network policies

### Secret Management Lessons

**What Worked:**

- Template-based secret files (`.yaml.template`)
- Vault integration for production
- Pre-commit hooks (gitleaks)

**Incidents:**

- **2024-11:** Accidentally committed secret to Git
  - **Impact:** Low (caught by pre-commit hook)
  - **RCA:** Forgot to use template file
  - **Fix:** Enhanced pre-commit config, added CI check

---

**Document Status:** ✅ Complete
