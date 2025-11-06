# Packer template for CentOS Stream 9 with cloud-init
# Creates Proxmox VM template optimized for k3s and container workloads

packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.8"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

# Variables
variable "proxmox_url" {
  type    = string
  default = "${env("PM_API_URL")}"
}

variable "proxmox_token_id" {
  type    = string
  default = "${env("PM_API_TOKEN_ID")}"
}

variable "proxmox_token_secret" {
  type      = string
  sensitive = true
  default   = "${env("PM_API_TOKEN_SECRET")}"
}

variable "proxmox_node" {
  type    = string
  default = "proxmox-01"
}

variable "proxmox_storage_pool" {
  type    = string
  default = "ceph-rbd"
}

variable "iso_storage_pool" {
  type    = string
  default = "local"
}

variable "template_name" {
  type    = string
  default = "centos9-cloud"
}

variable "template_description" {
  type    = string
  default = "CentOS Stream 9 with cloud-init, Docker, k3s-ready"
}

variable "centos_iso_url" {
  type    = string
  default = "https://mirrors.centos.org/mirrorlist?path=/9-stream/BaseOS/x86_64/iso/CentOS-Stream-9-latest-x86_64-dvd1.iso&redirect=1&protocol=https"
}

variable "centos_iso_checksum" {
  type    = string
  default = "file:https://mirrors.centos.org/mirrorlist?path=/9-stream/BaseOS/x86_64/iso/CentOS-Stream-9-latest-x86_64-dvd1.iso.SHA256SUM&redirect=1&protocol=https"
}

variable "vm_cpu_cores" {
  type    = number
  default = 2
}

variable "vm_memory" {
  type    = number
  default = 4096
}

variable "vm_disk_size" {
  type    = string
  default = "50G"
}

variable "ssh_username" {
  type    = string
  default = "cloud-user"
}

variable "ssh_password" {
  type      = string
  sensitive = true
  default   = "packer"
}

# Source definition
source "proxmox-iso" "centos9" {
  # Proxmox connection
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_token_id
  token                    = var.proxmox_token_secret
  insecure_skip_tls_verify = true
  node                     = var.proxmox_node

  # VM template settings
  template_name        = var.template_name
  template_description = var.template_description

  # ISO settings
  iso_url          = var.centos_iso_url
  iso_checksum     = var.centos_iso_checksum
  iso_storage_pool = var.iso_storage_pool
  unmount_iso      = true

  # VM hardware
  cores   = var.vm_cpu_cores
  memory  = var.vm_memory
  sockets = 1
  cpu_type = "host"

  # Disk configuration
  scsi_controller = "virtio-scsi-single"
  disks {
    disk_size         = var.vm_disk_size
    storage_pool      = var.proxmox_storage_pool
    type              = "scsi"
    format            = "raw"
    io_thread         = true
    discard           = true
    ssd               = true
  }

  # Network configuration
  network_adapters {
    bridge   = "vmbr0"
    model    = "virtio"
    firewall = false
  }

  # Cloud-init
  cloud_init              = true
  cloud_init_storage_pool = var.proxmox_storage_pool

  # Boot configuration
  boot_wait = "10s"
  boot_command = [
    "<tab> text inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/centos9-ks.cfg<enter><wait>"
  ]

  # HTTP server for kickstart
  http_directory = "packer/http"

  # SSH configuration
  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = "30m"

  # Additional settings
  qemu_agent        = true
  vm_name           = "packer-centos9-${formatdate("YYYYMMDD-hhmm", timestamp())}"
  os                = "l26"
  bios              = "ovmf"
  efi_config {
    efi_storage_pool = var.proxmox_storage_pool
    efi_type         = "4m"
  }
}

# Build
build {
  sources = ["source.proxmox-iso.centos9"]

  # Wait for cloud-init
  provisioner "shell" {
    inline = [
      "sudo cloud-init status --wait || true"
    ]
  }

  # Update system
  provisioner "shell" {
    inline = [
      "sudo dnf update -y",
      "sudo dnf install -y epel-release",
      "sudo dnf config-manager --set-enabled crb"
    ]
  }

  # Install essential packages
  provisioner "shell" {
    inline = [
      "sudo dnf install -y cloud-init cloud-utils-growpart",
      "sudo dnf install -y qemu-guest-agent",
      "sudo dnf install -y vim curl wget git htop net-tools bind-utils",
      "sudo dnf install -y python3 python3-pip",
      "sudo dnf install -y chrony",
      "sudo systemctl enable chronyd",
      "sudo systemctl start chronyd"
    ]
  }

  # Install container runtime (containerd)
  provisioner "shell" {
    inline = [
      "sudo dnf install -y yum-utils device-mapper-persistent-data lvm2",
      "sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo",
      "sudo dnf install -y containerd.io",
      "sudo mkdir -p /etc/containerd",
      "sudo containerd config default | sudo tee /etc/containerd/config.toml",
      "sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml",
      "sudo systemctl enable containerd",
      "sudo systemctl start containerd"
    ]
  }

  # Kernel modules and sysctl for Kubernetes
  provisioner "shell" {
    inline = [
      "sudo modprobe overlay",
      "sudo modprobe br_netfilter",
      "cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf",
      "overlay",
      "br_netfilter",
      "EOF",
      "",
      "cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf",
      "net.bridge.bridge-nf-call-iptables  = 1",
      "net.bridge.bridge-nf-call-ip6tables = 1",
      "net.ipv4.ip_forward                 = 1",
      "EOF",
      "",
      "sudo sysctl --system"
    ]
  }

  # Disable swap (required for k3s)
  provisioner "shell" {
    inline = [
      "sudo swapoff -a",
      "sudo sed -i '/ swap / s/^/#/' /etc/fstab"
    ]
  }

  # Configure cloud-init
  provisioner "shell" {
    inline = [
      "sudo systemctl enable cloud-init-local.service",
      "sudo systemctl enable cloud-init.service",
      "sudo systemctl enable cloud-config.service",
      "sudo systemctl enable cloud-final.service"
    ]
  }

  # Install monitoring tools
  provisioner "shell" {
    inline = [
      "sudo dnf install -y sysstat iotop iftop",
      "sudo systemctl enable sysstat"
    ]
  }

  # Security hardening
  provisioner "shell" {
    inline = [
      "sudo dnf install -y firewalld fail2ban",
      "sudo systemctl enable firewalld",
      "sudo systemctl enable fail2ban",
      "sudo firewall-cmd --permanent --add-service=ssh",
      "sudo firewall-cmd --reload"
    ]
  }

  # Cleanup
  provisioner "shell" {
    inline = [
      "sudo cloud-init clean --logs --seed",
      "sudo rm -rf /var/lib/cloud/instances",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo rm -f /var/lib/systemd/random-seed",
      "sudo dnf clean all",
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/tmp/*",
      "history -c"
    ]
  }

  # Generalize for template
  provisioner "shell" {
    inline = [
      "sudo sync"
    ]
  }
}
