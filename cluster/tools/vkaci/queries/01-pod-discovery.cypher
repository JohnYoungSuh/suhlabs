// ============================================================================
// VKACI Cypher Query: Pod Discovery
// Purpose: Discover all pods with their namespaces, labels, and status
// ============================================================================

// Query 1.1: List all pods
MATCH (n:Namespace)<-[:BELONGS_TO]-(p:Pod)
RETURN n.name as namespace,
       p.name as pod,
       p.phase as status,
       p.ip as podIP,
       p.nodeName as node,
       p.labels as labels
ORDER BY namespace, pod;

// Query 1.2: Pods by namespace
MATCH (n:Namespace {name: $namespace})<-[:BELONGS_TO]-(p:Pod)
RETURN p.name as pod,
       p.phase as status,
       p.ip as podIP,
       p.restartCount as restarts
ORDER BY pod;

// Query 1.3: Pods with specific label
MATCH (p:Pod)
WHERE p.labels.$labelKey = $labelValue
MATCH (p)-[:BELONGS_TO]->(n:Namespace)
RETURN n.name as namespace,
       p.name as pod,
       p.phase as status
ORDER BY namespace, pod;

// Query 1.4: Failed/CrashLooping pods
MATCH (n:Namespace)<-[:BELONGS_TO]-(p:Pod)
WHERE p.phase IN ['Failed', 'CrashLoopBackOff', 'Error']
   OR p.restartCount > 5
RETURN n.name as namespace,
       p.name as pod,
       p.phase as status,
       p.restartCount as restarts,
       p.reason as reason
ORDER BY restartCount DESC, namespace, pod;

// Query 1.5: Pods running on specific node
MATCH (p:Pod {nodeName: $nodeName})-[:BELONGS_TO]->(n:Namespace)
RETURN n.name as namespace,
       p.name as pod,
       p.phase as status,
       p.ip as podIP
ORDER BY namespace, pod;

// Query 1.6: Pod resource utilization (if metrics collected)
MATCH (n:Namespace)<-[:BELONGS_TO]-(p:Pod)
RETURN n.name as namespace,
       p.name as pod,
       p.cpuRequest as cpuRequest,
       p.cpuLimit as cpuLimit,
       p.memoryRequest as memoryRequest,
       p.memoryLimit as memoryLimit
ORDER BY memoryLimit DESC;

// Query 1.7: Pods without resource limits (security risk)
MATCH (n:Namespace)<-[:BELONGS_TO]-(p:Pod)
WHERE p.cpuLimit IS NULL OR p.memoryLimit IS NULL
RETURN n.name as namespace,
       p.name as pod,
       p.cpuLimit IS NULL as missingCPULimit,
       p.memoryLimit IS NULL as missingMemoryLimit
ORDER BY namespace, pod;

// Query 1.8: Count pods by namespace
MATCH (n:Namespace)<-[:BELONGS_TO]-(p:Pod)
RETURN n.name as namespace,
       count(p) as podCount,
       count(CASE WHEN p.phase = 'Running' THEN 1 END) as runningPods,
       count(CASE WHEN p.phase <> 'Running' THEN 1 END) as unhealthyPods
ORDER BY podCount DESC;
