# Appliance - Home Server Software

This directory contains the software that runs on each home appliance (Raspberry Pi).

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Home Appliance (Raspberry Pi)                          │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ DNS Server  │  │ File Sharing │  │ Mail Relay   │   │
│  │ (dnsmasq)   │  │ (Samba)      │  │ (Postfix)    │   │
│  └─────────────┘  └──────────────┘  └──────────────┘   │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ PKI/Certs   │  │ Web UI       │  │ Agent        │   │
│  │ (Step-CA)   │  │ (Flask)      │  │ (Phone Home) │   │
│  └─────────────┘  └──────────────┘  └──────────────┘   │
│                            │                            │
│                            ▼                            │
│                    Backend (Cloud)                      │
└─────────────────────────────────────────────────────────┘
```

## Hardware Requirements

**Recommended:**
- Raspberry Pi 4 Model B (4GB RAM) or Raspberry Pi 5
- 64 GB USB 3.0 SSD (boot + data)
- Gigabit Ethernet connection
- Official power supply (15W USB-C)

**Minimum:**
- Raspberry Pi 4 Model B (2GB RAM)
- 32 GB microSD card (Class 10 or better)
- Fast Ethernet (100 Mbps)

## Components

### `/services` - Service Setup Scripts

Each service has setup and configuration scripts:

- **`/dns`** - dnsmasq configuration (DNS + DHCP)
- **`/samba`** - Samba file sharing setup
- **`/mail`** - Postfix mail relay configuration
- **`/pki`** - Step-CA certificate authority

**Each service includes:**
- `setup.sh` - Installation script
- `config.sh` - Configuration script
- `service_name.conf.j2` - Jinja2 config template
- `README.md` - Service documentation

### `/agent` - Phone Home Agent

Python daemon that communicates with backend:

**Features:**
- Heartbeat every 60 seconds to backend
- Config sync every 5 minutes
- Metrics export (CPU, RAM, disk)
- Self-update mechanism
- Offline queue (store and forward)

**Files:**
- `agent.py` - Main agent code
- `config.py` - Configuration
- `systemd/aiops-agent.service` - Systemd unit file

### `/ui` - Onboarding Web Interface

Simple web UI for initial appliance setup:

**Features:**
- Network configuration wizard
- Backend registration
- Service status dashboard
- Basic troubleshooting

**Tech Stack:**
- Flask (Python web framework)
- Htmx (dynamic HTML)
- Tailwind CSS (styling)

## Services Resource Usage

| Service | RAM (MB) | Storage (GB) | CPU (%) | Ports |
|---------|----------|--------------|---------|-------|
| dnsmasq | 10-20 | 0.1 | 1-3 | 53, 67 |
| Samba | 50-150 | 1-5 | 5-15 | 139, 445 |
| Postfix | 30-100 | 2 | 2-5 | 25 |
| Step-CA | 20-50 | 0.5 | 1-2 | 8443 |
| Web UI | 100-200 | 1 | 5-10 | 80, 443 |
| Agent | 50-100 | 0.5 | 2-5 | - |

**Total:** ~1-1.5 GB RAM, ~5-10 GB storage

## Installation

### Option 1: Pre-built Image (Recommended)
```bash
# Flash pre-built image to SD card or USB SSD
# Image includes all services pre-installed

# Download image
wget https://downloads.aiops.example.com/aiops-appliance-v1.0.0.img.gz

# Flash to device
gunzip -c aiops-appliance-v1.0.0.img.gz | sudo dd of=/dev/sdX bs=4M status=progress

# Boot Raspberry Pi and visit http://appliance.local for setup
```

### Option 2: Manual Installation
```bash
# Start with Raspberry Pi OS Lite (64-bit)

# Clone repository
git clone https://github.com/your-org/aiops-appliance.git
cd aiops-appliance/appliance

# Run installation script
sudo ./install.sh

# Services will be automatically configured and started
```

## Development

### Testing on x86/ARM64 (Docker)
```bash
# Build appliance Docker image for testing
cd appliance
docker build -t aiops-appliance:dev -f Dockerfile .

# Run simulated appliance
docker run -d \
  --name test-appliance \
  --hostname appliance-test \
  -p 53:53/udp \
  -p 80:80 \
  -p 445:445 \
  -e BACKEND_URL=http://backend:8000 \
  aiops-appliance:dev

# Check logs
docker logs -f test-appliance
```

### Local Development
```bash
# Install dependencies
pip install -r agent/requirements.txt
pip install -r ui/requirements.txt

# Run agent locally (for testing)
cd agent
python agent.py --config config.dev.yml

