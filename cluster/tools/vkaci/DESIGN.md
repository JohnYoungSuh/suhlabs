# VKACI - Visibility Kubernetes Analysis and Configuration Inventory

## Overview

VKACI is a Kubernetes discovery and analysis tool that provides comprehensive visibility into cluster resources, relationships, and network flows using graph database technology.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │   Pods   │  │ Services │  │Namespaces│  │   CRDs   │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
                  ┌──────────────────┐
                  │  VKACI Collector │
                  │   (Python)       │
                  └──────────────────┘
                            │
                            ▼
                  ┌──────────────────┐
                  │   Neo4j Graph    │
                  │    Database      │
                  └──────────────────┘
                            │
                    ┌───────┴───────┐
                    ▼               ▼
            ┌──────────────┐  ┌──────────────┐
            │Cypher Queries│  │  VKACI CLI   │
            │  (Discovery) │  │  (Python)    │
            └──────────────┘  └──────────────┘
                    │
                    ▼
            ┌──────────────┐
            │Visualization │
            │ (Network Map)│
            └──────────────┘
```

## Components

### 1. Data Model (Neo4j Graph)

**Node Types:**
- `Namespace` - Kubernetes namespaces
- `Pod` - Running pods
- `Service` - Kubernetes services
- `Endpoint` - Service endpoints
- `NetworkPolicy` - Network policies
- `CustomResource` - CRDs (Certificate, Issuer, etc.)
- `Container` - Individual containers within pods
- `Volume` - Mounted volumes
- `Secret` - Secrets
- `ConfigMap` - Configuration maps
- `Node` - Kubernetes nodes

**Relationship Types:**
- `BELONGS_TO` - Pod belongs to Namespace
- `EXPOSES` - Service exposes Pod
- `ROUTES_TO` - Service routes to Endpoint
- `ALLOWS` - NetworkPolicy allows traffic
- `DENIES` - NetworkPolicy denies traffic
- `MOUNTS` - Pod mounts Volume/Secret/ConfigMap
- `RUNS_ON` - Pod runs on Node
- `REFERENCES` - Resource references another resource
- `OWNS` - Owner reference relationship
- `DEPENDS_ON` - Dependency relationship

### 2. Cypher Queries

**Discovery Queries:**

#### Q1: Pod Discovery
```cypher
// Find all pods with their namespaces and labels
MATCH (n:Namespace)<-[:BELONGS_TO]-(p:Pod)
RETURN n.name as namespace,
       p.name as pod,
       p.labels as labels,
       p.phase as status,
       p.ip as podIP
ORDER BY namespace, pod
```

#### Q2: Service to Pod Mapping
```cypher
// Find all services and the pods they expose
MATCH (n:Namespace)<-[:BELONGS_TO]-(s:Service)-[:EXPOSES]->(p:Pod)
RETURN n.name as namespace,
       s.name as service,
       collect(p.name) as pods,
       s.clusterIP as clusterIP,
       s.ports as ports
ORDER BY namespace, service
```

#### Q3: Network Flow Analysis
```cypher
// Analyze network flows between services
MATCH (src:Pod)-[:BELONGS_TO]->(srcNs:Namespace),
      (dst:Service)-[:BELONGS_TO]->(dstNs:Namespace),
      (src)-[:COMMUNICATES_WITH]->(dst)
OPTIONAL MATCH (np:NetworkPolicy)-[:ALLOWS]->(dst)
RETURN srcNs.name as sourceNamespace,
       src.name as sourcePod,
       dstNs.name as destNamespace,
       dst.name as destService,
       np.name as allowedBy
ORDER BY sourceNamespace, sourcePod
```

#### Q4: Namespace Isolation
```cypher
// Check namespace isolation and network policies
MATCH (n:Namespace)
OPTIONAL MATCH (n)<-[:BELONGS_TO]-(np:NetworkPolicy)
RETURN n.name as namespace,
       count(np) as policyCount,
       collect(np.name) as policies,
       CASE WHEN count(np) = 0 THEN 'UNPROTECTED' ELSE 'PROTECTED' END as isolationStatus
ORDER BY isolationStatus, namespace
```

#### Q5: Custom Resource Discovery
```cypher
// Find all custom resources and their relationships
MATCH (cr:CustomResource)
OPTIONAL MATCH (cr)-[:BELONGS_TO]->(n:Namespace)
OPTIONAL MATCH (cr)-[:REFERENCES]->(ref)
RETURN cr.kind as resourceType,
       n.name as namespace,
       cr.name as name,
       cr.status as status,
       collect(ref.name) as references
