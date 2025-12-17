# Security as Code with OSCAL Integration

## Overview

This document outlines the plan for implementing automated security compliance using OSCAL (Open Security Controls Assessment Language), STIG (Security Technical Implementation Guides), and Neo4j graph database queries.

**Status**: Planned (Not Yet Implemented)
**Priority**: Medium (Post-MVP)
**Dependencies**: Neo4j deployment, K8s graph data collection

---

## Architecture

### Component Layout

```
security-ops namespace
├── oscal-scanner (Deployment)
│   ├── Scans cluster resources via K8s API
│   ├── Executes STIG compliance checks (Cypher queries)
│   ├── Generates OSCAL Component Definitions
│   └── Auto-generates POA&Ms for findings
├── neo4j (StatefulSet)
│   ├── Graph database for K8s resources
│   ├── Stores compliance control mappings
│   └── Historical compliance data
└── oscal-api (Deployment)
    ├── REST API for OSCAL documents
    ├── POA&M management
    └── Audit evidence export
```

### Why NOT kube-system or Control Plane

**Decision**: Use dedicated `security-ops` namespace

**Rationale**:
- ✅ Separation of concerns
- ✅ RBAC isolation
- ✅ Resource quotas/limits
- ✅ Network policy controls
- ✅ Standard Kubernetes deployment (easier than static pods)
- ✅ High availability support

**Rejected Options**:
- ❌ **kube-system**: Reserved for K8s core components
- ❌ **control-plane**: Requires static pods, no HA, distribution-specific

---

## OSCAL Integration

### 1. Component Definition Generation

**Purpose**: Auto-generate OSCAL Component Definitions from live infrastructure

**Data Flow**:
```
K8s API → Neo4j Graph → Cypher Queries → OSCAL JSON/XML
```

**Example Cypher → OSCAL Mapping**:

```cypher
// Find all NetworkPolicy implementations (NIST AC-4: Information Flow Enforcement)
MATCH (ns:Namespace)<-[:PROTECTS]-(np:NetworkPolicy)
RETURN {
  control_id: "AC-4",
  component_type: "NetworkPolicy",
  implementations: collect({
    namespace: ns.name,
    policy_name: np.name,
    ingress_rules: np.ingress,
    egress_rules: np.egress
  })
}
```

**OSCAL Output**:
```json
{
  "component-definition": {
    "uuid": "...",
    "metadata": {
      "title": "Kubernetes Security Controls",
      "last-modified": "2025-11-15T...",
      "version": "1.0"
    },
    "components": [{
      "uuid": "...",
      "type": "software",
      "title": "Network Policies",
      "description": "Kubernetes NetworkPolicy resources enforcing AC-4",
      "control-implementations": [{
        "uuid": "...",
        "source": "https://doi.org/10.6028/NIST.SP.800-53r5",
        "implemented-requirements": [{
          "uuid": "...",
          "control-id": "ac-4",
          "description": "Information flow enforced via NetworkPolicy in namespaces: ai-ops, vault, monitoring"
        }]
      }]
    }]
  }
}
```

---

### 2. System Security Plan (SSP) Automation

**Cypher Query for SSP Evidence**:

```cypher
// AC-2: Account Management (Service Accounts)
MATCH (sa:ServiceAccount)-[:HAS_RBAC_ROLE]->(r:Role)
MATCH (sa)<-[:USES_SERVICE_ACCOUNT]-(p:Pod)
RETURN {
  control: "AC-2",
  evidence_type: "service_account_inventory",
  service_account: sa.name,
  namespace: sa.namespace,
  role: r.name,
  permissions: r.rules,
  used_by_pods: collect(p.name),
  last_verified: datetime()
}
```

**SSP Section Auto-Population**:
- **AC-2 (Account Management)**: Service account inventory from graph
- **AC-3 (Access Enforcement)**: RBAC role mappings
- **AC-4 (Information Flow)**: NetworkPolicy configurations
- **AU-2 (Audit Events)**: Vault audit log configuration
- **SC-7 (Boundary Protection)**: Ingress/egress rules

---

### 3. Assessment Results (SAR) Generation

**Continuous Assessment via Cypher**:

```cypher
// Daily compliance assessment
MATCH (control:NISTControl)
OPTIONAL MATCH (control)-[:IMPLEMENTED_BY]->(resource)
OPTIONAL MATCH (control)-[:HAS_FINDING]->(finding:Finding {status: "OPEN"})
RETURN
  control.id,
  control.title,
  CASE
    WHEN count(resource) > 0 AND count(finding) = 0 THEN "SATISFIED"
    WHEN count(resource) > 0 AND count(finding) > 0 THEN "PARTIALLY-SATISFIED"
    ELSE "NOT-SATISFIED"
  END as implementation_status,
  count(resource) as evidence_count,
  count(finding) as open_findings,
  datetime() as assessment_date
```