# Run web UI locally
cd ui
flask run --port 8080
```

## Configuration

### Agent Configuration (`agent/config.yml`)
```yaml
backend:
  url: https://backend.aiops.example.com
  api_key: ${API_KEY}  # Set from environment

appliance:
  id: uuid-1234-5678
  name: home-appliance-001

heartbeat:
  interval: 60  # seconds

config_sync:
  interval: 300  # seconds (5 minutes)

services:
  - dns
  - samba
  - mail
  - pki

logging:
  level: INFO
  file: /var/log/aiops-agent.log
```

### Network Configuration
```bash
# Set static IP (recommended)
sudo nano /etc/dhcpcd.conf

# Add:
interface eth0
static ip_address=192.168.1.100/24
static routers=192.168.1.1
static domain_name_servers=1.1.1.1 8.8.8.8
```

## Monitoring

### Service Status
```bash
# Check all services
sudo systemctl status aiops-*

# Individual services
sudo systemctl status aiops-agent
sudo systemctl status dnsmasq
sudo systemctl status smbd
sudo systemctl status postfix
```

### Logs
```bash
# Agent logs
sudo journalctl -u aiops-agent -f

# All AIOps logs
sudo journalctl -u "aiops-*" -f --since "1 hour ago"
```

### Resource Usage
```bash
# CPU, RAM, Disk
htop

# Detailed metrics (if node_exporter installed)
curl http://localhost:9100/metrics
```

## Troubleshooting

### Agent not connecting to backend
```bash
# Check connectivity
ping backend.aiops.example.com

# Check DNS resolution
nslookup backend.aiops.example.com

# Check agent logs
sudo journalctl -u aiops-agent -n 100

# Restart agent
sudo systemctl restart aiops-agent
```

### DNS not working
```bash
# Check dnsmasq status
sudo systemctl status dnsmasq

# Test DNS resolution
dig @localhost google.com

# Check dnsmasq logs
sudo journalctl -u dnsmasq -n 50
```

### Samba not accessible
```bash
# Check Samba status
sudo systemctl status smbd nmbd

# Test Samba connectivity
smbclient -L localhost -N

# Check firewall (should allow ports 139, 445)
sudo ufw status
```

## Security

### Automatic Updates
```bash
# Enable unattended upgrades
sudo apt install unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades
```

### Firewall
```bash
# Enable UFW firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow necessary ports
sudo ufw allow 53/udp    # DNS
sudo ufw allow 80/tcp    # Web UI
sudo ufw allow 445/tcp   # Samba
sudo ufw allow 22/tcp    # SSH (for Ansible)

# Enable firewall
sudo ufw enable
```

### SSH Hardening
```bash
# Disable password authentication (use keys only)
sudo nano /etc/ssh/sshd_config

# Set:
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes

# Restart SSH
sudo systemctl restart sshd
```

## Update Process

### Automatic Updates
The agent handles automatic software updates:
1. Backend pushes update notification
2. Agent downloads new version
3. Validates signature
4. Applies update during maintenance window
5. Restarts services
6. Reports success/failure to backend

### Manual Update
```bash
# Update appliance software
sudo /opt/aiops/update.sh

# Or via Ansible from backend
ansible-playbook -i inventory playbooks/update.yml
```

## Backup & Recovery

### Automatic Backups
- Configuration backed up to backend every 24 hours
- User data optionally synced to cloud storage
- Full system image snapshot weekly (if SD card allows)

### Manual Backup
```bash
# Backup configuration
sudo tar -czf /tmp/aiops-config-backup.tar.gz /etc/aiops /opt/aiops

# Copy to safe location
scp /tmp/aiops-config-backup.tar.gz user@backup-server:~/
```

### Recovery
```bash
# Restore from backup
sudo tar -xzf aiops-config-backup.tar.gz -C /

# Restart services
sudo systemctl restart aiops-*
```

## Performance Tuning

### Optimize for SD Card
```bash
# Reduce log writes
sudo nano /etc/systemd/journald.conf
# Set: Storage=volatile

# Use tmpfs for temporary files
sudo nano /etc/fstab
# Add: tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0

# Reboot
sudo reboot
```

### Use USB SSD (Recommended)
```bash
# Boot from SD card, but store data on USB SSD
# Mount SSD at /srv

sudo mkdir /srv
sudo mount /dev/sda1 /srv

# Add to /etc/fstab
echo "UUID=<uuid> /srv ext4 defaults,noatime 0 2" | sudo tee -a /etc/fstab

# Move data to SSD
sudo rsync -av /var/lib/samba/ /srv/samba/
sudo ln -s /srv/samba /var/lib/samba
```
