# Family Services Appliance

## Vision

Deploy an ARM-based board running OpenMediaVault (OMV) as a front-end appliance to host essential family services. All improvements and enhancements will be contributed upstream to benefit the broader community.

## Hardware Selection

**See [Hardware Analysis & Cost Structure](FAMILY-SERVICES-APPLIANCE-HARDWARE.md) for:**
- Detailed hardware recommendations across three tiers (Basic, Pro, Premium)
- Complete cost breakdowns and BOMs
- Performance comparisons and sizing guidance
- Dual CM3588 vs. Orange Pi 5 Plus evaluation
- Power consumption and cooling requirements

**Quick Reference:**
- **Basic Tier** ($165-204): Single Orange Pi 5 (8GB) - 2-4 users
- **Pro Tier** ($654-890): Dual Orange Pi 5 Plus (16GB) - 4-8 users, HA ⭐ Recommended
- **Premium Tier** ($1,440-3,920): Multiple options for 8-15+ users

## Architecture

- **Hardware**: ARM-based board (e.g., Raspberry Pi, Orange Pi, ODROID) or Compute Modules (CM3588)
- **Base OS**: OpenMediaVault (OMV)
- **Orchestration**: k3s (Kubernetes) for service management and high availability
- **Integration**: Connect to existing AIOps substrate for monitoring and automation
- **Philosophy**: Self-hosted, privacy-focused family services

## MVP Services

### Core Services

1. **PhotoPrism** - Photo Management & Sharing
   - Repository: https://github.com/photoprism/
   - AI-powered photo organization
   - Face recognition and automatic tagging
   - Mobile apps for photo upload
   - Privacy-focused (no cloud dependency)
   - **Hardware Requirements**: 2-4GB RAM, benefits from GPU acceleration (Premium tier)

2. **Email Server**
   - Options: Mailcow, Mailu, or Mail-in-a-Box
   - Full-featured email with SMTP/IMAP
   - Spam filtering
   - Web interface for email management
   - Mobile device sync support
   - **Hardware Requirements**: 512MB-1GB RAM, TLS certificate required

3. **DNS & DHCP Services**
   - **Architecture Options**:
     - **Option A**: dnsmasq (standalone) - Lightweight DNS/DHCP, local resolution, custom DNS records
     - **Option B**: Pi-hole (includes dnsmasq) - All of Option A + ad-blocking web UI
     - **Option C**: AdGuard Home - Alternative to Pi-hole with modern UI
   - DNS-over-HTTPS (DoH) support
   - Network-wide privacy protection
   - Custom local domain resolution (e.g., *.home.lan)
   - **k3s Integration** (Validated Architecture):
     - **CoreDNS** (k3s internal): Provides HA for services
       - Service discovery and load balancing across pods
       - Automatic failover when pods die/restart
       - Lightweight: No external query load (~15-30MB memory)
     - **dnsmasq/Pi-hole** (external): Protects family privacy and internet safety
       - Ad-blocking and tracker blocking (network-wide)
       - Malicious domain filtering
       - Safe browsing for all family devices
       - Points to k3s LoadBalancer IPs for local services
       - Lightweight: ~20-50MB memory footprint
     - **Separation Benefits**:
       - k3s = Internal HA and service resilience
       - dnsmasq = External privacy and safety
       - No DNS query overlap = minimal resource usage on both sides
       - CoreDNS not exposed to family network traffic
       - dnsmasq not burdened with k3s internal resolution
     - **Automation**: external-dns operator syncs k3s Ingress/Service → dnsmasq records
     - **Load Balancing**: MetalLB or k3s ServiceLB for stable service IPs
   - **Hardware Requirements**: 20-50MB RAM, minimal CPU