**OSCAL Assessment Result**:
```json
{
  "assessment-results": {
    "uuid": "...",
    "metadata": {
      "title": "Kubernetes Security Assessment",
      "last-modified": "2025-11-15T..."
    },
    "results": [{
      "uuid": "...",
      "title": "Automated Daily Scan",
      "start": "2025-11-15T00:00:00Z",
      "end": "2025-11-15T00:15:00Z",
      "findings": [{
        "uuid": "...",
        "title": "AC-4: Missing NetworkPolicy",
        "description": "Namespace 'production' lacks NetworkPolicy",
        "implementation-statement-uuid": "...",
        "related-observations": ["..."]
      }]
    }]
  }
}
```

---

## STIG Automation

### STIG Compliance as Cypher Queries

**File Structure**:
```
cypher/stig-checks/
├── v-242376-network-policies.cypher      # NetworkPolicy required
├── v-242377-pod-security-standards.cypher # Pod Security Admission
├── v-242378-rbac-least-privilege.cypher   # RBAC minimization
├── v-242379-secrets-encryption.cypher     # Secrets at rest
├── v-242380-audit-logging.cypher          # Audit log enabled
└── v-242381-cert-rotation.cypher          # Certificate lifecycle
```

### Example: V-242376 (Network Policies Required)

**STIG Requirement**: "Kubernetes must have network policies that restrict pod-to-pod traffic"

**Cypher Implementation**:
```cypher
// V-242376: Find namespaces without NetworkPolicies
MATCH (ns:Namespace)
WHERE NOT EXISTS((ns)<-[:PROTECTS]-(:NetworkPolicy))
  AND ns.name NOT IN ['kube-system', 'kube-public', 'kube-node-lease']
RETURN {
  stig_id: "V-242376",
  severity: "CAT II",
  status: "OPEN",
  finding_details: ns.name + " namespace lacks NetworkPolicy",
  namespace: ns.name,
  remediation: "Deploy default-deny NetworkPolicy to namespace",
  poam_required: true,
  check_date: datetime()
}
```

**Output Format**:
```json
{
  "stig_id": "V-242376",
  "severity": "CAT II",
  "status": "OPEN",
  "finding_details": "production namespace lacks NetworkPolicy",
  "namespace": "production",
  "remediation": "Deploy default-deny NetworkPolicy to namespace",
  "poam_required": true,
  "check_date": "2025-11-15T10:30:00Z"
}
```

---

### Example: V-242378 (RBAC Least Privilege)

**STIG Requirement**: "Service accounts must use least privilege RBAC"

**Cypher Implementation**:
```cypher
// V-242378: Find overly permissive RBAC roles
MATCH (sa:ServiceAccount)-[:HAS_RBAC_ROLE]->(r:Role)
WHERE ANY(rule IN r.rules WHERE
  '*' IN rule.verbs OR
  '*' IN rule.resources OR
  '*' IN rule.apiGroups
)
RETURN {
  stig_id: "V-242378",
  severity: "CAT I",
  status: "OPEN",
  finding_details: "ServiceAccount " + sa.name + " has wildcard permissions",
  service_account: sa.name,
  namespace: sa.namespace,
  role: r.name,
  excessive_permissions: [rule IN r.rules WHERE '*' IN rule.verbs | rule],
  remediation: "Replace wildcard (*) with specific resource/verb grants",
  poam_required: true,
  check_date: datetime()
}
```

---

### Example: V-242381 (Certificate Rotation)

**STIG Requirement**: "Certificates must be rotated before expiration"

**Cypher Implementation**:
```cypher
// V-242381: Find certificates expiring within 30 days
MATCH (c:Certificate)-[:CREATES_SECRET]->(s:Secret)
WHERE duration.between(datetime(), c.notAfter).days < 30
RETURN {
  stig_id: "V-242381",
  severity: "CAT II",
  status: CASE
    WHEN c.renewBefore IS NOT NULL THEN "NOT_A_FINDING"
    ELSE "OPEN"
  END,
  finding_details: "Certificate " + c.name + " expires in " +
                   duration.between(datetime(), c.notAfter).days + " days",
  certificate: c.name,
  namespace: c.namespace,
  expiry_date: c.notAfter,
  auto_renewal_configured: c.renewBefore IS NOT NULL,
  remediation: "Configure cert-manager with renewBefore parameter",
  poam_required: c.renewBefore IS NULL,
  check_date: datetime()
}
```

---

## POA&M (Plan of Action & Milestones) Generation

### Auto-Generate POA&Ms from Findings

