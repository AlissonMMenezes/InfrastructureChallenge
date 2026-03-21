variable "name" {
  description = "Prefix for firewall and SSH key naming (e.g. cluster name)"
  type        = string
}

variable "server_name" {
  description = "Hostname of the NAT gateway server"
  type        = string
}

variable "network_id" {
  description = "Hetzner private network id to attach"
  type        = string
}

variable "private_ip" {
  description = "Private IPv4 on the attached network"
  type        = string
}

variable "nat_source_cidr" {
  description = "Source CIDR to SNAT to the Internet (e.g. downstream private subnet)"
  type        = string
}

variable "allow_ssh_cidr" {
  description = "CIDR allowed to SSH to the NAT gateway"
  type        = string
  default     = "0.0.0.0/0"
}

variable "ssh_key_id" {
  description = "Hetzner SSH key id to attach to the NAT gateway server (create once in the parent stack, e.g. kubernetes module)"
  type        = string
}

variable "server_type" {
  description = "Hetzner server type"
  type        = string
  default     = "cx22"
}

variable "image" {
  description = "OS image"
  type        = string
  default     = "ubuntu-24.04"
}

variable "location" {
  description = "Hetzner location"
  type        = string
}

variable "public_ipv4_enabled" {
  description = "Attach public IPv4 (required for SNAT egress)"
  type        = bool
  default     = true
}

variable "public_ipv6_enabled" {
  description = "Attach public IPv6"
  type        = bool
  default     = false
}

variable "labels" {
  description = "Labels for firewall and server"
  type        = map(string)
  default     = {}
}
