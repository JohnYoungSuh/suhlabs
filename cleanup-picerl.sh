#!/bin/bash
# PICERL Documentation Cleanup Script
# Run this script to complete Phases 2-5 of the document migration

set -euo pipefail

echo "================================================================"
echo "PICERL Documentation Migration - Phases 2-5"
echo "================================================================"

# Phase 2: Git Backup & Tagging
echo ""
echo "Phase 2: Creating Git Backup..."
cd /home/suhlabs/projects/suhlabs/aiops-substrate

# Create timestamped backup
BACKUP_FILE="../docs-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
tar -czf "$BACKUP_FILE" docs/
echo "✅ Backup created: $BACKUP_FILE"

# Create cleanup branch
git checkout -b docs-picerl-cleanup
echo "✅ Created branch: docs-picerl-cleanup"

# Tag pre-cleanup state
git tag "pre-picerl-cleanup-$(date +%Y%m%d)"
echo "✅ Tagged current state"

# Phase 3: Create Archive Directories
echo ""
echo "Phase 3: Creating Archive Structure..."
mkdir -p docs/ARCHIVE docs/BUSINESS
echo "✅ Created docs/ARCHIVE/ and docs/BUSINESS/"

# Phase 4: Move Files to Archive
echo ""
echo "Phase 4: Moving Files to Archive..."

# Fully migrated docs (move to ARCHIVE)
echo "Moving fully migrated docs to ARCHIVE..."
mv docs/ANTIGRAVITY-ARCHITECTURE.md docs/ARCHIVE/ 2>/dev/null || echo "  (already moved or not found)"
mv docs/CEDAR-ZERO-TRUST.md docs/ARCHIVE/ 2>/dev/null || echo "  (already moved or not found)"

# Deployment guides (consolidated into OPS-PREP/OPS-RECOVERY)
mv docs/FAMILY-SERVICES-APPLIANCE-DEPLOYMENT.md docs/ARCHIVE/ 2>/dev/null || echo "  (already moved)"
mv docs/FAMILY-SERVICES-APPLIANCE-ASSEMBLY.md docs/ARCHIVE/ 2>/dev/null || echo "  (already moved)"
mv docs/FAMILY-SERVICES-APPLIANCE-HARDWARE.md docs/ARCHIVE/ 2>/dev/null || echo "  (already moved)"
mv docs/FAMILY-SERVICES-APPLIANCE-BOM.md docs/ARCHIVE/ 2>/dev/null || echo "  (already moved)"
mv docs/AI-OPS-SEC-QUICKSTART.md docs/ARCHIVE/ 2>/dev/null || echo "  (already moved)"
mv docs/INTEGRATION-GUIDE.md docs/ARCHIVE/ 2>/dev/null || echo "  (already moved)"

# Secret management (consolidated into SEC-PREP)
mv docs/SECRET-MANAGEMENT.md docs/ARCHIVE/ 2>/dev/null || echo "  (already moved)"

# Delete duplicate (SECRETS-MANAGEMENT.md is duplicate of SECRET-MANAGEMENT.md)
rm -f docs/SECRETS-MANAGEMENT.md 2>/dev/null || echo "  (already deleted)"

# Day-N docs (consolidated into OPS-LESSONS)
mv docs/DAY-4-COMPLETE.md docs/ARCHIVE/ 2>/dev/null || echo "  (already moved)"
mv docs/DAY-5-COMPLETE.md docs/ARCHIVE/ 2>/dev/null || echo "  (already moved)"
mv docs/DAY-6-COMPLETE.md docs/ARCHIVE/ 2>/dev/null || echo "  (already moved)"
mv docs/DAY-7-INTEGRATION.md docs/ARCHIVE/ 2>/dev/null || echo "  (already moved)"
mv docs/DAY-8-PLAN.md docs/ARCHIVE/ 2>/dev/null || echo "  (already moved)"
mv docs/day-4-ansible-learning-guide.md docs/ARCHIVE/ 2>/dev/null || echo "  (already moved)"
mv docs/day-4-pki-learning-guide.md docs/ARCHIVE/ 2>/dev/null || echo "  (already moved)"

# Troubleshooting (consolidated into OPS-ERADICATION)
mv docs/WEEK2-TROUBLESHOOTING.md docs/ARCHIVE/ 2>/dev/null || echo "  (already moved)"
mv docs/BUGFIX-vault-bootstrap-unseal.md docs/ARCHIVE/ 2>/dev/null || echo "  (already moved)"
mv docs/vault-poc-issue-report.md docs/ARCHIVE/ 2>/dev/null || echo "  (already moved)"
mv docs/medium-severity-fixes.md docs/ARCHIVE/ 2>/dev/null || echo "  (already moved)"
mv docs/gaps.md docs/ARCHIVE/ 2>/dev/null || echo "  (already moved)"
mv docs/dns-troubleshooting-guide.md docs/ARCHIVE/ 2>/dev/null || echo "  (already moved)"

