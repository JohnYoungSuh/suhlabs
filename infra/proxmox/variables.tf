# Variables for Proxmox Infrastructure

#-----------------------------------
# Proxmox Connection
#-----------------------------------

variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
  default     = "https://proxmox.corp.example.com:8006/api2/json"
}

variable "proxmox_api_token_id" {
  description = "Proxmox API token ID"
  type        = string
  sensitive   = true
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification"
  type        = bool
  default     = true
}

variable "proxmox_nodes" {
  description = "List of Proxmox nodes for HA"
  type        = list(string)
  default     = ["proxmox-01", "proxmox-02", "proxmox-03"]
}

#-----------------------------------
# Environment
#-----------------------------------

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["production", "staging", "development"], var.environment)
    error_message = "Environment must be production, staging, or development"
  }
}

variable "domain" {
  description = "Domain name for the cluster"
  type        = string
  default     = "corp.example.com"
}

#-----------------------------------
# Network Configuration
#-----------------------------------

variable "vpc_cidr" {
  description = "VPC CIDR block for k3s cluster"
  type        = string
  default     = "10.100.0.0/24"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block"
  }
}

variable "create_isolated_network" {
  description = "Create isolated network bridge for VPC"
  type        = bool
  default     = true
}

variable "vpc_bridge_id" {
  description = "Bridge ID for VPC (e.g., vmbr10)"
  type        = number
  default     = 10
}

variable "vlan_id" {
  description = "VLAN ID for k3s cluster"
  type        = number
  default     = 100
}

variable "admin_cidr" {
  description = "Admin CIDR for SSH access"
  type        = string
  default     = "0.0.0.0/0"
}

variable "dns_servers" {
  description = "DNS servers"
  type        = string
  default     = "8.8.8.8 1.1.1.1"
}

#-----------------------------------
# VM Template
#-----------------------------------

variable "vm_template_name" {
  description = "Name of the VM template (created by Packer)"
  type        = string
  default     = "centos9-cloud"
}

variable "storage_pool" {
  description = "Proxmox storage pool"
  type        = string
  default     = "ceph-rbd"
}

variable "vm_user" {
  description = "Default VM user"
  type        = string
  default     = "cloud-user"
}

variable "ssh_public_keys" {
  description = "List of SSH public keys"
  type        = list(string)
  default     = []
}

#-----------------------------------
# Load Balancer
#-----------------------------------

variable "ha_lb_count" {
  description = "Number of HA load balancers (HAProxy + Keepalived)"
  type        = number
  default     = 2

  validation {
    condition     = var.ha_lb_count >= 2
    error_message = "At least 2 load balancers required for HA"
  }
}

#-----------------------------------
# Control Plane
#-----------------------------------

variable "control_plane_count" {
  description = "Number of control plane nodes"
  type        = number
  default     = 3

  validation {
    condition     = var.control_plane_count >= 3 && var.control_plane_count % 2 == 1
    error_message = "Control plane count must be odd (3, 5, 7) for HA quorum"
  }
}

variable "control_plane_cpu" {
  description = "CPU cores for control plane"
  type        = number
  default     = 4
}

variable "control_plane_memory" {
  description = "Memory (MB) for control plane"
  type        = number
  default     = 8192
}

variable "control_plane_disk_size" {
  description = "Disk size for control plane"
  type        = string
  default     = "50G"
}

#-----------------------------------
# Worker Nodes (Autoscaling)
#-----------------------------------

variable "worker_min_count" {
  description = "Minimum number of worker nodes (always running)"
  type        = number
  default     = 3
}

variable "worker_max_count" {
  description = "Maximum number of worker nodes (includes ASG pool)"
  type        = number
  default     = 10

  validation {
    condition     = var.worker_max_count >= var.worker_min_count
    error_message = "worker_max_count must be >= worker_min_count"
  }
}

variable "worker_cpu" {
  description = "CPU cores for worker nodes"
  type        = number
  default     = 8
}

variable "worker_memory" {
  description = "Memory (MB) for worker nodes"
  type        = number
  default     = 16384
}

variable "worker_disk_size" {
  description = "Disk size for worker nodes"
  type        = string
  default     = "100G"
}

#-----------------------------------
# Autoscaling Configuration
#-----------------------------------

variable "autoscaling_enabled" {
  description = "Enable autoscaling for worker nodes"
  type        = bool
  default     = true
}

variable "scale_up_cpu_threshold" {
  description = "CPU threshold (%) to trigger scale up"
  type        = number
  default     = 70

  validation {
    condition     = var.scale_up_cpu_threshold > 0 && var.scale_up_cpu_threshold <= 100
    error_message = "CPU threshold must be between 1 and 100"
  }
}

variable "scale_up_memory_threshold" {
  description = "Memory threshold (%) to trigger scale up"
  type        = number
  default     = 80

  validation {
    condition     = var.scale_up_memory_threshold > 0 && var.scale_up_memory_threshold <= 100
    error_message = "Memory threshold must be between 1 and 100"
  }
}

variable "scale_down_cpu_threshold" {
  description = "CPU threshold (%) to trigger scale down"
  type        = number
  default     = 30

  validation {
    condition     = var.scale_down_cpu_threshold > 0 && var.scale_down_cpu_threshold <= 100
    error_message = "CPU threshold must be between 1 and 100"
  }
}

variable "scale_down_memory_threshold" {
  description = "Memory threshold (%) to trigger scale down"
  type        = number
  default     = 40

  validation {
    condition     = var.scale_down_memory_threshold > 0 && var.scale_down_memory_threshold <= 100
    error_message = "Memory threshold must be between 1 and 100"
  }
}

variable "scale_cooldown_seconds" {
  description = "Cooldown period between scaling actions"
  type        = number
  default     = 300
}

#-----------------------------------
# Bastion Host
#-----------------------------------

variable "create_bastion" {
  description = "Create bastion/jump host"
  type        = bool
  default     = true
}
