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
  insecure  = true  # Homelab standard: Proxmox uses self-signed cert for internal API
  
  ssh {
    agent = true
    username = "root"
  }
}

# Download Ubuntu 24.04 cloud image
resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = var.proxmox_node

  file_name = "ubuntu-24.04-noble-amd64.img"
  url       = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}

# VM 110 - Flow Development & Productivity Stack
resource "proxmox_virtual_environment_vm" "vm110" {
  name        = var.vm_name
  description = "Flow Dev Sandbox: NPM, code-server, Paperless, Uptime Kuma, Tandoor, Homepage"
  tags        = ["terraform", "development", "productivity"]
  
  node_name = var.proxmox_node
  vm_id     = var.vm_id

  # Enable QEMU guest agent (industry best practice)
  agent {
    enabled = true
    trim    = true
    type    = "virtio"
  }

  cpu {
    cores = 4
    type  = "host"  # Pass through host CPU features (important for AVX instructions)
  }

  memory {
    dedicated = 12288  # 12GB RAM (sufficient for Paperless OCR + multiple services)
  }

  # Boot from cloud-init disk
  boot_order = ["scsi0"]

  # Primary disk
  disk {
    datastore_id = "flash"
    file_id      = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
    interface    = "scsi0"
    size         = 64
    discard      = "on"
    ssd          = true
  }

  # Network with firewall enabled
  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    firewall = true  # Enable firewall on interface level
  }

  # Cloud-init configuration
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

  # Machine configuration
  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"
  bios          = "seabios"
}

# Firewall Rules for VM 110
resource "proxmox_virtual_environment_firewall_rules" "vm110_rules" {
  node_name = var.proxmox_node
  vm_id     = var.vm_id

  depends_on = [proxmox_virtual_environment_vm.vm110]

  # SSH access
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "SSH - Remote management"
    dport   = "22"
    proto   = "tcp"
    enabled = true
    log     = "nolog"
  }

  # HTTP/HTTPS - NPM reverse proxy
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "HTTP - NPM reverse proxy"
    dport   = "80"
    proto   = "tcp"
    enabled = true
    log     = "nolog"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "HTTPS - NPM reverse proxy"
    dport   = "443"
    proto   = "tcp"
    enabled = true
    log     = "nolog"
  }

  # NPM Admin UI
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "NPM Admin UI"
    dport   = "81"
    proto   = "tcp"
    enabled = true
    log     = "nolog"
  }

  # code-server
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "code-server (VS Code in browser)"
    dport   = "8443"
    proto   = "tcp"
    enabled = true
    log     = "nolog"
  }

  # Paperless-ngx
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Paperless-ngx Web UI"
    dport   = "8000"
    proto   = "tcp"
    enabled = true
    log     = "nolog"
  }

  # Uptime Kuma
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Uptime Kuma monitoring"
    dport   = "3001"
    proto   = "tcp"
    enabled = true
    log     = "nolog"
  }

  # Tandoor Recipes
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Tandoor Recipes"
    dport   = "8080"
    proto   = "tcp"
    enabled = true
    log     = "nolog"
  }

  # Homepage Dashboard
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Homepage dashboard"
    dport   = "3000"
    proto   = "tcp"
    enabled = true
    log     = "nolog"
  }
}

# Output VM information
output "vm_info" {
  description = "VM 110 connection details"
  value = {
    vm_id   = proxmox_virtual_environment_vm.vm110.vm_id
    vm_ip   = var.vm_ip
    ssh_cmd = "ssh ${var.vm_user}@${var.vm_ip}"
  }
}
