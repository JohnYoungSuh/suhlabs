# EPIC-1: Hardware & Foundation

**Epic Key**: HOMELAB-1  
**Priority**: High  
**Story Points**: 21  
**Sprint**: Sprint 0-1  
**Labels**: `learn-jira`, `hardware`, `foundation`

---

## Epic Description

Setup the physical and foundational infrastructure for a 2-host consumer-grade homelab cluster. This epic covers hardware procurement, network configuration, and base OS installation.

**Learning Focus**: Jira project management, hardware selection, network fundamentals

---

## Success Criteria

- [ ] 2x consumer mini PCs operational
- [ ] Network configured with cluster VLAN
- [ ] CentOS Stream 9 installed on both hosts
- [ ] SSH access working from admin machine
- [ ] Storage layout configured
- [ ] Total cost <$1,000

---

## Stories in This Epic

### HOMELAB-2: Plan Jira Project Structure ⭐ START HERE

**Story Points**: 3  
**Priority**: High  
**Sprint**: Sprint 0  
**Labels**: `learn-jira`, `planning`

**Description**:
As a DevOps engineer learning Jira, I need to define the complete project structure (epics, stories, tasks) so that I can manage the homelab project effectively and learn Jira best practices.

**Acceptance Criteria**:
- [ ] Jira project created with key "HOMELAB"
- [ ] All 8 epics created
- [ ] Workflow defined (Backlog → To Do → In Progress → Review → Testing → Done)
- [ ] Story point scale documented (1,2,3,5,8,13,21)
- [ ] Learning labels configured (learn-jira, learn-python, etc.)
- [ ] Definition of Done (DoD) defined
- [ ] Definition of Ready (DoR) defined
- [ ] First sprint created (Sprint 0)

**Learning Objectives**:
- Understand Jira hierarchy (Epic > Story > Task > Subtask)
- Learn story point estimation
- Practice writing acceptance criteria
- Understand workflow states

**Tasks**:
1. Create Jira project "HOMELAB"
2. Import epics from CSV file
3. Configure custom workflow
4. Setup labels and components
5. Create Sprint 0 (2 weeks)
6. Document DoD and DoR in wiki

**Time Estimate**: 2-4 hours

**Anti-Patterns to Avoid**:
- ❌ Creating too many epics (keep it to 8-10)
- ❌ Unclear acceptance criteria
- ❌ Stories that are too large (>13 points)
- ❌ Missing learning labels

**Resources**:
- Atlassian Jira Documentation
- Agile story writing guide
- CSV import file: `/jira/jira-import.csv`

---

### HOMELAB-3: Procure Consumer Hardware

**Story Points**: 2  
**Priority**: High  
**Sprint**: Sprint 0  
**Labels**: `hardware`, `procurement`

**Description**:
As a family homelab admin, I need to select and purchase 2x consumer-grade mini PCs that can run a small Kubernetes cluster so that I have the hardware foundation for family services.

**Acceptance Criteria**:
- [ ] 2x mini PCs purchased with specs:
  - CPU: 4+ cores (Intel N100 or better)
  - RAM: 8GB+ (16GB preferred)
  - Storage: 256GB+ SSD
  - Network: Gigabit Ethernet
  - Price: <$400 each
- [ ] Network switch purchased (8-port gigabit minimum)
- [ ] Network cables (Cat6, 3ft x 4)
- [ ] Power management (UPS or surge protector)
- [ ] Total cost <$1,000

**Learning Objectives**:
- Understand hardware requirements for Kubernetes
- Learn cost-effective hardware selection
- Plan for power and cooling

**Recommended Hardware**:

**Option 1: Beelink Mini S12 Pro** (~$180 each)
- Intel N100 (4-core, up to 3.4GHz)
- 16GB DDR4
- 500GB NVMe SSD
- 2x Gigabit Ethernet
- WiFi 6
- Total for 2: ~$360

**Option 2: Intel NUC 11** (~$350 each)
- Intel i3-1115G4 (2-core, 4-thread, up to 4.1GHz)
- 16GB DDR4
- 512GB NVMe SSD
- 2x Gigabit Ethernet
- Total for 2: ~$700

