# Documentation Archive

This directory contains documentation that has been consolidated into the PICERL framework.

## What's Here

These documents are **archived for historical reference only**. Their content has been migrated into the new PICERL-structured documentation.

## Migration Date

**Archived:** 2025-12-16

## New Documentation Structure

All operational and security procedures are now organized using the PICERL incident response framework:

### Operations (OPS-PICERL-*)
- **PREPARATION.md** - Setup, architecture, deployment
- **RECOVERY.md** - Disaster recovery, restore procedures
- **IDENTIFICATION.md** - Monitoring, observability, alerting
- **ERADICATION.md** - Troubleshooting, bug fixes, maintenance
- **CONTAINMENT.md** - Environment isolation, change control
- **LESSONS.md** - Sprint retrospectives, learnings

### Security (SECURITY-PICERL-*)
- **PREPARATION.md** - Zero-trust, hardening, PKI
- **IDENTIFICATION.md** - SIEM, threat detection
- **CONTAINMENT.md** - Isolation, access control
- **ERADICATION.md** - Patching, remediation
- **RECOVERY.md** - Breach recovery, forensics
- **LESSONS.md** - Security post-mortems

## Finding Migrated Content

Use the **MIGRATION-AUDIT.md** document (in `docs/`) to find where specific content from archived files has been migrated.

## Restoration

If you need to restore any archived content:

```bash
# View archive contents
ls -lh docs/ARCHIVE/

# Restore specific file
cp docs/ARCHIVE/filename.md docs/

# Or restore from git tag
git show pre-picerl-cleanup-YYYYMMDD:docs/filename.md
```