4. **TLS/SSL Certificate Management**
   - **cert-manager** (deployed in k3s) - Automated certificate lifecycle
   - **Certificate Strategies**:
     - **Option A - Internal Only** (Recommended for home use):
       - Self-signed CA or internal CA (mkcert, step-ca)
       - Wildcard cert for *.home.lan
       - Install CA cert on family devices once
       - No external dependencies, fully private
     - **Option B - Let's Encrypt** (If externally accessible):
       - Let's Encrypt via DNS-01 challenge (works behind firewall)
       - Automatic 90-day renewal via cert-manager
       - Requires public domain name
       - Use with Tailscale/WireGuard for secure remote access
   - **Integration**:
     - cert-manager ClusterIssuer for automatic cert provisioning
     - Ingress annotations trigger automatic cert creation
     - Certificates stored as Kubernetes secrets
   - **Services requiring TLS**:
     - Email (SMTP/IMAP TLS required for mobile clients)
     - PhotoPrism web interface
     - Nextcloud/file sync
     - All web-based admin interfaces
   - **Hardware Requirements**: Minimal (<100MB RAM)

### Supporting Services

5. **File Storage & Sync**
   - Nextcloud or Seafile
   - Cross-device file synchronization
   - Shared family folders
   - Document collaboration
   - **Hardware Requirements**: 512MB-2GB RAM, scales with active users

6. **Calendar & Contacts**
   - CalDAV/CardDAV server (Radicale or Nextcloud)
   - Family calendar sharing
   - Contact synchronization across devices
   - **Hardware Requirements**: 256MB-512MB RAM

7. **Media Server** (Optional for MVP)
   - Jellyfin or Plex
   - Family media library
   - Streaming to various devices
   - **Hardware Requirements**: 2-4GB RAM, transcoding benefits from GPU (Premium tier)

8. **Backup Service**
   - Automated backup solution (Restic, Duplicati)
   - Backup to external storage or cloud
   - Disaster recovery capability
   - **Hardware Requirements**: Minimal CPU/RAM, requires adequate storage

## Resource Planning

### Memory Requirements Summary
```
k3s base:                    512MB-1GB
CoreDNS:                     15-30MB
dnsmasq/Pi-hole:            20-50MB
PhotoPrism:                  2-4GB
Email server:                512MB-1GB
Nextcloud:                   512MB-2GB
cert-manager:                50-100MB
Monitoring (Prometheus):     256-512MB
─────────────────────────────────────
Minimum (Basic):             4-6GB
Recommended (Pro):           8-12GB per node
Optimal (Premium):           16-32GB per node
```

### Storage Requirements
- **System/OS**: 32-64GB
- **Container Images**: 10-20GB
- **PhotoPrism**: 100GB-2TB (depends on photo library)
- **Email**: 10-100GB (per user)
- **Nextcloud**: 100GB-5TB (depends on usage)
- **Backups**: 2-3x primary storage
- **Recommended**: Use separate NAS for large data storage (Premium tier)

### Network Requirements
- **Basic**: 1GbE sufficient for 2-4 users
- **Pro**: 2.5GbE recommended for 4-8 users with active file sync
- **Premium**: 2.5GbE minimum, 10GbE for media streaming and NAS

## High Availability Architecture (Pro/Premium Tiers)

```
┌─────────────────────────────────────────────────────────────┐
│                     Family Network                           │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐           │
│  │  Laptop    │  │   Phone    │  │   Tablet   │           │
│  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘           │
│        │                │                │                   │
│        └────────────────┴────────────────┘                   │
│                         │                                     │
│                         ▼                                     │
│              ┌──────────────────┐                           │
│              │  dnsmasq/Pi-hole │  ← DNS/DHCP/Ad-block      │
│              │   (External)     │                           │
│              └────────┬─────────┘                           │
│                       │                                      │
│                       ▼                                      │
│              ┌──────────────────┐                           │
│              │  2.5GbE Switch   │                           │
│              │   + MetalLB VIP  │                           │
│              └────────┬─────────┘                           │
│                       │                                      │
│        ┌──────────────┴──────────────┐                     │
│        │                              │                     │
│        ▼                              ▼                     │
│  ┌───────────┐                  ┌───────────┐             │
│  │  Node 1   │                  │  Node 2   │             │
│  │           │                  │           │             │
│  │  k3s      │ ◄────etcd───────►│  k3s      │             │
│  │  server   │      HA          │  server   │             │
│  │           │                  │           │             │
│  │  CoreDNS  │                  │  CoreDNS  │             │
│  │  Services │                  │  Services │             │
│  └───────────┘                  └───────────┘             │
│        │                              │                     │
│        └──────────────┬───────────────┘                     │
│                       │                                      │
│                       ▼                                      │
│              ┌──────────────────┐                           │
│              │   Shared NAS     │  ← Persistent storage     │
│              │   (Optional)     │                           │
│              └──────────────────┘                           │
└─────────────────────────────────────────────────────────────┘
```