ORDER BY resourceType, namespace, name
```

#### Q6: Certificate Topology
```cypher
// Map certificate issuance chain
MATCH (cert:CustomResource {kind: 'Certificate'})-[:BELONGS_TO]->(n:Namespace)
OPTIONAL MATCH (cert)-[:USES_ISSUER]->(issuer:CustomResource)
OPTIONAL MATCH (cert)-[:CREATES_SECRET]->(secret:Secret)
RETURN n.name as namespace,
       cert.name as certificate,
       issuer.name as issuer,
       secret.name as secret,
       cert.status as status
ORDER BY namespace, certificate
```

#### Q7: Volume Mount Analysis
```cypher
// Find all pods mounting secrets or configmaps
MATCH (p:Pod)-[:MOUNTS]->(v)
WHERE v:Secret OR v:ConfigMap
MATCH (p)-[:BELONGS_TO]->(n:Namespace)
RETURN n.name as namespace,
       p.name as pod,
       labels(v)[0] as volumeType,
       v.name as volumeName
ORDER BY namespace, pod
```

#### Q8: Dependency Graph
```cypher
// Build complete dependency graph for a service
MATCH path = (s:Service {name: $serviceName})-[:DEPENDS_ON*1..5]->(dep)
MATCH (s)-[:BELONGS_TO]->(n:Namespace)
RETURN n.name as namespace,
       s.name as service,
       [node in nodes(path) | node.name] as dependencyChain
```

#### Q9: Security Analysis
```cypher
// Find pods with security concerns
MATCH (p:Pod)-[:BELONGS_TO]->(n:Namespace)
WHERE p.privileged = true
   OR p.hostNetwork = true
   OR p.runAsRoot = true
RETURN n.name as namespace,
       p.name as pod,
       p.privileged as privileged,
       p.hostNetwork as hostNetwork,
       p.runAsRoot as runAsRoot
ORDER BY namespace, pod
```

#### Q10: Orphaned Resources
```cypher
// Find resources without owner references
MATCH (r)
WHERE NOT (r)-[:OWNED_BY]->()
  AND NOT r:Namespace
  AND NOT r:Node
RETURN labels(r)[0] as resourceType,
       r.namespace as namespace,
       r.name as name
ORDER BY resourceType, namespace
```

### 3. Python Collector

**File: `collector.py`**

```python
#!/usr/bin/env python3
"""
VKACI Collector
Collects Kubernetes resources and populates Neo4j graph database
"""

from kubernetes import client, config
from neo4j import GraphDatabase
import logging

class VKACICollector:
    def __init__(self, neo4j_uri, neo4j_user, neo4j_password):
        self.driver = GraphDatabase.driver(neo4j_uri, auth=(neo4j_user, neo4j_password))
        config.load_incluster_config()  # or load_kube_config() for local

        self.v1 = client.CoreV1Api()
        self.apps_v1 = client.AppsV1Api()
        self.networking_v1 = client.NetworkingV1Api()
        self.custom_api = client.CustomObjectsApi()

    def collect_all(self):
        """Collect all Kubernetes resources"""
        with self.driver.session() as session:
            # Clear existing data (optional)
            session.run("MATCH (n) DETACH DELETE n")

            # Collect resources
            self.collect_namespaces(session)
            self.collect_pods(session)
            self.collect_services(session)
            self.collect_network_policies(session)
            self.collect_custom_resources(session)

            # Build relationships
            self.build_relationships(session)

    def collect_namespaces(self, session):
        """Collect namespaces"""
        namespaces = self.v1.list_namespace()
        for ns in namespaces.items:
            session.run("""
                CREATE (n:Namespace {
                    name: $name,
                    labels: $labels,
                    created: $created
                })
            """, name=ns.metadata.name,
                 labels=ns.metadata.labels or {},
                 created=str(ns.metadata.creation_timestamp))

    def collect_pods(self, session):
        """Collect pods"""
        pods = self.v1.list_pod_for_all_namespaces()
        for pod in pods.items:
            session.run("""
                CREATE (p:Pod {
                    name: $name,
                    namespace: $namespace,
                    labels: $labels,
                    phase: $phase,
                    ip: $ip,
                    nodeName: $nodeName,
                    privileged: $privileged,
                    hostNetwork: $hostNetwork,
                    runAsRoot: $runAsRoot
                })
            """, name=pod.metadata.name,
                 namespace=pod.metadata.namespace,
                 labels=pod.metadata.labels or {},
                 phase=pod.status.phase,
                 ip=pod.status.pod_ip,
                 nodeName=pod.spec.node_name,
                 privileged=self._is_privileged(pod),
                 hostNetwork=pod.spec.host_network or False,
                 runAsRoot=self._runs_as_root(pod))

    # ... (more collection methods)
```

### 4. Python CLI

**File: `vkaci.py`**

```python
#!/usr/bin/env python3
"""
VKACI CLI
Command-line interface for Kubernetes discovery and analysis
"""

import click
from neo4j import GraphDatabase
from tabulate import tabulate