**Network Equipment**:
- TP-Link TL-SG108 (8-port Gigabit switch): ~$25
- Cat6 cables (4-pack): ~$15
- CyberPower UPS (1000VA): ~$120

**Total Budget**:
- Option 1: ~$520 (budget-friendly) ✅ RECOMMENDED
- Option 2: ~$860 (higher performance)

**Tasks**:
1. Research and compare mini PC options
2. Purchase 2x mini PCs
3. Purchase network switch and cables
4. Purchase UPS/surge protector
5. Verify all hardware received and functional
6. Document hardware in wiki

**Time Estimate**: 1-2 hours (research + ordering), 3-5 days (delivery)

**Anti-Patterns to Avoid**:
- ❌ Buying underpowered hardware (<4 cores, <8GB RAM)
- ❌ Forgetting network equipment
- ❌ No power protection
- ❌ Overspending on unnecessary features

---

### HOMELAB-4: Setup Network Infrastructure

**Story Points**: 5  
**Priority**: High  
**Sprint**: Sprint 1  
**Labels**: `learn-networking`, `foundation`

**Description**:
As a DevOps engineer, I need to configure the home network with a dedicated VLAN for the cluster so that cluster traffic is isolated and manageable with static IPs.

**Acceptance Criteria**:
- [ ] VLAN 100 created for cluster traffic
- [ ] Static IPs assigned:
  - Host 1 (node-01): 192.168.100.10
  - Host 2 (node-02): 192.168.100.11
  - VIP (for HA): 192.168.100.5
  - Gateway: 192.168.100.1
- [ ] DNS forwarding configured to point to cluster DNS
- [ ] Internet connectivity verified from both hosts
- [ ] Hosts can ping each other
- [ ] Low latency between hosts (<1ms)

**Learning Objectives**:
- Understand VLANs and network segmentation
- Learn static IP configuration
- Practice network troubleshooting

**Technical Implementation**:

**Router Configuration** (assuming router supports VLANs):
```bash
# Create VLAN 100
Interface: VLAN100
IP: 192.168.100.1/24
DHCP: Disabled
```

**Network Diagram**:
```
Internet
   ↓
[Router/Gateway] 192.168.1.1
   ↓
[Switch] (VLAN-aware)
   ├─ [VLAN 1] 192.168.1.0/24 (Main network)
   └─ [VLAN 100] 192.168.100.0/24 (Cluster)
       ├─ node-01: .10
       ├─ node-02: .11
       └─ VIP: .5
```

**Host Network Configuration** (`/etc/netplan/01-netcfg.yaml`):
```yaml
network:
  version: 2
  ethernets:
    eno1:
      addresses:
        - 192.168.100.10/24  # .11 for node-02
      gateway4: 192.168.100.1
      nameservers:
        addresses:
          - 192.168.100.5  # Cluster DNS (will setup later)
          - 8.8.8.8        # Fallback
```

**Tasks**:
1. Configure VLAN 100 on router
2. Tag switch port for VLAN 100
3. Configure static IPs on both hosts
4. Test connectivity (ping, traceroute)
5. Configure DNS forwarding
6. Document network layout
7. Create network troubleshooting runbook

**Time Estimate**: 4-8 hours

**Testing**:
```bash
# From node-01
ping -c 4 192.168.100.11
ping -c 4 8.8.8.8
ping -c 4 google.com

# Check latency
ping -c 100 192.168.100.11 | tail -1
# Should show <1ms average

# Check connectivity
curl -I https://google.com
```

**Anti-Patterns to Avoid**:
- ❌ Using DHCP for cluster nodes (use static IPs)
- ❌ Not isolating cluster traffic (security risk)
- ❌ Forgetting to configure DNS
- ❌ High latency between nodes (>5ms)

**Troubleshooting**:
- If no ping: Check switch VLAN configuration
- If no internet: Check gateway and routing
- If DNS fails: Check nameserver configuration

