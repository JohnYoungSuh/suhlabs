// ============================================================================
// VKACI Cypher Query: Network Flow Analysis
// Purpose: Analyze network traffic patterns and communication flows
// ============================================================================

// Query 4.1: All network flows
MATCH (srcPod:Pod)-[comm:COMMUNICATES_WITH]->(dstSvc:Service)
MATCH (srcPod)-[:BELONGS_TO]->(srcNs:Namespace)
MATCH (dstSvc)-[:BELONGS_TO]->(dstNs:Namespace)
RETURN srcNs.name as sourceNamespace,
       srcPod.name as sourcePod,
       dstNs.name as destNamespace,
       dstSvc.name as destService,
       comm.port as port,
       comm.protocol as protocol,
       comm.bytesTransferred as bytes
ORDER BY bytes DESC;

// Query 4.2: Network flows with policy enforcement
MATCH (srcPod:Pod)-[:COMMUNICATES_WITH]->(dstSvc:Service)
MATCH (srcPod)-[:BELONGS_TO]->(srcNs:Namespace)
MATCH (dstSvc)-[:BELONGS_TO]->(dstNs:Namespace)
OPTIONAL MATCH (np:NetworkPolicy)-[:ALLOWS]->(dstSvc)
OPTIONAL MATCH (deny:NetworkPolicy)-[:DENIES]->(dstSvc)
RETURN srcNs.name as sourceNS,
       srcPod.name as sourcePod,
       dstNs.name as destNS,
       dstSvc.name as destService,
       CASE
           WHEN deny IS NOT NULL THEN 'DENIED'
           WHEN np IS NOT NULL THEN 'ALLOWED'
           ELSE 'NO_POLICY'
       END as policyStatus,
       coalesce(np.name, deny.name) as policyName
ORDER BY policyStatus, sourceNS;

// Query 4.3: Unauthorized network flows (denied by policy)
MATCH (srcPod:Pod)-[:COMMUNICATES_WITH]->(dstSvc:Service)
MATCH (np:NetworkPolicy)-[:DENIES]->(dstSvc)
MATCH (srcPod)-[:BELONGS_TO]->(srcNs:Namespace)
MATCH (dstSvc)-[:BELONGS_TO]->(dstNs:Namespace)
RETURN srcNs.name as sourceNS,
       srcPod.name as sourcePod,
       dstNs.name as destNS,
       dstSvc.name as destService,
       np.name as deniedByPolicy,
       'SECURITY_VIOLATION' as alert
ORDER BY sourceNS, sourcePod;

// Query 4.4: Flows to external services (egress)
MATCH (srcPod:Pod)-[:COMMUNICATES_WITH]->(ext:ExternalEndpoint)
MATCH (srcPod)-[:BELONGS_TO]->(srcNs:Namespace)
RETURN srcNs.name as namespace,
       srcPod.name as pod,
       ext.host as externalHost,
       ext.port as port,
       ext.isPublicInternet as isInternet
ORDER BY namespace, pod;

// Query 4.5: Top talkers (pods with most connections)
MATCH (p:Pod)-[:COMMUNICATES_WITH]->(target)
MATCH (p)-[:BELONGS_TO]->(n:Namespace)
RETURN n.name as namespace,
       p.name as pod,
       count(target) as connectionCount,
       collect(DISTINCT labels(target)[0]) as targetTypes
ORDER BY connectionCount DESC
LIMIT 20;

// Query 4.6: Service dependency graph
MATCH path = (s1:Service)-[:DEPENDS_ON*1..3]->(s2:Service)
MATCH (s1)-[:BELONGS_TO]->(n1:Namespace)
MATCH (s2)-[:BELONGS_TO]->(n2:Namespace)
RETURN n1.name as sourceNS,
       s1.name as sourceService,
       n2.name as targetNS,
       s2.name as targetService,
       length(path) as hops
ORDER BY hops, sourceNS, sourceService;

// Query 4.7: Network flows by port
MATCH (srcPod:Pod)-[comm:COMMUNICATES_WITH]->(dstSvc:Service)
RETURN comm.port as port,
       comm.protocol as protocol,
       count(*) as flowCount,
       sum(comm.bytesTransferred) as totalBytes
ORDER BY flowCount DESC;

// Query 4.8: Vault access patterns (PKI-specific)
MATCH (srcPod:Pod)-[:COMMUNICATES_WITH]->(vaultSvc:Service)
WHERE vaultSvc.name CONTAINS 'vault'
MATCH (srcPod)-[:BELONGS_TO]->(srcNs:Namespace)
MATCH (vaultSvc)-[:BELONGS_TO]->(vaultNs:Namespace)
RETURN srcNs.name as namespace,
       srcPod.name as pod,
       vaultSvc.name as vaultService,
       'CERT_ISSUANCE' as purpose
ORDER BY namespace, pod;

// Query 4.9: Suspicious network patterns
MATCH (p:Pod)-[comm:COMMUNICATES_WITH]->(target)
WHERE comm.failedAttempts > 10
   OR comm.bytesTransferred > 1000000000  // > 1GB
   OR comm.port IN [22, 3389, 23]  // SSH, RDP, Telnet
MATCH (p)-[:BELONGS_TO]->(n:Namespace)
RETURN n.name as namespace,
       p.name as pod,
       labels(target)[0] as targetType,
       target.name as targetName,
       comm.port as port,
       comm.failedAttempts as failedAttempts,
       comm.bytesTransferred as bytes,
       'SUSPICIOUS_ACTIVITY' as alert
ORDER BY failedAttempts DESC, bytes DESC;

// Query 4.10: Network segmentation validation
MATCH (n1:Namespace), (n2:Namespace)
WHERE n1.name < n2.name
  AND n1.securityZone <> n2.securityZone
OPTIONAL MATCH (n1)<-[:BELONGS_TO]-(p1:Pod)-[:COMMUNICATES_WITH]->
               (s2:Service)-[:BELONGS_TO]->(n2)
RETURN n1.name as namespace1,
       n1.securityZone as zone1,
       n2.name as namespace2,
       n2.securityZone as zone2,
       count(p1) as crossZoneFlows,
       CASE
           WHEN count(p1) > 0 THEN 'SEGMENTATION_VIOLATION'
           ELSE 'OK'
       END as status
ORDER BY crossZoneFlows DESC;