**Cypher Query**:
```cypher
// Generate POA&M for all STIG findings
MATCH (finding:Finding {status: "OPEN"})
WITH finding.stig_id as stig_id,
     collect(finding) as findings,
     finding.severity as severity
RETURN {
  poam_id: "POAM-" + toString(date()) + "-" + stig_id,
  weakness_name: stig_id + ": " + findings[0].finding_details,
  severity: severity,
  affected_resources: [f IN findings | f.namespace + "/" + f.resource_name],
  weakness_description: findings[0].remediation,
  milestones: [
    {
      milestone_id: 1,
      description: "Identify all affected resources",
      scheduled_completion: date() + duration({days: 7}),
      status: "Completed"
    },
    {
      milestone_id: 2,
      description: "Deploy remediation (e.g., NetworkPolicies)",
      scheduled_completion: date() + duration({days: 30}),
      status: "Ongoing"
    },
    {
      milestone_id: 3,
      description: "Verify compliance and close finding",
      scheduled_completion: date() + duration({days: 45}),
      status: "Scheduled"
    }
  ],
  resources_required: "DevSecOps team - 4 hours",
  scheduled_completion_date: date() + duration({days: 45}),
  poam_status: "Ongoing",
  point_of_contact: "security-ops@suhlabs.com"
}
```

**OSCAL POA&M Output**:
```json
{
  "plan-of-action-and-milestones": {
    "uuid": "...",
    "metadata": {
      "title": "Kubernetes STIG POA&M",
      "last-modified": "2025-11-15T..."
    },
    "poam-items": [{
      "uuid": "...",
      "title": "V-242376: Missing NetworkPolicies",
      "description": "5 namespaces lack NetworkPolicy controls",
      "related-findings": ["..."],
      "milestones": [{
        "uuid": "...",
        "title": "Deploy default-deny NetworkPolicies",
        "description": "Create and apply NetworkPolicy manifests",
        "scheduled-completion-date": "2025-12-15"
      }]
    }]
  }
}
```

---

## Continuous Compliance Monitoring

### Real-Time Compliance Dashboard

**Cypher Query**:
```cypher
// Overall compliance posture
MATCH (control:NISTControl)
OPTIONAL MATCH (control)-[:IMPLEMENTED_BY]->(resource)
OPTIONAL MATCH (control)-[:HAS_FINDING]->(finding:Finding {status: "OPEN"})
WITH
  count(DISTINCT control) as total_controls,
  count(DISTINCT CASE WHEN resource IS NOT NULL AND finding IS NULL THEN control END) as compliant,
  count(DISTINCT CASE WHEN resource IS NOT NULL AND finding IS NOT NULL THEN control END) as partial,
  count(DISTINCT CASE WHEN resource IS NULL THEN control END) as non_compliant
RETURN {
  total_controls: total_controls,
  compliant: compliant,
  partially_compliant: partial,
  non_compliant: non_compliant,
  compliance_percentage: toFloat(compliant) / total_controls * 100,
  last_assessment: datetime()
}
```

**Dashboard Metrics**:
- Overall compliance percentage
- Controls by status (SATISFIED, PARTIAL, NOT-SATISFIED)
- Open findings by severity (CAT I, CAT II, CAT III)
- POA&M completion rate
- Trend over time (daily/weekly/monthly)

---

## Implementation Phases

### Phase 1: Foundation (Weeks 1-2)

**Deliverables**:
- [ ] Create `security-ops` namespace in Terraform
- [ ] Deploy Neo4j StatefulSet
- [ ] Deploy K8s resource collector (populates Neo4j)
- [ ] Create basic graph schema (Pod, Service, Certificate, etc.)
- [ ] Validate data collection working

**Files to Create**:
```
infra/local/main.tf                    # Add security-ops namespace
cluster/security-ops/
├── neo4j/
│   ├── statefulset.yaml
│   ├── service.yaml
│   └── pvc.yaml
└── k8s-collector/
    ├── deployment.yaml
    ├── rbac.yaml                      # ClusterRole with read-only
    └── configmap.yaml
```

---

### Phase 2: STIG Automation (Weeks 3-4)

**Deliverables**:
- [ ] Write Cypher queries for top 10 STIGs
- [ ] Deploy STIG scanner pod
- [ ] Generate JSON findings reports
- [ ] Create daily scan CronJob

**Files to Create**:
```
cypher/stig-checks/
├── v-242376-network-policies.cypher
├── v-242377-pod-security-standards.cypher
├── v-242378-rbac-least-privilege.cypher
├── v-242379-secrets-encryption.cypher
├── v-242380-audit-logging.cypher
├── v-242381-cert-rotation.cypher
├── v-242382-api-server-auth.cypher
├── v-242383-etcd-encryption.cypher
├── v-242384-admission-controllers.cypher
└── v-242385-image-scanning.cypher

cluster/security-ops/stig-scanner/
├── deployment.yaml
├── cronjob.yaml                       # Daily scan at 2 AM
└── configmap.yaml                     # STIG check configuration
```

---

### Phase 3: OSCAL Generation (Weeks 5-6)