@click.group()
def cli():
    """VKACI - Visibility Kubernetes Analysis and Configuration Inventory"""
    pass

@cli.command()
@click.option('--namespace', '-n', help='Filter by namespace')
def pods(namespace):
    """Discover all pods"""
    query = """
        MATCH (n:Namespace)<-[:BELONGS_TO]-(p:Pod)
        WHERE $namespace IS NULL OR n.name = $namespace
        RETURN n.name as namespace, p.name as pod, p.phase as status, p.ip as ip
        ORDER BY namespace, pod
    """
    results = run_query(query, {'namespace': namespace})
    print(tabulate(results, headers='keys', tablefmt='grid'))

@cli.command()
def services():
    """Discover all services and their endpoints"""
    query = """
        MATCH (n:Namespace)<-[:BELONGS_TO]-(s:Service)-[:EXPOSES]->(p:Pod)
        RETURN n.name as namespace, s.name as service,
               collect(p.name) as pods, s.clusterIP as clusterIP
        ORDER BY namespace, service
    """
    results = run_query(query)
    print(tabulate(results, headers='keys', tablefmt='grid'))

@cli.command()
def network_flows():
    """Analyze network flows and policies"""
    query = """
        MATCH (src:Pod)-[:COMMUNICATES_WITH]->(dst:Service)
        RETURN src.namespace as srcNS, src.name as srcPod,
               dst.namespace as dstNS, dst.name as dstService
        ORDER BY srcNS, srcPod
    """
    results = run_query(query)
    print(tabulate(results, headers='keys', tablefmt='grid'))

# ... (more commands)
```

## Implementation Plan

### Phase 1: Foundation (Cypher-First)
1. ✅ Design graph data model
2. ✅ Write all Cypher discovery queries
3. ⬜ Test queries with sample data
4. ⬜ Document query patterns

### Phase 2: Data Collection (Python)
1. ⬜ Implement Kubernetes API collector
2. ⬜ Populate Neo4j with pod data
3. ⬜ Populate Neo4j with service data
4. ⬜ Populate Neo4j with namespace data
5. ⬜ Populate Neo4j with network policy data
6. ⬜ Populate Neo4j with custom resources

### Phase 3: Relationship Building
1. ⬜ Build BELONGS_TO relationships
2. ⬜ Build EXPOSES relationships
3. ⬜ Build MOUNTS relationships
4. ⬜ Build ALLOWS/DENIES relationships
5. ⬜ Build DEPENDS_ON relationships

### Phase 4: CLI Tool (Python)
1. ⬜ Create Click-based CLI
2. ⬜ Implement discovery commands
3. ⬜ Implement analysis commands
4. ⬜ Add output formatting (table, JSON, YAML)

### Phase 5: Deployment
1. ⬜ Create Neo4j deployment manifests
2. ⬜ Create VKACI collector deployment
3. ⬜ Create RBAC for Kubernetes API access
4. ⬜ Add monitoring and logging

### Phase 6: Visualization
1. ⬜ Add Neo4j Browser integration
2. ⬜ Create custom network topology view
3. ⬜ Add export to Graphviz/D3.js

## Use Cases

### 1. Security Auditing
```bash
vkaci security-audit
# Shows: privileged pods, hostNetwork usage, missing network policies
```

### 2. Dependency Mapping
```bash
vkaci dependencies --service ai-ops-agent
# Shows: complete dependency chain for a service
```

### 3. Certificate Tracking
```bash
vkaci certificates --status
# Shows: all certificates, their issuers, and renewal status
```

### 4. Network Flow Analysis
```bash
vkaci network-flows --from vault --to ai-ops-agent
# Shows: all network paths between services
```

### 5. Orphaned Resource Detection
```bash
vkaci orphans
# Shows: resources without owner references
```

## Deployment Architecture

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: vkaci
---
# Neo4j StatefulSet (graph database)
# VKACI Collector CronJob (periodic collection)
# VKACI CLI Pod (interactive queries)
```

## Security Considerations

1. **RBAC**: Read-only ClusterRole for Kubernetes API
2. **Neo4j Auth**: Secure credentials via Secrets
3. **Network Policies**: Restrict VKACI namespace
4. **Data Retention**: TTL for historical data
5. **Audit Logging**: Track all queries

## Performance

- **Collection Frequency**: Every 5 minutes (configurable)
- **Incremental Updates**: Only changed resources
- **Query Optimization**: Indexed properties
- **Data Pruning**: 7-day retention (configurable)

## Future Enhancements

- Real-time event streaming (watch API)
- Anomaly detection (ML-based)
- Cost analysis integration
- Multi-cluster support
- GitOps integration (ArgoCD/Flux)
- Compliance reporting (PCI-DSS, HIPAA, SOC2)
