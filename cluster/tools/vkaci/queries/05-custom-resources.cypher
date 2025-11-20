// ============================================================================
// VKACI Cypher Query: Custom Resource Discovery
// Purpose: Discover and analyze CRDs, certificates, issuers, and custom resources
// ============================================================================

// Query 5.1: List all custom resources
MATCH (cr:CustomResource)
OPTIONAL MATCH (cr)-[:BELONGS_TO]->(n:Namespace)
RETURN cr.kind as resourceType,
       n.name as namespace,
       cr.name as name,
       cr.apiVersion as apiVersion,
       cr.created as created
ORDER BY resourceType, namespace, name;

// Query 5.2: Custom resources by type
MATCH (cr:CustomResource)
RETURN cr.kind as resourceType,
       cr.apiGroup as apiGroup,
       count(*) as count
ORDER BY count DESC;

// Query 5.3: Certificate discovery
MATCH (cert:CustomResource {kind: 'Certificate'})
MATCH (cert)-[:BELONGS_TO]->(n:Namespace)
OPTIONAL MATCH (cert)-[:USES_ISSUER]->(issuer:CustomResource)
OPTIONAL MATCH (cert)-[:CREATES_SECRET]->(secret:Secret)
RETURN n.name as namespace,
       cert.name as certificate,
       cert.commonName as commonName,
       cert.dnsNames as dnsNames,
       issuer.name as issuer,
       secret.name as secretName,
       cert.status as status,
       cert.notAfter as expiresAt
ORDER BY namespace, certificate;

// Query 5.4: Expiring certificates (within 30 days)
MATCH (cert:CustomResource {kind: 'Certificate'})
WHERE datetime(cert.notAfter) < datetime() + duration('P30D')
MATCH (cert)-[:BELONGS_TO]->(n:Namespace)
RETURN n.name as namespace,
       cert.name as certificate,
       cert.notAfter as expiresAt,
       duration.inDays(datetime(), datetime(cert.notAfter)).days as daysUntilExpiry,
       'RENEWAL_REQUIRED' as alert
ORDER BY daysUntilExpiry;

// Query 5.5: Failed certificates
MATCH (cert:CustomResource {kind: 'Certificate'})
WHERE cert.status <> 'Ready'
   OR cert.conditions IS NOT NULL
MATCH (cert)-[:BELONGS_TO]->(n:Namespace)
OPTIONAL MATCH (cert)-[:USES_ISSUER]->(issuer:CustomResource)
RETURN n.name as namespace,
       cert.name as certificate,
       cert.status as status,
       cert.conditions as conditions,
       issuer.name as issuer
ORDER BY namespace, certificate;

// Query 5.6: Issuer/ClusterIssuer discovery
MATCH (issuer:CustomResource)
WHERE issuer.kind IN ['Issuer', 'ClusterIssuer']
OPTIONAL MATCH (issuer)-[:BELONGS_TO]->(n:Namespace)
RETURN issuer.kind as type,
       n.name as namespace,
       issuer.name as name,
       issuer.issuerType as issuerType,
       issuer.status as status
ORDER BY type, namespace, name;

// Query 5.7: Certificate to issuer mapping
MATCH (cert:CustomResource {kind: 'Certificate'})-[:USES_ISSUER]->(issuer:CustomResource)
MATCH (cert)-[:BELONGS_TO]->(n:Namespace)
RETURN issuer.kind as issuerType,
       issuer.name as issuer,
       n.name as namespace,
       collect(cert.name) as certificates,
       count(cert) as certCount
ORDER BY issuerType, issuer;

// Query 5.8: Vault PKI role usage
MATCH (cert:CustomResource {kind: 'Certificate'})
WHERE cert.vaultRole IS NOT NULL
MATCH (cert)-[:BELONGS_TO]->(n:Namespace)
RETURN cert.vaultRole as vaultRole,
       count(cert) as usageCount,
       collect(n.name + '/' + cert.name) as certificates
ORDER BY usageCount DESC;

// Query 5.9: Certificate DNS name validation
MATCH (cert:CustomResource {kind: 'Certificate'})
MATCH (cert)-[:BELONGS_TO]->(n:Namespace)
WHERE any(dns IN cert.dnsNames WHERE NOT dns ENDS WITH '.cluster.local' AND NOT dns ENDS WITH '.corp.local')
RETURN n.name as namespace,
       cert.name as certificate,
       cert.dnsNames as dnsNames,
       'INVALID_DNS_NAME' as issue,
       'Check Vault PKI allowed_domains' as recommendation
ORDER BY namespace, certificate;

// Query 5.10: Custom resource dependencies
MATCH (cr:CustomResource)-[:REFERENCES]->(ref)
MATCH (cr)-[:BELONGS_TO]->(n:Namespace)
RETURN cr.kind as resourceType,
       n.name as namespace,
       cr.name as name,
       labels(ref)[0] as referencesType,
       ref.name as referencesName
ORDER BY resourceType, namespace, name;

// Query 5.11: Orphaned custom resources (no owner)
MATCH (cr:CustomResource)
WHERE NOT (cr)-[:OWNED_BY]->()
OPTIONAL MATCH (cr)-[:BELONGS_TO]->(n:Namespace)
RETURN cr.kind as resourceType,
       n.name as namespace,
       cr.name as name,
       'NO_OWNER_REFERENCE' as issue
ORDER BY resourceType, namespace, name;

// Query 5.12: CRD version compatibility
MATCH (cr:CustomResource)
RETURN cr.apiVersion as apiVersion,
       cr.kind as kind,
       count(*) as instanceCount,
       collect(DISTINCT cr.namespace)[0..5] as sampleNamespaces
ORDER BY kind, apiVersion;

// Query 5.13: Certificate chain validation
MATCH path = (cert:CustomResource {kind: 'Certificate'})-[:SIGNED_BY*1..3]->(ca:CustomResource)
WHERE ca.isCACertificate = true
MATCH (cert)-[:BELONGS_TO]->(n:Namespace)
RETURN n.name as namespace,
       cert.name as certificate,
       [node IN nodes(path) | node.name] as certificateChain,
       length(path) as chainLength
ORDER BY namespace, certificate;

// Query 5.14: Custom resource by owner
MATCH (owner)-[:OWNS]->(cr:CustomResource)
MATCH (cr)-[:BELONGS_TO]->(n:Namespace)
RETURN labels(owner)[0] as ownerType,
       owner.name as ownerName,
       cr.kind as resourceType,
       n.name as namespace,
       collect(cr.name) as resources
ORDER BY ownerType, ownerName;

// Query 5.15: CRD security analysis
MATCH (cr:CustomResource)
WHERE cr.privileged = true
   OR cr.hostNetwork = true
   OR any(cap IN cr.capabilities WHERE cap IN ['SYS_ADMIN', 'NET_ADMIN'])
MATCH (cr)-[:BELONGS_TO]->(n:Namespace)
RETURN cr.kind as resourceType,
       n.name as namespace,
       cr.name as name,
       cr.privileged as privileged,
       cr.hostNetwork as hostNetwork,
       cr.capabilities as capabilities,
       'SECURITY_RISK' as alert
ORDER BY namespace, name;
