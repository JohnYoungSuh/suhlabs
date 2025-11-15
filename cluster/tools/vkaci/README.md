# VKACI - Visibility Kubernetes Analysis and Configuration Inventory

**Graph-based Kubernetes discovery and analysis tool**

## Overview

VKACI provides comprehensive visibility into your Kubernetes cluster using Neo4j graph database technology. It discovers pods, services, namespaces, network flows, and custom resources, then builds a relationship graph for powerful querying and analysis.

## Features

- **🔍 Comprehensive Discovery**: Pods, Services, Namespaces, NetworkPolicies, Custom Resources
- **📊 Graph-based Analysis**: Relationship mapping using Neo4j
- **🌐 Network Flow Tracking**: Visualize service-to-service communication
- **🔐 Security Auditing**: Identify security risks and misconfigurations
- **📜 Certificate Management**: Track certificate chains and expiration
- **🎯 Cypher-First Approach**: Powerful queries with graph database

## Architecture

```
Kubernetes API → Python Collector → Neo4j Graph DB → Cypher Queries → CLI/Visualization
```

## Quick Start

### 1. Deploy Neo4j and VKACI

```bash
# Deploy Neo4j graph database
kubectl apply -f deploy/neo4j/

# Deploy VKACI collector
kubectl apply -f deploy/vkaci/

# Wait for pods to be ready
kubectl wait --for=condition=Ready pod -l app=vkaci -n vkaci --timeout=300s
```

### 2. Run Discovery

```bash
# Exec into VKACI pod
kubectl exec -it -n vkaci deploy/vkaci-collector -- bash

# Run full discovery
python3 collector.py --collect-all

# Or run specific collectors
python3 collector.py --collect-pods
python3 collector.py --collect-services
python3 collector.py --collect-custom-resources
```

### 3. Query with CLI

```bash
# List all pods
vkaci pods

# Show service-to-pod mapping
vkaci services

# Analyze network flows
vkaci network-flows

# Find security issues
vkaci security-audit

# Discover certificates
vkaci certificates
```

### 4. Query with Neo4j Browser

```bash
# Port-forward Neo4j
kubectl port-forward -n vkaci svc/neo4j 7474:7474 7687:7687

# Open browser: http://localhost:7474
# Run Cypher queries from queries/ directory
```

## Discovery Capabilities

### Pod Discovery
- All pods with namespace, labels, status
- Resource requests/limits
- Failed/CrashLooping pods
- Pods without resource limits

### Service Discovery
- Service-to-pod mapping
- Services without endpoints (broken selectors)
- External services (LoadBalancer/NodePort)
- Port conflicts

### Namespace Isolation
- Network policy coverage
- Unprotected namespaces
- Cross-namespace communication
- Default namespace usage (anti-pattern)

### Network Flows
- Service-to-service communication
- Policy enforcement status (ALLOWED/DENIED)
- Top talkers (most connections)
- Suspicious patterns (failed attempts, high bandwidth)

### Custom Resources
- Certificate discovery and status
- Expiring certificates (< 30 days)
- Issuer/ClusterIssuer mapping
- Certificate chain validation
- DNS name validation against Vault PKI

## Cypher Query Examples

### Find all pods in a namespace
```cypher
MATCH (n:Namespace {name: 'default'})<-[:BELONGS_TO]-(p:Pod)
RETURN p.name, p.phase, p.ip
ORDER BY p.name;
```

### Service dependency graph
```cypher
MATCH path = (s1:Service)-[:DEPENDS_ON*1..3]->(s2:Service)
RETURN [node IN nodes(path) | node.name] as chain;
```

### Security audit - find privileged pods
```cypher
MATCH (p:Pod)-[:BELONGS_TO]->(n:Namespace)
WHERE p.privileged = true OR p.hostNetwork = true
RETURN n.name, p.name, p.privileged, p.hostNetwork;
```

### Certificate expiration tracking
```cypher
MATCH (cert:CustomResource {kind: 'Certificate'})
WHERE datetime(cert.notAfter) < datetime() + duration('P30D')
RETURN cert.name, cert.notAfter,
       duration.inDays(datetime(), datetime(cert.notAfter)).days as daysLeft
ORDER BY daysLeft;
```

