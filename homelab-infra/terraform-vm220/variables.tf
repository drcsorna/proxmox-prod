variable "proxmox_endpoint" {
  type = string
}

variable "proxmox_api_token" {
  type      = string
  sensitive = true
}

variable "proxmox_node" {
  type    = string
  default = "bubver"
}

variable "vm_id" {
  type    = number
  default = 210
}

variable "vm_name" {
  type    = string
  default = "servarr"
}

variable "vm_ip" {
  type = string
}

variable "vm_gateway" {
  type    = string
  default = "192.168.10.1"
}

variable "vm_user" {
  type    = string
  default = "drcsorna"
}

variable "ssh_public_key" {
  type = string
}