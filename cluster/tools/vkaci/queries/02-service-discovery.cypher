// ============================================================================
// VKACI Cypher Query: Service Discovery
// Purpose: Discover services, endpoints, and service-to-pod mappings
// ============================================================================

// Query 2.1: List all services
MATCH (n:Namespace)<-[:BELONGS_TO]-(s:Service)
RETURN n.name as namespace,
       s.name as service,
       s.type as serviceType,
       s.clusterIP as clusterIP,
       s.ports as ports
ORDER BY namespace, service;

// Query 2.2: Service to Pod mapping
MATCH (n:Namespace)<-[:BELONGS_TO]-(s:Service)-[:EXPOSES]->(p:Pod)
RETURN n.name as namespace,
       s.name as service,
       s.clusterIP as clusterIP,
       collect(DISTINCT p.name) as pods,
       count(p) as podCount
ORDER BY namespace, service;

// Query 2.3: Services without endpoints (broken)
MATCH (n:Namespace)<-[:BELONGS_TO]-(s:Service)
WHERE NOT (s)-[:EXPOSES]->(:Pod)
RETURN n.name as namespace,
       s.name as service,
       s.selector as selector,
       'NO_ENDPOINTS' as status
ORDER BY namespace, service;

// Query 2.4: Service selector mismatch detection
MATCH (n:Namespace)<-[:BELONGS_TO]-(s:Service)
OPTIONAL MATCH (s)-[:EXPOSES]->(p:Pod)
WITH n, s, count(p) as podCount
WHERE podCount = 0
RETURN n.name as namespace,
       s.name as service,
       s.selector as selector,
       podCount,
       'SELECTOR_MISMATCH' as issue
ORDER BY namespace, service;

// Query 2.5: External services (LoadBalancer/NodePort)
MATCH (n:Namespace)<-[:BELONGS_TO]-(s:Service)
WHERE s.type IN ['LoadBalancer', 'NodePort']
RETURN n.name as namespace,
       s.name as service,
       s.type as serviceType,
       s.externalIP as externalIP,
       s.loadBalancerIP as loadBalancerIP,
       s.ports as ports
ORDER BY namespace, service;

// Query 2.6: Headless services (clusterIP: None)
MATCH (n:Namespace)<-[:BELONGS_TO]-(s:Service {clusterIP: 'None'})
RETURN n.name as namespace,
       s.name as service,
       'Headless' as serviceType,
       s.selector as selector
ORDER BY namespace, service;

// Query 2.7: Services exposing specific pod
MATCH (p:Pod {name: $podName})<-[:EXPOSES]-(s:Service)-[:BELONGS_TO]->(n:Namespace)
RETURN n.name as namespace,
       s.name as service,
       s.clusterIP as clusterIP,
       s.ports as ports
ORDER BY service;

// Query 2.8: Port conflicts (same port, different services)
MATCH (s1:Service)-[:BELONGS_TO]->(n:Namespace)<-[:BELONGS_TO]-(s2:Service)
WHERE s1.name < s2.name
  AND any(port1 IN s1.ports WHERE any(port2 IN s2.ports WHERE port1.port = port2.port))
RETURN n.name as namespace,
       s1.name as service1,
       s2.name as service2,
       [port IN s1.ports WHERE any(p IN s2.ports WHERE p.port = port.port) | port.port] as conflictingPorts
ORDER BY namespace;