### Network policy coverage
```cypher
MATCH (n:Namespace)
OPTIONAL MATCH (n)<-[:BELONGS_TO]-(np:NetworkPolicy)
RETURN n.name, count(np) as policies,
       CASE WHEN count(np) = 0 THEN 'UNPROTECTED' ELSE 'PROTECTED' END as status
ORDER BY status, n.name;
```

## CLI Commands

```bash
# Pod discovery
vkaci pods                           # All pods
vkaci pods --namespace default       # Pods in specific namespace
vkaci pods --failed                  # Failed/CrashLooping pods
vkaci pods --no-limits               # Pods without resource limits

# Service discovery
vkaci services                       # All services
vkaci services --broken              # Services without endpoints
vkaci services --external            # LoadBalancer/NodePort services

# Network analysis
vkaci network-flows                  # All network flows
vkaci network-flows --denied         # Denied flows (policy violations)
vkaci network-flows --suspicious     # Suspicious patterns

# Security auditing
vkaci security-audit                 # Full security scan
vkaci security-audit --privileged    # Privileged containers
vkaci security-audit --unprotected   # Namespaces without network policies

# Certificate management
vkaci certificates                   # All certificates
vkaci certificates --expiring        # Expiring within 30 days
vkaci certificates --failed          # Failed certificate issuance

# Namespace analysis
vkaci namespaces                     # All namespaces
vkaci namespaces --unprotected       # No network policies
vkaci namespaces --usage             # Resource usage per namespace

# Custom resources
vkaci custom-resources               # All CRDs
vkaci custom-resources --type Certificate  # Specific type
vkaci custom-resources --orphaned    # No owner references
```

## Use Cases

### 1. Troubleshooting Service Discovery Issues

```bash
# Find services without endpoints
vkaci services --broken

# Check selector mismatch
MATCH (s:Service)
WHERE NOT (s)-[:EXPOSES]->(:Pod)
RETURN s.namespace, s.name, s.selector;
```

**Example Output:**
```
namespace    service          selector
-----------  ---------------  ------------------------
default      ai-ops-agent     {'app': 'ai-ops-agent'}
```

### 2. Certificate Expiration Monitoring

```bash
# Find certificates expiring soon
vkaci certificates --expiring

# Or with Cypher
MATCH (cert:CustomResource {kind: 'Certificate'})
WHERE datetime(cert.notAfter) < datetime() + duration('P30D')
RETURN cert.namespace + '/' + cert.name as certificate,
       duration.inDays(datetime(), datetime(cert.notAfter)).days as daysLeft
ORDER BY daysLeft;
```

### 3. Security Auditing

```bash
# Full security audit
vkaci security-audit

# Covers:
# - Privileged containers
# - hostNetwork usage
# - Missing network policies
# - Pods without resource limits
# - Default namespace usage
# - Missing probes
```

### 4. Network Flow Analysis

```bash
# Find cross-namespace communication
MATCH (srcNs:Namespace)<-[:BELONGS_TO]-(srcPod:Pod),
      (dstNs:Namespace)<-[:BELONGS_TO]-(dstSvc:Service),
      (srcPod)-[:COMMUNICATES_WITH]->(dstSvc)
WHERE srcNs.name <> dstNs.name
RETURN srcNs.name, srcPod.name, dstNs.name, dstSvc.name;
```

### 5. Dependency Mapping

```bash
# Map full dependency chain for a service
MATCH path = (s:Service {name: 'ai-ops-agent'})-[:DEPENDS_ON*1..5]->(dep)
RETURN [node IN nodes(path) | node.name] as chain;
```

## Data Model

### Nodes
- `Namespace` - Kubernetes namespaces
- `Pod` - Running pods
- `Service` - Services
- `NetworkPolicy` - Network policies
- `CustomResource` - CRDs (Certificate, Issuer, etc.)
- `Secret` - Secrets
- `Node` - Kubernetes nodes

