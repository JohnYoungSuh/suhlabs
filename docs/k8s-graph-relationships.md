# Kubernetes Graph Database Relationships

## Overview
This document defines the top 10 most valuable Kubernetes resource relationships for diagnostic and observability purposes using Neo4j and Cypher queries.

## Top 10 Diagnostic Relationships

### 1. Service → Pod (EXPOSES)
**Purpose**: Track which pods are exposed by which services
**Diagnostic Value**: Identify misconfigured services, orphaned pods

**Cypher Query**:
```cypher
MATCH (s:Service)-[:EXPOSES]->(p:Pod)
WHERE p.status <> 'Running'
RETURN s.name, p.name, p.status
```

**Example Output**:
```
nginx-service, nginx-pod-xyz, CrashLoopBackOff
```

---

### 2. Certificate → Secret (CREATES_SECRET)
**Purpose**: Track certificates and their associated secrets
**Diagnostic Value**: Identify expired certificates, missing secrets

**Cypher Query**:
```cypher
MATCH (c:Certificate)-[:CREATES_SECRET]->(s:Secret)
WHERE c.notAfter < datetime()
RETURN c.name, s.name, 'EXPIRED'
```

**Example Output**:
```
vault-tls, vault-tls-secret, EXPIRED
```

---

### 3. Certificate → Issuer (USES_ISSUER)
**Purpose**: Track which issuer created which certificates
**Diagnostic Value**: Identify issuer failures, certificate issuance patterns

**Cypher Query**:
```cypher
MATCH (c:Certificate)-[:USES_ISSUER]->(i:Issuer)
WHERE i.status <> 'Ready'
RETURN c.name, i.name, 'ISSUER_NOT_READY'
```

**Example Output**:
```
app-cert, vault-issuer, ISSUER_NOT_READY
```

---

### 4. NetworkPolicy → Namespace (PROTECTS)
**Purpose**: Track network policies protecting namespaces
**Diagnostic Value**: Identify unprotected namespaces, policy gaps

**Cypher Query**:
```cypher
MATCH (ns:Namespace)
WHERE NOT EXISTS((ns)<-[:PROTECTS]-(:NetworkPolicy))
RETURN ns.name, 'NO_NETWORK_POLICY'
```

**Example Output**:
```
production, NO_NETWORK_POLICY
```

---

### 5. Pod → RestartCause (RESTARTED_DUE_TO)
**Purpose**: Track why pods are restarting
**Diagnostic Value**: Identify restart patterns, stability issues

**Cypher Query**:
```cypher
MATCH (p:Pod)-[:RESTARTED_DUE_TO]->(rc:RestartCause)
WHERE p.restartCount > 5
RETURN p.name, rc.reason, p.restartCount
```

**Example Output**:
```
api-pod-abc, OOMKilled, 12
```

---

### 6. Pod → Node (RUNS_ON)
**Purpose**: Track pod placement on nodes
**Diagnostic Value**: Identify node failures, scheduling issues

**Cypher Query**:
```cypher
MATCH (n:Node)<-[:RUNS_ON]-(p:Pod {phase: 'Failed'})
RETURN n.name, COUNT(p) as failedPods
ORDER BY failedPods DESC
```

**Example Output**:
```
worker-node-2, 8
```

---

### 7. Pod → Secret (USES)
**Purpose**: Track which secrets are used by which pods
**Diagnostic Value**: Identify missing secrets, unused secrets

**Cypher Query**:
```cypher
MATCH (p:Pod)-[:USES]->(s:Secret)
WHERE NOT EXISTS(s.data)
RETURN p.name, s.name, 'SECRET_MISSING'
```

**Example Output**:
```
app-pod, db-credentials, SECRET_MISSING
```

---

### 8. Deployment → Pod (SPAWNS)
**Purpose**: Track deployment-to-pod relationships
**Diagnostic Value**: Identify deployment rollout issues

**Cypher Query**:
```cypher
MATCH (d:Deployment)-[:SPAWNS]->(p:Pod)
WHERE p.status <> 'Running'
RETURN d.name, COUNT(p) as unhealthyPods
```

**Example Output**:
```
nginx-deployment, 3
```

---

### 9. HelmRelease → Resource (MANAGES)
**Purpose**: Track Helm-managed resources and detect config drift
**Diagnostic Value**: Identify override mismatches, failed deployments

**Cypher Query**:
```cypher
MATCH (h:HelmRelease)-[:MANAGES]->(r:Resource)
WHERE r.liveValue <> h.valuesOverride
RETURN h.name, r.name, 'OVERRIDE_MISMATCH'
```

**Example Output**:
```
vault, vault-agent, OVERRIDE_MISMATCH
```

**Why This Relationship Matters**:
- You've hit Helm override mismatches — values.yaml not reflected in live resources
- Prevents: Silent config drift, failed deployments due to incorrect assumptions
- Example: Vault agent injection not working because Helm chart values weren't applied

---

### 10. [Reserved]
**Purpose**: Reserved for future discovery needs
**Candidates**:
- VaultPolicy → ServiceAccount (AUTHORIZES)
- PVC → StorageClass (USES_STORAGE)
- Pod → AIAnnotation (HAS_INSIGHT)

---

## Deprecated Relationships

### ❌ Pod → Certificate (REMOVED)
**Reason for Removal**: Pods don't mount certificates directly. They mount secrets created by cert-manager.

**Existing Coverage**:
- Relationship #2: Certificate → Secret (CREATES_SECRET)
- Relationship #7: Pod → Secret (USES)

**Conclusion**: Relationship #10 (Pod → Certificate) adds no diagnostic value when you already have Certificate → Secret and Pod → Secret relationships.

---

## Query Examples

### Find All Unprotected Namespaces
```cypher
MATCH (ns:Namespace)
WHERE NOT EXISTS((ns)<-[:PROTECTS]-(:NetworkPolicy))
RETURN ns.name
```

### Find Pods on Failed Nodes
```cypher
MATCH (n:Node {status: 'NotReady'})<-[:RUNS_ON]-(p:Pod)
RETURN n.name, p.name, p.namespace
```

### Find Expired Certificates
```cypher
MATCH (c:Certificate)-[:CREATES_SECRET]->(s:Secret)
WHERE c.notAfter < datetime()
RETURN c.name, c.notAfter, s.name
```

### Find Config Drift in Helm Releases
```cypher
MATCH (h:HelmRelease)-[:MANAGES]->(r:Resource)
WHERE r.liveValue <> h.valuesOverride
RETURN h.name, r.kind, r.name, r.liveValue, h.valuesOverride
```

---

## Implementation Notes

### Graph Database Schema
```
Nodes:
- Service
- Pod
- Certificate
- Secret
- Issuer
- Namespace
- NetworkPolicy
- Node
- RestartCause
- Deployment
- HelmRelease
- Resource

Relationships:
- EXPOSES
- CREATES_SECRET
- USES_ISSUER
- PROTECTS
- RESTARTED_DUE_TO
- RUNS_ON
- USES
- SPAWNS
- MANAGES
```

### Data Collection
- Use Kubernetes API watchers to populate graph
- Update graph in real-time as resources change
- Maintain historical data for trend analysis

### Performance Considerations
- Index frequently queried properties (name, namespace, status)
- Use relationship direction for efficient traversal
- Cache common diagnostic queries

---

## References
- [Neo4j Cypher Documentation](https://neo4j.com/docs/cypher-manual/)
- [Kubernetes API Reference](https://kubernetes.io/docs/reference/kubernetes-api/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)

---

**Last Updated**: 2025-11-15
**Version**: 1.0
