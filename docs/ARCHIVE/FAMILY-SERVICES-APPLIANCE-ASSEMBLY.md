# Family Services Appliance - Assembly Guide

## Pro Tier Assembly: Dual Orange Pi 5 Plus (16GB)

This guide covers the physical assembly and initial setup of the recommended Pro Tier configuration.

## Prerequisites

### Tools Required
- Phillips head screwdriver (#1 or #2)
- Small flathead screwdriver (optional, for cable management)
- Anti-static wrist strap (recommended)
- Label maker or labels (for cable identification)
- Multimeter (optional, for power verification)

### Workspace Setup
- Clean, static-free work surface
- Good lighting
- Organized component layout
- Cable management supplies (zip ties, Velcro straps)

## Bill of Materials Checklist

Print this and check off items as you unpack:

```
Hardware Components:
□ (2) Orange Pi 5 Plus (16GB) boards
□ (2) 512GB NVMe M.2 SSDs
□ (2) 32GB eMMC modules
□ (2) 12V/3A DC power adapters
□ (2) Metal cases with active cooling
□ (1) 8-port Gigabit/2.5GbE managed switch
□ (1) UPS (750-800VA)
□ (5+) Cat6/Cat6A Ethernet cables
□ (1) Power strip with surge protection

Optional:
□ Rack mount shelf or stackable case
□ Cable management accessories
□ Additional cooling fans
□ Thermal pads/paste
```

## Assembly Steps

### Step 1: Prepare Workspace

1. **Clear work area** and lay out anti-static mat
2. **Ground yourself** with anti-static wrist strap
3. **Organize components** by node (Node 1, Node 2)
4. **Label everything** before assembly

### Step 2: Node Assembly (Repeat for Both Nodes)

#### 2.1 Install eMMC Module

**⚠️ IMPORTANT**: Do this BEFORE installing in case to avoid damage

1. Locate the eMMC socket on the Orange Pi 5 Plus board (underside)
2. Align the eMMC module with the socket (notch alignment)
3. Press firmly until seated (you'll hear/feel a click)
4. Gently tug to verify it's locked in place

**Common Mistakes:**
- ❌ Installing backwards (check notch alignment)
- ❌ Not pressing firmly enough
- ❌ Forcing at wrong angle

#### 2.2 Install NVMe SSD

1. Locate the M.2 slot (usually labeled M.2 M-Key)
2. Remove any protective film from the SSD
3. Insert SSD at 30-degree angle into the M.2 slot
4. Press down gently and secure with provided screw
5. **Do not overtighten** - finger tight plus 1/4 turn

**Torque**: Use minimal force; the screw should be snug but not tight

#### 2.3 Apply Thermal Management

**If using metal case with heatsink:**
1. Clean the SoC surface with isopropyl alcohol
2. Remove protective film from thermal pad
3. Apply thermal pad to SoC (center it carefully)
4. Some cases include thermal pads pre-installed on lid

**If using separate heatsink:**
1. Apply small rice-grain size of thermal paste to SoC
2. Spread evenly with plastic card
3. Mount heatsink with provided clips/screws

#### 2.4 Install Board in Case

1. **Check fan connector** - ensure it's accessible
2. Position board in case (align mounting holes)
3. Use provided standoffs/screws (don't overtighten)
4. Connect cooling fan to board's fan header
   - **Orange Pi 5 Plus**: Usually 3-pin or 4-pin header near power
   - **Polarity matters**: Ground (black) to ground pin

5. Route cables neatly (keep away from fan)
6. Close case and secure with screws

#### 2.5 Label the Node

Apply label to case:
```
NODE 1
MAC: [write MAC here after first boot]
IP: [reserve DHCP or static IP]
Hostname: familysvc-node1
```

### Step 3: Network Setup

#### 3.1 Configure Switch

**Before connecting nodes:**

1. **Power on switch** and wait for boot (2-3 minutes)
2. **Access management interface**:
   - Default IP: Usually 192.168.0.1 or printed on switch
   - Default credentials: admin/admin (change immediately!)

3. **Basic configuration**:
   - Set static management IP (e.g., 192.168.1.250)
   - Update firmware if available
   - Enable VLAN support (if using VLANs)
   - Configure port speeds (2.5GbE if supported)

4. **Create VLANs** (optional but recommended):
   ```
   VLAN 10: Management (switch, UPS, monitoring)
   VLAN 20: Services (k3s cluster traffic)
   VLAN 30: Family Network (user devices)
   VLAN 40: Storage (if using separate NAS)
   ```

5. **Port assignments**:
   ```
   Port 1: Uplink to home router (trunk all VLANs)
   Port 2: Node 1 (trunk VLANs 10, 20, 40 or access VLAN 20)
   Port 3: Node 2 (trunk VLANs 10, 20, 40 or access VLAN 20)
   Port 4: UPS management (access VLAN 10)
   Port 5: NAS (access VLAN 40 or trunk)
   Port 6-8: Reserved/spare
   ```

#### 3.2 Cable Everything

**Cable labeling scheme:**
```
NODE1-ETH0 → SW-P2
NODE2-ETH0 → SW-P3
UPS-MGMT → SW-P4
SW-UPLINK → ROUTER-P1
```

**Cable routing best practices:**
- Keep power cables separate from data cables
- Use cable management clips/velcro
- Leave service loops (slack for maintenance)
- Label both ends of each cable

### Step 4: Power Infrastructure

#### 4.1 UPS Setup

1. **Unpack and inspect** UPS
2. **Install battery** (if not pre-installed)
   - Remove battery cover
   - Connect battery terminals (red to red, black to black)
   - Secure battery in place
   - Replace cover

3. **Initial charge**: Plug UPS into wall outlet
   - Charge for 8-12 hours before first use
   - Do NOT plug in equipment during initial charge

4. **Configure UPS** (after initial charge):
   - Connect to management port
   - Access web interface (IP printed on UPS)
   - Configure shutdown thresholds:
     - Warning: 30% battery
     - Shutdown: 10% battery
   - Set up email alerts
   - Enable network management protocol (SNMP)

#### 4.2 Power Distribution

**Connection order** (from UPS outlets):

```
Priority 1 (Battery backup outlets):
├─ Network switch
├─ Node 1
└─ Node 2

Priority 2 (Surge protection only):
├─ NAS (if using)
└─ Spare
```

**Important:**
- Use UPS provided cables when possible
- Don't daisy-chain power strips
- Don't exceed UPS rated capacity (check watts)
- Leave at least 20% headroom

### Step 5: Initial Power-On

#### 5.1 Pre-flight Checklist

Before powering on:
```
□ All screws tightened (but not overtightened)
□ No loose components inside cases
□ Thermal paste/pads applied correctly
□ Fans connected and cables routed properly
□ eMMC and NVMe firmly seated
□ Network cables connected
□ UPS fully charged
□ Switch powered on and configured
□ Work area clear of conductive materials
```

#### 5.2 First Boot Sequence

**Power on Node 1:**

1. Connect power adapter to Node 1
2. Press power button (if present) or auto-boots
3. **Observe LEDs**:
   - Power LED: Solid (good)
   - Activity LED: Blinking (booting)
   - Network LED: Link/Activity after boot

4. **Listen for POST**:
   - Fan should spin up
   - No unusual beeps or grinding
   - Fan should stabilize after ~10 seconds

5. **Check temperatures** (after 5 minutes):
   - Access via serial console or SSH after boot
   - `cat /sys/class/thermal/thermal_zone*/temp`
   - Should be < 60°C idle, < 75°C under light load

**Wait 5 minutes, then power on Node 2** (same process)

#### 5.3 Troubleshooting First Boot

**No power LED:**
- Check power adapter connection
- Verify outlet has power
- Try different power adapter
- Check board for physical damage

**No network link:**
- Check cable connections (both ends)
- Verify switch port is active
- Try different cable
- Check switch port LEDs

**Continuous reboots:**
- Insufficient power supply
- Overheating (check fan, heatsink)
- Bad eMMC or NVMe
- Hardware defect

**Fan not spinning:**
- Check fan connector orientation
- Verify fan header on board
- Test fan separately with multimeter
- May need BIOS/bootloader settings

### Step 6: Network Verification

#### 6.1 Check DHCP Assignments

1. Access your router's DHCP leases page
2. Look for new devices (Orange Pi 5 Plus)
3. Note MAC addresses and IP assignments
4. Create static DHCP reservations:
   ```
   Node 1: 192.168.1.11
   Node 2: 192.168.1.12
   ```

#### 6.2 Test Connectivity

From your laptop/PC:

```bash
# Ping both nodes
ping 192.168.1.11
ping 192.168.1.12

# Check network speed
iperf3 -s  # On one node
iperf3 -c 192.168.1.11 -t 30  # From another device
```

**Expected results:**
- 940+ Mbps on 1GbE
- 2.3+ Gbps on 2.5GbE
- RTT < 1ms on local network

### Step 7: Access and Initial Configuration

#### 7.1 Serial Console Access (Recommended for First Boot)

**Equipment needed:**
- USB-to-TTL serial adapter (3.3V)
- Jumper wires

**Connections** (Orange Pi 5 Plus debug header):
```
USB-TTL    →    Orange Pi 5 Plus
GND        →    Pin 6 (GND)
RX         →    Pin 8 (TX)
TX         →    Pin 10 (RX)
```

**Software:**
- Linux/Mac: `screen /dev/ttyUSB0 115200`
- Windows: PuTTY or TeraTerm

**Settings:**
- Baud rate: 115200
- Data bits: 8
- Stop bits: 1
- Parity: None
- Flow control: None

#### 7.2 SSH Access (After Network Configuration)

```bash
# Default credentials (change immediately!)
ssh root@192.168.1.11
# or
ssh orangepi@192.168.1.11

# Common default passwords:
# - orangepi
# - root
# - (blank)
```

**First tasks after SSH access:**
```bash
# Update system
apt update && apt upgrade -y

# Change root password
passwd

# Set hostname
hostnamectl set-hostname familysvc-node1

# Configure timezone
timedatectl set-timezone America/New_York

# Enable NTP
timedatectl set-ntp true

# Verify storage
lsblk
# Should see eMMC and NVMe

# Check temperatures
cat /sys/class/thermal/thermal_zone*/temp
```

### Step 8: Storage Configuration

#### 8.1 Verify Storage Devices

```bash
# List block devices
lsblk

# Expected output:
# mmcblk0       (eMMC - 32GB)
# ├─mmcblk0p1   (boot partition)
# └─mmcblk0p2   (root partition)
# nvme0n1       (NVMe - 512GB)

# Check NVMe health
nvme smart-log /dev/nvme0n1
```

#### 8.2 Partition and Format NVMe (if not done)

**⚠️ WARNING**: This will erase all data on NVMe

```bash
# Create partition table
parted /dev/nvme0n1 mklabel gpt

# Create single partition
parted /dev/nvme0n1 mkpart primary ext4 0% 100%

# Format as ext4
mkfs.ext4 -L nvme-data /dev/nvme0n1p1

# Create mount point
mkdir -p /mnt/nvme

# Add to fstab
echo "LABEL=nvme-data /mnt/nvme ext4 defaults,noatime 0 2" >> /etc/fstab

# Mount
mount -a

# Verify
df -h /mnt/nvme
```

### Step 9: Documentation

#### 9.1 Create Node Documentation

For each node, document:

```markdown
# Node 1 - familysvc-node1

## Hardware
- Model: Orange Pi 5 Plus
- RAM: 16GB
- Storage: 32GB eMMC + 512GB NVMe
- MAC Address: [from `ip link`]
- Serial Number: [from case label]

## Network
- Primary IP: 192.168.1.11
- Hostname: familysvc-node1.home.lan
- VLAN: 20 (Services)
- Switch Port: 2

## Power
- UPS Outlet: #1
- Power Supply: 12V/3A (Orange Pi official)
- Estimated Power Draw: 15-25W

## Storage Layout
- /dev/mmcblk0: eMMC (boot, root)
- /dev/nvme0n1: NVMe (k3s data, containers)

## Initial Configuration Date
- [Date]
- Configured by: [Name]
- OS Version: [Ubuntu/Armbian version]

## Notes
- [Any specific quirks, issues, or configuration notes]
```

#### 9.2 Create Network Diagram

Document your final network topology:

```
Internet
   │
   ├─ ISP Router (192.168.1.1)
   │
   └─ Managed Switch (192.168.1.250)
       ├─ Port 1: Uplink to router
       ├─ Port 2: Node 1 (192.168.1.11)
       ├─ Port 3: Node 2 (192.168.1.12)
       ├─ Port 4: UPS Management (192.168.1.249)
       └─ Port 5-8: Reserved

UPS: CyberPower CP800AVR
├─ Outlet 1-3: Battery backup (nodes, switch)
└─ Outlet 4-6: Surge protection only
```

### Step 10: Post-Assembly Testing

#### 10.1 Stress Test

**Temperature test** (run for 30 minutes):
```bash
# Install stress-ng
apt install stress-ng

# CPU stress test
stress-ng --cpu 0 --timeout 30m

# Monitor temperatures
watch -n 1 cat /sys/class/thermal/thermal_zone0/temp
```

**Acceptable temperatures:**
- Idle: 35-50°C
- Load: 60-75°C
- Thermal throttle: 85°C (should not reach)

**If temperatures are too high:**
- Check heatsink contact
- Verify fan operation
- Consider additional cooling
- Check case airflow

#### 10.2 Network Performance Test

```bash
# Install iperf3
apt install iperf3

# On Node 1:
iperf3 -s

# On Node 2:
iperf3 -c 192.168.1.11 -t 60 -P 4
```

**Expected results:**
- 1GbE: 940+ Mbps
- 2.5GbE: 2.3+ Gbps

#### 10.3 Storage Performance Test

```bash
# Install fio
apt install fio

# Sequential read test
fio --name=seqread --rw=read --bs=1M --size=4G --filename=/mnt/nvme/test

# Sequential write test
fio --name=seqwrite --rw=write --bs=1M --size=4G --filename=/mnt/nvme/test

# Random IOPS test
fio --name=randread --rw=randread --bs=4k --size=1G --filename=/mnt/nvme/test
```

**Expected NVMe performance:**
- Sequential read: 1,500+ MB/s
- Sequential write: 1,000+ MB/s
- Random read IOPS: 100,000+

#### 10.4 UPS Failover Test

**⚠️ WARNING**: This will cut power to equipment

```bash
# Install apcupsd or nut
apt install apcupsd

# Configure UPS communication
# Edit /etc/apcupsd/apcupsd.conf

# Test UPS communication
apcaccess status

# Simulate power failure (disconnect UPS from wall)
# Monitor:
# 1. Nodes remain powered
# 2. UPS runtime estimate
# 3. Shutdown trigger at low battery
```

**Test checklist:**
```
□ Nodes remain powered during wall power loss
□ UPS runtime > 10 minutes at full load
□ Shutdown triggers at configured threshold
□ Nodes gracefully power down
□ Systems automatically restart when power returns
```

## Common Issues and Solutions

### Issue: Board won't boot

**Symptoms**: No LEDs, no fan spin

**Solutions:**
1. Check power adapter voltage (12V) and current rating (3A minimum)
2. Verify power barrel connector is fully inserted
3. Try different power outlet
4. Check for damaged power jack on board
5. Test power adapter with multimeter

### Issue: High temperatures

**Symptoms**: Over 80°C under load, thermal throttling

**Solutions:**
1. Reapply thermal paste/pad
2. Verify heatsink is making contact
3. Check fan is spinning (should be ~3000+ RPM under load)
4. Improve case airflow (add vents, better case)
5. Reduce ambient temperature
6. Consider larger heatsink or active cooling upgrade

### Issue: NVMe not detected

**Symptoms**: `lsblk` doesn't show nvme0n1

**Solutions:**
1. Reseat the NVMe drive (remove and reinsert)
2. Check M.2 slot compatibility (must be M-Key for NVMe)
3. Verify SSD is NVMe protocol (not SATA M.2)
4. Update bootloader/firmware
5. Try different NVMe drive to rule out compatibility
6. Check for bent pins in M.2 slot

### Issue: Network not working

**Symptoms**: No link LED, no DHCP, can't ping

**Solutions:**
1. Check cable on both ends
2. Try different cable (Cat5e minimum for 1GbE, Cat6 for 2.5GbE)
3. Verify switch port is enabled
4. Check for IP conflict
5. Disable and re-enable network interface: `ip link set eth0 down && ip link set eth0 up`
6. Check switch VLAN configuration

### Issue: Intermittent reboots

**Symptoms**: Random crashes, unexpected reboots

**Solutions:**
1. Check power supply (undersized or failing)
2. Verify UPS isn't causing voltage fluctuations
3. Check temperatures (thermal protection)
4. Test RAM (if removable - not on Orange Pi)
5. Review kernel logs: `dmesg | grep -i error`
6. Check for loose connections

## Next Steps

After completing assembly:

1. ✅ **Proceed to deployment guide**: [FAMILY-SERVICES-APPLIANCE-DEPLOYMENT.md](FAMILY-SERVICES-APPLIANCE-DEPLOYMENT.md)
2. Configure k3s cluster and high availability
3. Deploy core services (PhotoPrism, email, DNS)
4. Set up monitoring and alerts
5. Configure automated backups
6. Create operational runbooks

## Maintenance Schedule

### Daily (Automated)
- Temperature monitoring
- Service health checks
- Backup verification

### Weekly
- Review logs for errors
- Check disk space
- Verify UPS battery status

### Monthly
- Clean dust from cases/fans
- Update operating system
- Test UPS failover
- Review and rotate logs

### Quarterly
- Thermal paste replacement (if needed)
- Full system backup verification
- Review and update documentation
- Check for firmware updates

### Annually
- UPS battery replacement (if needed)
- Deep clean (compressed air)
- Cable management review
- Hardware upgrade evaluation

## Safety Notes

- Never work on equipment while powered
- Use anti-static precautions
- Don't block ventilation openings
- Keep liquids away from equipment
- Follow proper electrical safety
- Ensure adequate ventilation in enclosed spaces
- Don't exceed UPS capacity ratings

## Appendix A: Orange Pi 5 Plus Pinout

[Include pinout diagram or reference to official documentation]

## Appendix B: Recommended Tools and Supplies

### Essential Tools
- Phillips screwdriver set
- Anti-static wrist strap
- Cable tester
- Label maker
- Multimeter

### Consumables
- Thermal paste (Arctic MX-4 or equivalent)
- Isopropyl alcohol (90%+) and lint-free cloths
- Cable ties and Velcro straps
- Anti-static bags
- Compressed air (for cleaning)

### Optional but Useful
- USB-to-TTL serial adapter
- Raspberry Pi Debug Probe
- Temperature sensor (for ambient monitoring)
- Cable labeling sleeves
- Small flashlight or headlamp

## Support and Community

- Orange Pi Forum: http://www.orangepi.org/
- Armbian Forum: https://forum.armbian.com/
- k3s Documentation: https://docs.k3s.io/
- OpenMediaVault Forum: https://forum.openmediavault.org/

## Revision History

- v1.0 (2024-11-18): Initial assembly guide for Pro Tier