---

### HOMELAB-5: Install Base OS on Hosts

**Story Points**: 3  
**Priority**: Medium  
**Sprint**: Sprint 1  
**Labels**: `learn-ansible`, `learn-terraform`

**Description**:
As a DevOps engineer, I need to install CentOS Stream 9 on both hosts with cloud-init so that I have a consistent, automated base operating system.

**Acceptance Criteria**:
- [ ] CentOS Stream 9 installed on both hosts
- [ ] Cloud-init configured with:
  - Static network configuration
  - SSH keys for passwordless access
  - Hostname set (node-01, node-02)
  - Timezone set
- [ ] SSH access working from admin machine
- [ ] Both hosts accessible at 192.168.100.10 and .11
- [ ] Basic security hardening applied (firewall, SELinux)

**Learning Objectives**:
- Understand cloud-init for automation
- Learn Linux installation
- Practice SSH key management

**Pre-requisites**:
- USB drive (8GB+) for installation media
- SSH key pair generated on admin machine

**Installation Steps**:

**1. Create Installation Media**:
```bash
# Download CentOS Stream 9 ISO
curl -O https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/iso/CentOS-Stream-9-latest-x86_64-dvd1.iso

# Write to USB (replace /dev/sdX with your USB device)
sudo dd if=CentOS-Stream-9-latest-x86_64-dvd1.iso of=/dev/sdX bs=4M status=progress
```

**2. Install on node-01**:
- Boot from USB
- Select "Install CentOS Stream 9"
- Set hostname: node-01.homelab.local
- Configure network: Static IP 192.168.100.10
- Create user: admin (add to wheel group)
- Set timezone
- Select "Minimal Install" package group

**3. Cloud-Init Configuration** (`/etc/cloud/cloud.cfg.d/99_custom.cfg`):
```yaml
#cloud-config
hostname: node-01
fqdn: node-01.homelab.local
manage_etc_hosts: true

users:
  - name: admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: wheel
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-rsa AAAAB3... your-public-key

network:
  version: 2
  ethernets:
    eth0:
      addresses:
        - 192.168.100.10/24
      gateway4: 192.168.100.1
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]

timezone: America/Los_Angeles

packages:
  - vim
  - curl
  - wget
  - git

runcmd:
  - systemctl enable --now firewalld
  - firewall-cmd --permanent --add-service=ssh
  - firewall-cmd --reload
```

**4. Repeat for node-02** (change hostname and IP to .11)

**Tasks**:
1. Create installation USB
2. Install CentOS on node-01
3. Configure cloud-init on node-01
4. Install CentOS on node-02
5. Configure cloud-init on node-02
6. Generate and distribute SSH keys
7. Test SSH access from admin machine
8. Document installation process

**Time Estimate**: 2-4 hours (1-2 hours per host)

**Testing**:
```bash
# From admin machine
ssh admin@192.168.100.10 'hostname'
# Should output: node-01

ssh admin@192.168.100.11 'hostname'
# Should output: node-02

# Test passwordless sudo
ssh admin@192.168.100.10 'sudo whoami'
# Should output: root (no password prompt)
```

**Anti-Patterns to Avoid**:
- ❌ Using root account directly (create admin user)
- ❌ Password-based SSH (use key-based only)
- ❌ Disabling firewall (configure it properly)
- ❌ Not configuring cloud-init (manual config)

**Next Steps**:
After OS installation, you're ready for EPIC-2: Base Infrastructure (k3s cluster deployment)

---

### HOMELAB-6: Configure Storage Layout

**Story Points**: 5  
**Priority**: Medium  
**Sprint**: Sprint 1  
**Labels**: `storage`, `learn-kubernetes`

**Description**:
As a DevOps engineer, I need to configure local storage with LVM for flexibility so that I can allocate storage for k3s persistent volumes and maintain the ability to resize/reorganize.