### Relationships
- `BELONGS_TO` - Resource belongs to namespace
- `EXPOSES` - Service exposes pods
- `COMMUNICATES_WITH` - Pod communicates with service
- `ALLOWS` / `DENIES` - Network policy rules
- `MOUNTS` - Pod mounts volume/secret
- `USES_ISSUER` - Certificate uses issuer
- `CREATES_SECRET` - Certificate creates secret
- `DEPENDS_ON` - Service dependency
- `OWNED_BY` - Owner reference

## Configuration

### Environment Variables

```bash
# Neo4j connection
NEO4J_URI=bolt://neo4j.vkaci.svc.cluster.local:7687
NEO4J_USER=neo4j
NEO4J_PASSWORD=<from-secret>

# Collection frequency (CronJob)
COLLECTION_SCHEDULE="*/5 * * * *"  # Every 5 minutes

# Data retention
DATA_RETENTION_DAYS=7

# Kubernetes API
KUBERNETES_SERVICE_HOST=kubernetes.default.svc.cluster.local
```

### Collection Modes

```bash
# Full collection (all resources)
python3 collector.py --collect-all

# Incremental (only changes)
python3 collector.py --incremental

# Specific resources
python3 collector.py --collect-pods --collect-services

# With metrics
python3 collector.py --collect-all --with-metrics
```

## Installation

### Prerequisites

- Kubernetes 1.24+
- 2GB RAM for Neo4j
- 512MB RAM for VKACI collector

### Deploy

```bash
# Create namespace
kubectl create namespace vkaci

# Deploy Neo4j
kubectl apply -f deploy/neo4j/

# Deploy VKACI collector
kubectl apply -f deploy/vkaci/

# Verify
kubectl get pods -n vkaci
```

### Access Neo4j Browser

```bash
# Port forward
kubectl port-forward -n vkaci svc/neo4j 7474:7474

# Open http://localhost:7474
# Username: neo4j
# Password: kubectl get secret neo4j-auth -n vkaci -o jsonpath='{.data.password}' | base64 -d
```

## Development

### Run Locally

```bash
# Install dependencies
pip3 install -r requirements.txt

# Set environment variables
export NEO4J_URI=bolt://localhost:7687
export NEO4J_USER=neo4j
export NEO4J_PASSWORD=password

# Run collector
python3 collector.py --collect-all

# Run CLI
python3 vkaci.py pods
```

### Test Cypher Queries

```bash
# Copy queries to Neo4j Browser
cat queries/01-pod-discovery.cypher

# Or run via CLI
cat queries/01-pod-discovery.cypher | python3 run-query.py
```

## Performance

- **Collection Time**: ~30s for 100 pods
- **Storage**: ~50MB for 1000 resources
- **Query Response**: < 100ms for most queries
- **Retention**: 7 days (configurable)

## Security

- **RBAC**: Read-only ClusterRole for Kubernetes API
- **Neo4j Auth**: Credentials stored in Kubernetes Secrets
- **Network Policies**: VKACI namespace isolated
- **TLS**: Optional TLS for Neo4j connections

## Troubleshooting

### Collector not running

```bash
kubectl logs -n vkaci deploy/vkaci-collector
kubectl describe pod -n vkaci -l app=vkaci-collector
```

### No data in Neo4j

```bash
# Check if collection ran
kubectl logs -n vkaci deploy/vkaci-collector | grep "Collection complete"

# Manually trigger
kubectl exec -n vkaci deploy/vkaci-collector -- python3 collector.py --collect-all

# Verify in Neo4j
MATCH (n) RETURN count(n);
```

### Query performance issues

```bash
# Add indexes
CREATE INDEX pod_name FOR (p:Pod) ON (p.name);
CREATE INDEX service_name FOR (s:Service) ON (s.name);
CREATE INDEX namespace_name FOR (n:Namespace) ON (n.name);
```

## References

- [Neo4j Cypher Documentation](https://neo4j.com/docs/cypher-manual/current/)
- [Kubernetes Python Client](https://github.com/kubernetes-client/python)
- [VKACI Design Document](./DESIGN.md)
- [Query Examples](./queries/)

## License

MIT License - See LICENSE file

## Contributing

Contributions welcome! Please submit pull requests with:
- New Cypher queries for discovery patterns
- Python collector improvements
- Visualization enhancements
- Documentation updates
