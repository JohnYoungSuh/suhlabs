# Packer Template for CentOS Stream 9

This directory contains Packer templates to build CentOS Stream 9 VM templates optimized for k3s on Proxmox.

## Prerequisites

1. **Packer** >= 1.9.0
   ```bash
   packer version
   ```

2. **Proxmox VE** with API access
3. **Proxmox API Token** (recommended) or username/password

## Quick Start

### 1. Configure Proxmox Credentials

Set environment variables:

```bash
export PM_API_URL="https://proxmox.example.com:8006/api2/json"
export PM_API_TOKEN_ID="terraform@pam!terraform"
export PM_API_TOKEN_SECRET="your-secret-token-here"
```

**Or create a `.env` file** (add to `.gitignore`):

```bash
# .env
PM_API_URL=https://192.168.1.100:8006/api2/json
PM_API_TOKEN_ID=packer@pam!packer
PM_API_TOKEN_SECRET=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

Load it with:
```bash
source .env
```

### 2. Create Proxmox API Token

If you don't have an API token yet:

1. Log into Proxmox web UI
2. Go to **Datacenter → Permissions → API Tokens**
3. Click **Add**
4. Set:
   - User: `packer@pam` (or create a dedicated user)
   - Token ID: `packer`
   - Privilege Separation: **Unchecked** (or configure permissions)
5. Copy the token secret (shown only once!)

### 3. Validate Template

```bash
cd packer
packer validate centos9-cloudinit.pkr.hcl
```

### 4. Build Template

```bash
packer build centos9-cloudinit.pkr.hcl
```

Or use the Makefile from project root:

```bash
make packer-validate
make packer-build
```

## Configuration Variables

You can override variables via command line:

```bash
packer build \
  -var "proxmox_url=https://192.168.1.100:8006/api2/json" \
  -var "proxmox_node=pve01" \
  -var "proxmox_storage_pool=local-lvm" \
  -var "vm_memory=8192" \
  centos9-cloudinit.pkr.hcl
```

### Available Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `proxmox_url` | `$PM_API_URL` | Proxmox API URL |
| `proxmox_token_id` | `$PM_API_TOKEN_ID` | API Token ID |
| `proxmox_token_secret` | `$PM_API_TOKEN_SECRET` | API Token Secret |
| `proxmox_node` | `proxmox-01` | Target Proxmox node |
| `proxmox_storage_pool` | `ceph-rbd` | Storage pool for VM disks |
| `iso_storage_pool` | `local` | Storage pool for ISO files |
| `template_name` | `centos9-cloud` | Name of the template |
| `vm_cpu_cores` | `2` | Number of CPU cores |
| `vm_memory` | `4096` | RAM in MB |
| `vm_disk_size` | `50G` | Disk size |

## What Gets Installed

The template includes:

- **Base OS**: CentOS Stream 9 (latest)
- **Cloud-init**: For VM provisioning automation
- **Container Runtime**: containerd (configured for Kubernetes)
- **Kernel modules**: overlay, br_netfilter
- **System tuning**: sysctl optimizations for k3s
- **Monitoring tools**: sysstat, iotop, iftop
- **Security**: firewalld, fail2ban, SELinux enabled
- **Time sync**: chrony
- **QEMU Guest Agent**: For Proxmox integration

## Template Output

After successful build, you'll have:

- **Template name**: `centos9-cloud` (in Proxmox)
- **Cloud-init enabled**: Ready for SSH key injection
- **k3s-ready**: All prerequisites installed

## Using the Template

Once built, create VMs from this template:

```bash
# Via Proxmox UI: Right-click template → Clone

# Via Terraform (see infra/proxmox/)
# Via Ansible (see ansible/)
```

## Troubleshooting

### Error: "username must be specified"

**Solution**: Set `PM_API_TOKEN_ID` environment variable:
```bash
export PM_API_TOKEN_ID="packer@pam!packer"
```

### Error: "proxmox_url must be specified"

**Solution**: Set `PM_API_URL` environment variable:
```bash
export PM_API_URL="https://192.168.1.100:8006/api2/json"
```

### Error: "bad response code: 404" for checksum

**Solution**: This is fixed in the latest version. The ISO URL now points directly to:
```
https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/iso/
```

### Build hangs at "Waiting for SSH..."

**Causes**:
- Firewall blocking SSH (port 22)
- Incorrect network configuration
- Boot command failed to start kickstart

**Debug**:
1. Open Proxmox console for the VM
2. Check if kickstart is loading
3. Verify network connectivity

### Template not appearing in Proxmox

**Check**:
```bash
pvesh get /nodes/proxmox-01/qemu --output-format=json | grep centos9
```

## Files

- `centos9-cloudinit.pkr.hcl` - Main Packer template
- `http/centos9-ks.cfg` - Kickstart file for automated installation
- `README.md` - This file

## Next Steps

After building the template:

1. **Test the template**: Clone it and verify cloud-init works
2. **Provision infrastructure**: Use Terraform (see `infra/proxmox/`)
3. **Deploy k3s**: Use Ansible (see `ansible/`)

See the main project [deployment runbook](../docs/deployment-runbook.md) for complete workflow.
