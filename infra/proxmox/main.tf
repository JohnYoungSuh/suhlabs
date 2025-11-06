# Proxmox Infrastructure for AIOps Substrate
# Creates k3s cluster with HA control plane and worker autoscaling groups

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 2.9.14"
    }
  }

  # Remote state backend (configure via backend.hcl)
  backend "http" {}
}

# Provider configuration
provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
  pm_tls_insecure     = var.proxmox_tls_insecure
  pm_parallel         = 3
  pm_timeout          = 600
  pm_log_enable       = true
  pm_log_file         = "terraform-proxmox.log"
  pm_log_levels = {
    _default    = "debug"
    _capturelog = ""
  }
}

# Local variables
locals {
  # Cluster configuration
  cluster_name = "aiops-k3s"
  domain       = var.domain

  # Network configuration
  vpc_cidr           = var.vpc_cidr
  control_plane_ips  = [for i in range(var.control_plane_count) : cidrhost(var.vpc_cidr, 10 + i)]
  worker_base_ip_offset = 20
  lb_vip             = cidrhost(var.vpc_cidr, 5)

  # Common tags
  common_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "AIOps-Substrate"
    Cluster     = local.cluster_name
  }

  # Cloud-init template
  cloudinit_template_name = var.vm_template_name

  # SSH keys
  ssh_keys = join("\n", var.ssh_public_keys)
}

#-----------------------------------
# VPC-like Network Configuration
#-----------------------------------

# Proxmox SDN Zone (VPC equivalent)
resource "proxmox_virtual_environment_network_linux_bridge" "vpc_bridge" {
  count = var.create_isolated_network ? 1 : 0

  node_name = var.proxmox_nodes[0]
  name      = "vmbr${var.vpc_bridge_id}"
  comment   = "AIOps VPC Bridge - ${var.environment}"
  
  address = cidrhost(var.vpc_cidr, 1)
  gateway = cidrhost(var.vpc_cidr, 1)
  
  vlan_aware = true
  mtu        = 9000  # Jumbo frames for Ceph
}

# Firewall rules for k3s cluster
resource "proxmox_virtual_environment_firewall_rules" "k3s_cluster" {
  count = var.create_isolated_network ? 1 : 0

  node_name = var.proxmox_nodes[0]

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow SSH"
    dest    = ""
    dport   = "22"
    proto   = "tcp"
    source  = var.admin_cidr
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow k3s API"
    dest    = ""
    dport   = "6443"
    proto   = "tcp"
    source  = var.vpc_cidr
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow Kubelet"
    dest    = ""
    dport   = "10250"
    proto   = "tcp"
    source  = var.vpc_cidr
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow Flannel VXLAN"
    dest    = ""
    dport   = "8472"
    proto   = "udp"
    source  = var.vpc_cidr
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow NodePort Services"
    dest    = ""
    dport   = "30000:32767"
    proto   = "tcp"
    source  = "0.0.0.0/0"
  }
}

#-----------------------------------
# Load Balancer (HAProxy VMs)
#-----------------------------------

resource "proxmox_vm_qemu" "k3s_lb" {
  count = var.ha_lb_count

  name        = "${local.cluster_name}-lb-${count.index + 1}"
  target_node = var.proxmox_nodes[count.index % length(var.proxmox_nodes)]
  desc        = "k3s HA Load Balancer - ${local.cluster_name}"

  clone      = local.cloudinit_template_name
  full_clone = true
  vmid       = 200 + count.index

  # Hardware
  cores   = 2
  sockets = 1
  cpu     = "host"
  memory  = 4096

  # Disk
  disk {
    type    = "scsi"
    storage = var.storage_pool
    size    = "20G"
    format  = "raw"
    iothread = 1
    discard = "on"
    ssd     = 1
  }

  # Network
  network {
    model  = "virtio"
    bridge = var.create_isolated_network ? "vmbr${var.vpc_bridge_id}" : "vmbr0"
    tag    = var.vlan_id
  }

  # Cloud-init
  os_type    = "cloud-init"
  ipconfig0  = "ip=${local.lb_vip}/24,gw=${cidrhost(var.vpc_cidr, 1)}"
  nameserver = var.dns_servers
  searchdomain = local.domain
  sshkeys    = local.ssh_keys
  ciuser     = var.vm_user

  # Provisioning
  agent = 1

  lifecycle {
    ignore_changes = [
      network,
      disk,
    ]
  }

  tags = "loadbalancer,k3s,${var.environment}"
}

#-----------------------------------
# k3s Control Plane Nodes
#-----------------------------------

resource "proxmox_vm_qemu" "k3s_control_plane" {
  count = var.control_plane_count

  name        = "${local.cluster_name}-cp-${count.index + 1}"
  target_node = var.proxmox_nodes[count.index % length(var.proxmox_nodes)]
  desc        = "k3s Control Plane - ${local.cluster_name}"

  clone      = local.cloudinit_template_name
  full_clone = true
  vmid       = 100 + count.index

  # Hardware
  cores   = var.control_plane_cpu
  sockets = 1
  cpu     = "host"
  memory  = var.control_plane_memory

  # HA settings
  ha_state = "started"
  ha_group = "k3s-control-plane"

  # Disk
  disk {
    type    = "scsi"
    storage = var.storage_pool
    size    = var.control_plane_disk_size
    format  = "raw"
    iothread = 1
    discard = "on"
    ssd     = 1
  }

  # Network
  network {
    model  = "virtio"
    bridge = var.create_isolated_network ? "vmbr${var.vpc_bridge_id}" : "vmbr0"
    tag    = var.vlan_id
  }

  # Cloud-init
  os_type    = "cloud-init"
  ipconfig0  = "ip=${local.control_plane_ips[count.index]}/24,gw=${cidrhost(var.vpc_cidr, 1)}"
  nameserver = var.dns_servers
  searchdomain = local.domain
  sshkeys    = local.ssh_keys
  ciuser     = var.vm_user

  # Provisioning
  agent = 1

  lifecycle {
    ignore_changes = [
      network,
      disk,
    ]
  }

  tags = "control-plane,k3s,${var.environment}"
}