**Benefits:**
- Automatic pod failover between nodes
- Zero-downtime updates
- Hardware failure tolerance
- Load distribution across nodes
- Persistent storage options (local or NAS)

## Upstream Contribution Goals

- Performance optimizations for ARM architecture
- OMV integration improvements
- Container orchestration enhancements
- Documentation and deployment automation
- Security hardening configurations
- k3s deployment patterns for home lab environments
- PhotoPrism ARM optimization and AI performance tuning

## Integration with AIOps Substrate

- Monitor appliance health via Prometheus (metrics from both nodes)
- Automated alerting through existing alert infrastructure
- GitOps-based configuration management (ArgoCD/Flux)
- Automated backup verification
- Service availability monitoring (synthetic checks)
- Resource utilization tracking (CPU, memory, storage, network)
- Certificate expiration monitoring

## Deployment Phases

### Phase 1: MVP Deployment (Basic Tier)
**Timeline:** 1-2 weeks  
**Budget:** $200-250

1. Deploy single ARM board
2. Install OpenMediaVault base
3. Deploy core services (PhotoPrism, DNS/DHCP, cert-manager)
4. Configure basic monitoring
5. Test with family members
6. Establish backup routine

### Phase 2: Scaling to HA (Pro Tier)
**Timeline:** 2-4 weeks  
**Incremental Budget:** $450-650

1. Add second node
2. Convert to k3s HA cluster
3. Add UPS for power protection
4. Deploy full service stack with redundancy
5. Implement comprehensive monitoring and alerting
6. Configure automated failover testing

### Phase 3: Production Hardening (Pro+/Premium)
**Timeline:** 4-8 weeks  
**Incremental Budget:** $600-1,200

1. Add dedicated NAS for storage (if needed)
2. Upgrade networking to 2.5GbE or 10GbE
3. Implement offsite backup
4. Security hardening (network segmentation, firewall rules)
5. Performance tuning and optimization
6. Documentation and runbooks

## Next Steps

1. ✅ **Hardware Selection** - Review [Hardware Analysis](FAMILY-SERVICES-APPLIANCE-HARDWARE.md) and select tier
2. **Source Components** - Order hardware based on BOM
3. **Design Detailed Architecture** - Create network diagram and service topology
4. **Create Deployment Automation** - Ansible playbooks, Terraform configs
5. **Set Up Monitoring** - Integrate with AIOps substrate
6. **Document Contribution Workflow** - Establish process for upstream contributions
7. **Build Community** - Share learnings and improvements

## Related Documentation

- [Hardware Analysis & Cost Structure](FAMILY-SERVICES-APPLIANCE-HARDWARE.md) - Complete hardware evaluation
- [Assembly Guide](FAMILY-SERVICES-APPLIANCE-ASSEMBLY.md) - Step-by-step hardware assembly (coming soon)
- [Deployment Guide](FAMILY-SERVICES-APPLIANCE-DEPLOYMENT.md) - Automated deployment procedures (coming soon)
- [Operations Runbook](FAMILY-SERVICES-APPLIANCE-OPERATIONS.md) - Maintenance and troubleshooting (coming soon)
