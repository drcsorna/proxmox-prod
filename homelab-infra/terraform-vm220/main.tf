terraform {
  required_version = ">= 1.8.0"
  
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.87.0"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = true
  
  ssh {
    agent = true
    username = "root"
  }
}

resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = var.proxmox_node

  file_name = "ubuntu-24.04-noble-amd64.img"
  url       = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}

resource "proxmox_virtual_environment_vm" "vm210" {
  name        = var.vm_name
  description = "Media Stack: Jellyfin, *arr apps, qBittorrent+VPN, NPM"
  tags        = ["terraform", "media", "docker"]
  
  node_name = var.proxmox_node
  vm_id     = var.vm_id

  agent {
    enabled = true
    trim    = true
    type    = "virtio"
  }

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 8192
  }

  boot_order = ["scsi0"]

  disk {
    datastore_id = "flash"
    file_id      = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
    interface    = "scsi0"
    size         = 64
    discard      = "on"
    ssd          = true
  }

  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    firewall = true
  }

  initialization {
    datastore_id = "flash"
    
    ip_config {
      ipv4 {
        address = "${var.vm_ip}/24"
        gateway = var.vm_gateway
      }
    }

    user_account {
      username = var.vm_user
      keys     = [var.ssh_public_key]
    }
  }

  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"
  bios          = "seabios"
}

resource "proxmox_virtual_environment_firewall_rules" "vm210_rules" {
  node_name = var.proxmox_node
  vm_id     = var.vm_id

  depends_on = [proxmox_virtual_environment_vm.vm210]

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "SSH"
    dport   = "22"
    proto   = "tcp"
    enabled = true
    log     = "nolog"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "NPM HTTP"
    dport   = "80"
    proto   = "tcp"
    enabled = true
    log     = "nolog"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "NPM Admin"
    dport   = "81"
    proto   = "tcp"
    enabled = true
    log     = "nolog"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "NPM HTTPS"
    dport   = "443"
    proto   = "tcp"
    enabled = true
    log     = "nolog"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Jellyseerr"
    dport   = "5055"
    proto   = "tcp"
    enabled = true
    log     = "nolog"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Bazarr"
    dport   = "6767"
    proto   = "tcp"
    enabled = true
    log     = "nolog"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "nzbget"
    dport   = "6789"
    proto   = "tcp"
    enabled = true
    log     = "nolog"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "qBittorrent torrent"
    dport   = "6881"
    proto   = "tcp"
    enabled = true
    log     = "nolog"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Radarr"
    dport   = "7878"
    proto   = "tcp"
    enabled = true
    log     = "nolog"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "qBittorrent WebUI"
    dport   = "8080"
    proto   = "tcp"
    enabled = true
    log     = "nolog"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Jellyfin"
    dport   = "8096"
    proto   = "tcp"
    enabled = true
    log     = "nolog"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Lidarr"
    dport   = "8686"
    proto   = "tcp"
    enabled = true
    log     = "nolog"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Sonarr"
    dport   = "8989"
    proto   = "tcp"
    enabled = true
    log     = "nolog"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Prowlarr"
    dport   = "9696"
    proto   = "tcp"
    enabled = true
    log     = "nolog"
  }
}

output "vm_info" {
  description = "VM 210 connection details"
  value = {
    vm_id   = proxmox_virtual_environment_vm.vm210.vm_id
    vm_ip   = var.vm_ip
    ssh_cmd = "ssh ${var.vm_user}@${var.vm_ip}"
  }
}