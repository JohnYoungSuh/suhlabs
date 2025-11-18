# Family Services Appliance

## Vision

Deploy an ARM-based board running OpenMediaVault (OMV) as a front-end appliance to host essential family services. All improvements and enhancements will be contributed upstream to benefit the broader community.

## Architecture

- **Hardware**: ARM-based board (e.g., Raspberry Pi, Orange Pi, ODROID)
- **Base OS**: OpenMediaVault (OMV)
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

2. **Email Server**
   - Options: Mailcow, Mailu, or Mail-in-a-Box
   - Full-featured email with SMTP/IMAP
   - Spam filtering
   - Web interface for email management
   - Mobile device sync support

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

### Supporting Services

5. **File Storage & Sync**
   - Nextcloud or Seafile
   - Cross-device file synchronization
   - Shared family folders
   - Document collaboration

6. **Calendar & Contacts**
   - CalDAV/CardDAV server (Radicale or Nextcloud)
   - Family calendar sharing
   - Contact synchronization across devices

7. **Media Server** (Optional for MVP)
   - Jellyfin or Plex
   - Family media library
   - Streaming to various devices

8. **Backup Service**
   - Automated backup solution (Restic, Duplicati)
   - Backup to external storage or cloud
   - Disaster recovery capability

## Upstream Contribution Goals

- Performance optimizations for ARM architecture
- OMV integration improvements
- Container orchestration enhancements
- Documentation and deployment automation
- Security hardening configurations

## Integration with AIOps Substrate

- Monitor appliance health via Prometheus
- Automated alerting through existing alert infrastructure
- GitOps-based configuration management
- Automated backup verification
- Service availability monitoring

## Next Steps

1. Select specific ARM hardware platform
2. Choose specific implementations for each service
3. Design container/service architecture
4. Create deployment automation
5. Establish monitoring and backup strategies
6. Document contribution workflow for upstream projects