#-----------------------------------
# k3s Worker Nodes (Base Pool)
#-----------------------------------

resource "proxmox_vm_qemu" "k3s_worker" {
  count = var.worker_min_count

  name        = "${local.cluster_name}-worker-${count.index + 1}"
  target_node = var.proxmox_nodes[count.index % length(var.proxmox_nodes)]
  desc        = "k3s Worker - ${local.cluster_name} (ASG: base)"

  clone      = local.cloudinit_template_name
  full_clone = true
  vmid       = 110 + count.index

  # Hardware
  cores   = var.worker_cpu
  sockets = 1
  cpu     = "host"
  memory  = var.worker_memory

  # Disk
  disk {
    type    = "scsi"
    storage = var.storage_pool
    size    = var.worker_disk_size
    format  = "raw"
    iothread = 1
    discard = "on"
    ssd     = 1
  }

  # Network
  network {
    model  = "virtio"
    bridge = var.create_isolated_network ? "vmbr${var.vpc_bridge_id}" : "vmbr0"
    tag    = var.vlan_id
  }

  # Cloud-init
  os_type    = "cloud-init"
  ipconfig0  = "ip=${cidrhost(var.vpc_cidr, local.worker_base_ip_offset + count.index)}/24,gw=${cidrhost(var.vpc_cidr, 1)}"
  nameserver = var.dns_servers
  searchdomain = local.domain
  sshkeys    = local.ssh_keys
  ciuser     = var.vm_user

  # Provisioning
  agent = 1

  lifecycle {
    ignore_changes = [
      network,
      disk,
    ]
  }

  tags = "worker,k3s,${var.environment},asg-base"
}

#-----------------------------------
# Autoscaling Worker Pool (Dynamic)
#-----------------------------------

# Note: Proxmox doesn't have native autoscaling like AWS ASG
# This creates a pool of VMs that can be started/stopped by monitoring scripts
# See monitoring/autoscaler.py for the scaling logic

resource "proxmox_vm_qemu" "k3s_worker_asg" {
  count = var.worker_max_count - var.worker_min_count

  name        = "${local.cluster_name}-worker-asg-${count.index + 1}"
  target_node = var.proxmox_nodes[count.index % length(var.proxmox_nodes)]
  desc        = "k3s Worker - ${local.cluster_name} (ASG: dynamic) - Load-based scaling"

  clone      = local.cloudinit_template_name
  full_clone = true
  vmid       = 150 + count.index

  # Hardware (same as base workers)
  cores   = var.worker_cpu
  sockets = 1
  cpu     = "host"
  memory  = var.worker_memory

  # Disk
  disk {
    type    = "scsi"
    storage = var.storage_pool
    size    = var.worker_disk_size
    format  = "raw"
    iothread = 1
    discard = "on"
    ssd     = 1
  }

  # Network
  network {
    model  = "virtio"
    bridge = var.create_isolated_network ? "vmbr${var.vpc_bridge_id}" : "vmbr0"
    tag    = var.vlan_id
  }

  # Cloud-init
  os_type    = "cloud-init"
  ipconfig0  = "ip=${cidrhost(var.vpc_cidr, local.worker_base_ip_offset + var.worker_min_count + count.index)}/24,gw=${cidrhost(var.vpc_cidr, 1)}"
  nameserver = var.dns_servers
  searchdomain = local.domain
  sshkeys    = local.ssh_keys
  ciuser     = var.vm_user

  # Provisioning
  agent = 1

  # Start in stopped state (will be started by autoscaler)
  automatic_reboot = false
  oncreate         = false

  lifecycle {
    ignore_changes = [
      network,
      disk,
    ]
  }

  tags = "worker,k3s,${var.environment},asg-dynamic,autoscale"
}

#-----------------------------------
# Bastion/Jump Host
#-----------------------------------

resource "proxmox_vm_qemu" "bastion" {
  count = var.create_bastion ? 1 : 0

  name        = "${local.cluster_name}-bastion"
  target_node = var.proxmox_nodes[0]
  desc        = "Bastion host for ${local.cluster_name}"

  clone      = local.cloudinit_template_name
  full_clone = true
  vmid       = 190

  # Hardware
  cores   = 2
  sockets = 1
  cpu     = "host"
  memory  = 4096

  # Disk
  disk {
    type    = "scsi"
    storage = var.storage_pool
    size    = "30G"
    format  = "raw"
    iothread = 1
    discard = "on"
    ssd     = 1
  }

  # Network (dual-homed: external + internal)
  network {
    model  = "virtio"
    bridge = "vmbr0"  # External network
  }

  network {
    model  = "virtio"
    bridge = var.create_isolated_network ? "vmbr${var.vpc_bridge_id}" : "vmbr0"
    tag    = var.vlan_id
  }

  # Cloud-init
  os_type    = "cloud-init"
  ipconfig0  = "ip=dhcp"
  ipconfig1  = "ip=${cidrhost(var.vpc_cidr, 254)}/24"
  nameserver = var.dns_servers
  searchdomain = local.domain
  sshkeys    = local.ssh_keys
  ciuser     = var.vm_user

  # Provisioning
  agent = 1

  tags = "bastion,${var.environment}"
}