# Architecture docs (consolidated into OPS-PREP)
mv docs/ai-ops-sec-automation-architecture.md docs/ARCHIVE/ 2>/dev/null || echo "  (already moved)"
mv docs/vkaci-enhanced-cmdb-architecture.md docs/ARCHIVE/ 2>/dev/null || echo "  (already moved)"
mv docs/autonomous-validation-analysis.md docs/ARCHIVE/ 2>/dev/null || echo "  (already moved)"
mv docs/k8s-graph-relationships.md docs/ARCHIVE/ 2>/dev/null || echo "  (already moved)"

# Operational guides (consolidated into OPS-IDENTIFICATION/OPS-CONTAINMENT)
mv docs/PRODUCTION-SCRIPT-SUMMARY.md docs/ARCHIVE/ 2>/dev/null || echo "  (already moved)"
mv docs/TMUX-MASTERY-GUIDE.md docs/ARCHIVE/ 2>/dev/null || echo "  (already moved)"
mv docs/VISUAL-ENVIRONMENT-INDICATORS.md docs/ARCHIVE/ 2>/dev/null || echo "  (already moved)"
mv docs/ENVIRONMENT-STRATEGY-ANALYSIS.md docs/ARCHIVE/ 2>/dev/null || echo "  (already moved)"
mv docs/CI-CD-PIPELINE.md docs/ARCHIVE/ 2>/dev/null || echo "  (already moved)"
mv docs/DOCUMENTATION-GOVERNANCE.md docs/ARCHIVE/ 2>/dev/null || echo "  (already moved)"

# Security docs (consolidated)
mv docs/security-as-code-oscal.md docs/ARCHIVE/ 2>/dev/null || echo "  (already moved)"

# System design (partially consolidated - keep for reference)
mv docs/FAMILY-SERVICES-SYSTEM-DESIGN.md docs/ARCHIVE/ 2>/dev/null || echo "  (reference only, consolidated into OPS-PREP)"

# Move business docs to BUSINESS/
echo ""
echo "Moving business docs to BUSINESS..."
mv docs/FAMILY-SERVICES-BUSINESS-MODEL.md docs/BUSINESS/ 2>/dev/null || echo "  (already moved)"
mv docs/FAMILY-SERVICES-RESEARCH-ANALYSIS.md docs/BUSINESS/ 2>/dev/null || echo "  (already moved)"
mv docs/FAMILY-SERVICES-APPLIANCE-REVIEW.md docs/BUSINESS/ 2>/dev/null || echo " (already moved)"
mv docs/FAMILY-SERVICES-APPLIANCE.md docs/BUSINESS/ 2>/dev/null || echo "  (already moved)"
mv docs/PROFESSIONAL-MATERIALS.md docs/BUSINESS/ 2>/dev/null || echo " (already moved)"
mv docs/14-DAY-SPRINT.md docs/BUSINESS/ 2>/dev/null || echo "  (already moved)"

# Keep as-is (not archived)
echo ""
echo "Keeping as-is (active documents):"
echo "  - ai-agent-system-prompt.md (agent rules)"
echo "  - ai-agent-code-quality-policy.md (governance policy)"
echo "  - DESIGN-v2-GOVERNANCE.md (current governance design)"
echo "  - PICERL-CONSOLIDATION-PLAN.md (this migration plan)"
echo "  - MIGRATION-AUDIT.md (migration tracking)"
echo "  - lessons-learned.md (historical reference)"

# Phase 5: Create Archive README
echo ""
echo "Phase 5: Creating Archive Documentation..."

cat > docs/ARCHIVE/README.md <<'EOF'
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
EOF

echo "✅ Created docs/ARCHIVE/README.md"

# Git commit
echo ""
echo "Committing changes to git..."
git add docs/
git commit -m "docs: Reorganize documentation into PICERL framework

- Created 12 PICERL documents (6 OPS, 6 SEC)
- Archived 32 legacy docs to docs/ARCHIVE/
- Moved 6 business docs to docs/BUSINESS/
- Applied layered progressive disclosure structure

See MIGRATION-AUDIT.md for full content mapping."

echo "✅ Changes committed"

echo ""
echo "================================================================"
echo "Migration Complete!"
echo "================================================================"
echo ""
echo "Summary:"
echo "  - 12 new PICERL documents created"
echo "  - ~35 docs archived to docs/ARCHIVE/"
echo "  - 6 business docs moved to docs/BUSINESS/"
echo "  - Branch: docs-picerl-cleanup"
echo "  - Backup: $BACKUP_FILE"
echo ""
echo "Next steps:"
echo "  1. Review the new PICERL docs"
echo "  2. Test all internal links"
echo "  3. Update README.md with new structure"
echo "  4. Merge to main: git checkout main && git merge docs-picerl-cleanup"
