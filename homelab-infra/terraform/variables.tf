variable "proxmox_endpoint" {
  description = "Proxmox API endpoint"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token (format: user@realm!tokenid=secret)"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
  default     = "bubver"
}

variable "vm_id" {
  description = "VM ID for the new VM"
  type        = number
  default     = 110
}

variable "vm_name" {
  description = "Name for the VM"
  type        = string
  default     = "flow-dev"
}

variable "vm_ip" {
  description = "Static IP address for the VM"
  type        = string
}

variable "vm_gateway" {
  description = "Network gateway for the VM"
  type        = string
  default     = "192.168.10.1"
}

variable "vm_user" {
  description = "Username for the VM"
  type        = string
  default     = "drcsorna"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}