**Deliverables**:
- [ ] Python script: Neo4j → OSCAL Component Definition
- [ ] Python script: Neo4j → OSCAL Assessment Results
- [ ] REST API for OSCAL document retrieval
- [ ] OSCAL document versioning (Git)

**Files to Create**:
```
scripts/oscal/
├── generate-component-definition.py
├── generate-assessment-results.py
├── generate-ssp-evidence.py
└── requirements.txt

cluster/security-ops/oscal-api/
├── deployment.yaml
├── service.yaml
└── Dockerfile
```

---

### Phase 4: POA&M Automation (Weeks 7-8)

**Deliverables**:
- [ ] Auto-generate POA&Ms from STIG findings
- [ ] POA&M tracking workflow
- [ ] Integration with Git issues (optional)
- [ ] OSCAL POA&M export

**Files to Create**:
```
cypher/poam-generator/
├── create-poams.cypher
├── update-poam-status.cypher
└── close-poams.cypher

cluster/security-ops/poam-manager/
├── deployment.yaml
└── configmap.yaml
```

---

### Phase 5: Integration & Reporting (Weeks 9-10)

**Deliverables**:
- [ ] Grafana dashboards for compliance metrics
- [ ] Slack/email alerts for critical findings
- [ ] Monthly compliance report automation
- [ ] Audit evidence package export

**Files to Create**:
```
cluster/security-ops/grafana/
├── dashboards/
│   ├── compliance-overview.json
│   ├── stig-findings.json
│   └── poam-tracking.json
└── datasources/
    └── neo4j.yaml

scripts/reporting/
├── generate-monthly-report.py
└── export-audit-evidence.py
```

---

## Benefits

### 1. Automated Evidence Collection
- ✅ No manual compliance spreadsheets
- ✅ Real-time evidence from live infrastructure
- ✅ Auditable query history (Cypher queries in Git)

### 2. Continuous Compliance
- ✅ Daily STIG scans (CronJob)
- ✅ Immediate detection of drift
- ✅ Automated POA&M generation

### 3. Audit Readiness
- ✅ OSCAL-formatted documents (NIST standard)
- ✅ Point-in-time compliance snapshots
- ✅ Historical trend data

### 4. Reduced Manual Effort
- ✅ 90% reduction in compliance documentation time
- ✅ Automatic SSP updates as infrastructure changes
- ✅ Self-service OSCAL exports for auditors

---

## Integration with Existing Infrastructure

### Relationship to k8s-graph-relationships.md

This OSCAL implementation **extends** the existing graph relationships:

**Existing Relationships** (from `docs/k8s-graph-relationships.md`):
1. Service → Pod (EXPOSES)
2. Certificate → Secret (CREATES_SECRET)
3. Certificate → Issuer (USES_ISSUER)
4. NetworkPolicy → Namespace (PROTECTS)
5. Pod → RestartCause (RESTARTED_DUE_TO)
6. Pod → Node (RUNS_ON)
7. Pod → Secret (USES)
8. Deployment → Pod (SPAWNS)
9. HelmRelease → Resource (MANAGES)

**New Relationships for Compliance**:
10. NISTControl → Resource (IMPLEMENTED_BY)
11. Finding → Resource (AFFECTS)
12. POAM → Finding (REMEDIATES)
13. ServiceAccount → Role (HAS_RBAC_ROLE)
14. Pod → ServiceAccount (USES_SERVICE_ACCOUNT)

---

## Security Considerations

### RBAC for OSCAL Scanner

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: oscal-scanner
rules:
# Read-only access to all resources
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]

# NO write permissions (immutable scanning)
```

### Network Policies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: oscal-scanner-policy
  namespace: security-ops
spec:
  podSelector:
    matchLabels:
      app: oscal-scanner
  policyTypes:
  - Egress
  egress:
  # Only allow K8s API access
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 443  # K8s API server
  # Allow Neo4j access
  - to:
    - podSelector:
        matchLabels:
          app: neo4j
    ports:
    - protocol: TCP
      port: 7687  # Neo4j Bolt
```

---

## References

- [OSCAL Official Documentation](https://pages.nist.gov/OSCAL/)
- [NIST SP 800-53 Rev 5](https://doi.org/10.6028/NIST.SP.800-53r5)
- [Kubernetes STIG](https://www.stigviewer.com/stig/kubernetes/)
- [Neo4j Cypher Reference](https://neo4j.com/docs/cypher-manual/)
- [K8s Graph Relationships](./k8s-graph-relationships.md)

---

**Status**: Planning Document
**Next Steps**: Approve architecture → Phase 1 implementation
**Estimated Effort**: 10 weeks (2 engineers)
**ROI**: 90% reduction in compliance documentation overhead

---

**Last Updated**: 2025-11-15
**Version**: 1.0
**Author**: Security Automation Team
