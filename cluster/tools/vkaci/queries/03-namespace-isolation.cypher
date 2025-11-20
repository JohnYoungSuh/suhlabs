// ============================================================================
// VKACI Cypher Query: Namespace Isolation & Network Policies
// Purpose: Analyze namespace isolation and network security policies
// ============================================================================

// Query 3.1: List all namespaces
MATCH (n:Namespace)
RETURN n.name as namespace,
       n.labels as labels,
       n.created as created
ORDER BY namespace;

// Query 3.2: Namespace isolation status
MATCH (n:Namespace)
OPTIONAL MATCH (n)<-[:BELONGS_TO]-(np:NetworkPolicy)
RETURN n.name as namespace,
       count(np) as policyCount,
       collect(np.name) as policies,
       CASE
           WHEN count(np) = 0 THEN 'UNPROTECTED'
           WHEN count(np) < 2 THEN 'PARTIALLY_PROTECTED'
           ELSE 'PROTECTED'
       END as isolationStatus
ORDER BY isolationStatus, namespace;

// Query 3.3: Unprotected namespaces (critical finding)
MATCH (n:Namespace)
WHERE NOT (n)<-[:BELONGS_TO]-(:NetworkPolicy)
  AND n.name NOT IN ['kube-system', 'kube-public', 'kube-node-lease']
RETURN n.name as namespace,
       'MISSING_NETWORK_POLICY' as security_issue,
       'HIGH' as severity
ORDER BY namespace;

// Query 3.4: Network policy details
MATCH (n:Namespace)<-[:BELONGS_TO]-(np:NetworkPolicy)
RETURN n.name as namespace,
       np.name as policy,
       np.podSelector as podSelector,
       np.policyTypes as policyTypes,
       np.ingress as ingressRules,
       np.egress as egressRules
ORDER BY namespace, policy;

// Query 3.5: Namespace resource counts
MATCH (n:Namespace)
OPTIONAL MATCH (n)<-[:BELONGS_TO]-(p:Pod)
OPTIONAL MATCH (n)<-[:BELONGS_TO]-(s:Service)
OPTIONAL MATCH (n)<-[:BELONGS_TO]-(np:NetworkPolicy)
RETURN n.name as namespace,
       count(DISTINCT p) as pods,
       count(DISTINCT s) as services,
       count(DISTINCT np) as networkPolicies
ORDER BY pods DESC;

// Query 3.6: Cross-namespace communications
MATCH (srcNs:Namespace)<-[:BELONGS_TO]-(srcPod:Pod),
      (dstNs:Namespace)<-[:BELONGS_TO]-(dstSvc:Service),
      (srcPod)-[:COMMUNICATES_WITH]->(dstSvc)
WHERE srcNs.name <> dstNs.name
RETURN srcNs.name as sourceNamespace,
       srcPod.name as sourcePod,
       dstNs.name as destNamespace,
       dstSvc.name as destService
ORDER BY sourceNamespace, destNamespace;

// Query 3.7: Namespace with most external exposure
MATCH (n:Namespace)<-[:BELONGS_TO]-(s:Service)
WHERE s.type IN ['LoadBalancer', 'NodePort']
RETURN n.name as namespace,
       count(s) as externalServices,
       collect(s.name) as services
ORDER BY externalServices DESC;

// Query 3.8: Default namespace usage (anti-pattern)
MATCH (n:Namespace {name: 'default'})<-[:BELONGS_TO]-(r)
WHERE r:Pod OR r:Service OR r:Deployment
RETURN labels(r)[0] as resourceType,
       r.name as resourceName,
       'AVOID_DEFAULT_NAMESPACE' as recommendation
ORDER BY resourceType, resourceName;
