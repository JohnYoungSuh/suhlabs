# Outputs for Proxmox Infrastructure

#-----------------------------------
# Network Outputs
#-----------------------------------

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = var.vpc_cidr
}

output "lb_vip" {
  description = "Load balancer virtual IP"
  value       = cidrhost(var.vpc_cidr, 5)
}

output "k3s_api_endpoint" {
  description = "k3s API endpoint"
  value       = "https://${cidrhost(var.vpc_cidr, 5)}:6443"
}

#-----------------------------------
# Control Plane Outputs
#-----------------------------------

output "control_plane_ips" {
  description = "Control plane node IPs"
  value       = [for i in range(var.control_plane_count) : cidrhost(var.vpc_cidr, 10 + i)]
}

output "control_plane_vmids" {
  description = "Control plane VM IDs"
  value       = proxmox_vm_qemu.k3s_control_plane[*].vmid
}

output "control_plane_hostnames" {
  description = "Control plane hostnames"
  value       = proxmox_vm_qemu.k3s_control_plane[*].name
}

#-----------------------------------
# Worker Node Outputs
#-----------------------------------

output "worker_base_ips" {
  description = "Base worker node IPs"
  value = [
    for i in range(var.worker_min_count) :
    cidrhost(var.vpc_cidr, 20 + i)
  ]
}

output "worker_asg_ips" {
  description = "ASG worker node IPs"
  value = [
    for i in range(var.worker_max_count - var.worker_min_count) :
    cidrhost(var.vpc_cidr, 20 + var.worker_min_count + i)
  ]
}

output "worker_base_vmids" {
  description = "Base worker VM IDs"
  value       = proxmox_vm_qemu.k3s_worker[*].vmid
}

output "worker_asg_vmids" {
  description = "ASG worker VM IDs"
  value       = proxmox_vm_qemu.k3s_worker_asg[*].vmid
}

output "worker_count" {
  description = "Current worker node count"
  value = {
    min     = var.worker_min_count
    max     = var.worker_max_count
    current = var.worker_min_count
  }
}

#-----------------------------------
# Load Balancer Outputs
#-----------------------------------

output "load_balancer_ips" {
  description = "Load balancer IPs"
  value       = proxmox_vm_qemu.k3s_lb[*].default_ipv4_address
}

output "load_balancer_vmids" {
  description = "Load balancer VM IDs"
  value       = proxmox_vm_qemu.k3s_lb[*].vmid
}

#-----------------------------------
# Bastion Outputs
#-----------------------------------

output "bastion_ip" {
  description = "Bastion host external IP"
  value       = var.create_bastion ? proxmox_vm_qemu.bastion[0].default_ipv4_address : null
}

output "bastion_vmid" {
  description = "Bastion host VM ID"
  value       = var.create_bastion ? proxmox_vm_qemu.bastion[0].vmid : null
}

#-----------------------------------
# Autoscaling Configuration
#-----------------------------------

output "autoscaling_config" {
  description = "Autoscaling configuration"
  value = {
    enabled               = var.autoscaling_enabled
    cpu_scale_up          = var.scale_up_cpu_threshold
    cpu_scale_down        = var.scale_down_cpu_threshold
    memory_scale_up       = var.scale_up_memory_threshold
    memory_scale_down     = var.scale_down_memory_threshold
    cooldown_seconds      = var.scale_cooldown_seconds
    asg_vmids             = proxmox_vm_qemu.k3s_worker_asg[*].vmid
  }
  sensitive = false
}

#-----------------------------------
# Ansible Inventory
#-----------------------------------

output "ansible_inventory" {
  description = "Ansible inventory in YAML format"
  value = yamlencode({
    all = {
      vars = {
        ansible_user                 = var.vm_user
        ansible_ssh_common_args      = "-o StrictHostKeyChecking=no"
        k3s_version                  = "v1.28.5+k3s1"
        k3s_token                    = "{{ vault_k3s_token }}"
        cluster_cidr                 = "10.42.0.0/16"
        service_cidr                 = "10.43.0.0/16"
      }
      children = {
        k3s_cluster = {
          children = {
            control_plane = {
              hosts = {
                for i, ip in [for i in range(var.control_plane_count) : cidrhost(var.vpc_cidr, 10 + i)] :
                "k3s-cp-${i + 1}" => {
                  ansible_host = ip
                  node_ip      = ip
                  node_name    = "k3s-cp-${i + 1}"
                }
              }
            }
            workers = {
              hosts = merge(
                {
                  for i, ip in [for i in range(var.worker_min_count) : cidrhost(var.vpc_cidr, 20 + i)] :
                  "k3s-worker-${i + 1}" => {
                    ansible_host = ip
                    node_ip      = ip
                    node_name    = "k3s-worker-${i + 1}"
                    asg_group    = "base"
                  }
                },
                {
                  for i, ip in [for i in range(var.worker_max_count - var.worker_min_count) : cidrhost(var.vpc_cidr, 20 + var.worker_min_count + i)] :
                  "k3s-worker-asg-${i + 1}" => {
                    ansible_host = ip
                    node_ip      = ip
                    node_name    = "k3s-worker-asg-${i + 1}"
                    asg_group    = "dynamic"
                  }
                }
              )
            }
          }
        }
        loadbalancers = {
          hosts = {
            for i in range(var.ha_lb_count) :
            "lb-${i + 1}" => {
              ansible_host = cidrhost(var.vpc_cidr, 5 + i)
              vip          = cidrhost(var.vpc_cidr, 5)
              priority     = 100 + (i * 10)
            }
          }
        }
      }
    }
  })
}

#-----------------------------------
# Summary
#-----------------------------------

output "cluster_summary" {
  description = "Cluster deployment summary"
  value = {
    cluster_name      = "aiops-k3s"
    environment       = var.environment
    control_plane     = var.control_plane_count
    workers_min       = var.worker_min_count
    workers_max       = var.worker_max_count
    load_balancers    = var.ha_lb_count
    api_endpoint      = "https://${cidrhost(var.vpc_cidr, 5)}:6443"
    vpc_cidr          = var.vpc_cidr
    autoscaling       = var.autoscaling_enabled
  }
}