**Acceptance Criteria**:
- [ ] LVM configured on both hosts with volume groups
- [ ] Partitions created:
  - /boot/efi: 512MB (EFI boot)
  - /boot: 1GB (kernels)
  - /: 50GB (root filesystem)
  - /var/lib/k3s: 50GB+ (k3s data)
  - /data: remaining space (PVs)
- [ ] Storage ready for k3s local-path provisioner
- [ ] Backup strategy documented
- [ ] Monitoring for disk usage configured

**Learning Objectives**:
- Understand LVM and disk management
- Learn Kubernetes storage concepts
- Plan for data persistence

**LVM Layout**:
```
Physical Disk (256GB SSD)
├─ /dev/sda1 (512MB) → /boot/efi
├─ /dev/sda2 (1GB) → /boot
└─ /dev/sda3 (254.5GB) → LVM PV
    └─ vg_system (Volume Group)
        ├─ lv_root (50GB) → /
        ├─ lv_k3s (50GB) → /var/lib/k3s
        └─ lv_data (154.5GB) → /data
```

**Implementation**:
```bash
# Check current disk layout
lsblk

# Create LVM physical volume
pvcreate /dev/sda3

# Create volume group
vgcreate vg_system /dev/sda3

# Create logical volumes
lvcreate -L 50G -n lv_root vg_system
lvcreate -L 50G -n lv_k3s vg_system
lvcreate -l 100%FREE -n lv_data vg_system

# Create filesystems
mkfs.xfs /dev/vg_system/lv_root
mkfs.xfs /dev/vg_system/lv_k3s
mkfs.xfs /dev/vg_system/lv_data

# Mount
mkdir -p /var/lib/k3s /data
mount /dev/vg_system/lv_k3s /var/lib/k3s
mount /dev/vg_system/lv_data /data

# Add to /etc/fstab
echo "/dev/vg_system/lv_k3s /var/lib/k3s xfs defaults 0 0" >> /etc/fstab
echo "/dev/vg_system/lv_data /data xfs defaults 0 0" >> /etc/fstab
```

**Tasks**:
1. Plan storage layout
2. Configure LVM on node-01
3. Configure LVM on node-02
4. Test LVM resizing
5. Document storage architecture
6. Create backup strategy document

**Time Estimate**: 4-6 hours

**Anti-Patterns to Avoid**:
- ❌ Not using LVM (inflexible partitioning)
- ❌ Single large partition (no separation)
- ❌ Forgetting to add to /etc/fstab
- ❌ No backup plan

**Resources**:
- Red Hat LVM Guide
- Kubernetes storage concepts
- Backup best practices

---

## Epic Completion Checklist

- [ ] All stories in this epic completed
- [ ] 2 hosts operational and accessible
- [ ] Network configured and tested
- [ ] Storage layout implemented
- [ ] Documentation complete
- [ ] Learning notes captured in Jira
- [ ] Ready to proceed to EPIC-2

---

## Related Epics

- **Next**: EPIC-2 (Base Infrastructure) - Deploy k3s cluster
- **Depends On**: None (this is the foundation)
- **Blocks**: All other epics depend on this

---

## Budget Tracking

| Item | Estimated | Actual | Notes |
|------|-----------|--------|-------|
| 2x Mini PCs | $360 | | Beelink S12 Pro |
| Network switch | $25 | | TP-Link 8-port |
| Cables | $15 | | Cat6 4-pack |
| UPS | $120 | | CyberPower 1000VA |
| **Total** | **$520** | | |

---

## Learning Log

Track what you learned in this epic:

**Jira Skills**:
- [ ] Created epics, stories, tasks
- [ ] Wrote acceptance criteria
- [ ] Estimated story points
- [ ] Managed sprints

**Technical Skills**:
- [ ] Hardware selection
- [ ] Network configuration (VLANs, static IPs)
- [ ] Linux installation and cloud-init
- [ ] LVM storage management

**Concepts**:
- [ ] Homelab architecture
- [ ] Infrastructure planning
- [ ] Cost management

**Anti-Patterns Identified**:
- List any anti-patterns you encountered or avoided

---

## Notes

Use this section for any additional notes, issues, or learnings during this epic.
