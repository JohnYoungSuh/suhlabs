terraform {
  required_providers {
    proxmox = {
      source = "telmate/proxmox"
      version = "3.0.1-rc1"
    }
  }
}

provider "proxmox" {
  pm_api_url = var.proxmox_api_url
  pm_user = var.proxmox_user
  pm_password = var.proxmox_password
  pm_tls_insecure = true
}

resource "proxmox_vm_qemu" "k3s_control_plane" {
  count       = 3
  name        = "k3s-master-${count.index}"
  target_node = "pve"
  clone       = "ubuntu-2204-template"
  os_type     = "cloud-init"
  cores       = 4
  sockets     = 1
  cpu         = "host"
  memory      = 8192
  scsihw      = "virtio-scsi-pci"
  bootdisk    = "scsi0"

  disk {
    slot = 0
    size = "50G"
    type = "scsi"
    storage = "local-lvm"
    iothread = 1
  }

  network {
    model = "virtio"
    bridge = "vmbr0"
  }

  lifecycle {
    ignore_changes = [network, disk]
  }

  cicustom = "user=local:snippets/cloud-init-master.yaml"
}

resource "proxmox_vm_qemu" "k3s_worker" {
  count       = 3
  name        = "k3s-worker-${count.index}"
  target_node = "pve"
  clone       = "ubuntu-2204-template"
  os_type     = "cloud-init"
  cores       = 8
  sockets     = 1
  cpu         = "host"
  memory      = 16384
  scsihw      = "virtio-scsi-pci"
  bootdisk    = "scsi0"

  disk {
    slot = 0
    size = "200G" # Larger disk for Longhorn storage
    type = "scsi"
    storage = "local-lvm"
    iothread = 1
  }

  network {
    model = "virtio"
    bridge = "vmbr0"
  }

  cicustom = "user=local:snippets/cloud-init-worker.yaml"
}
