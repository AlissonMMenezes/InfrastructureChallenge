variable "name" {
  description = "Hetzner network name"
  type        = string
}

variable "ip_range" {
  description = "Hetzner network CIDR (must contain all subnets)"
  type        = string
}

variable "subnets" {
  description = "Named subnets (e.g. jump = 10.50.1.0/24, cluster = 10.50.2.0/24). CIDRs must be non-overlapping and inside ip_range."
  type        = map(string)
}

variable "subnet_type" {
  description = "Subnet type"
  type        = string
  default     = "cloud"
}

variable "network_zone" {
  description = "Hetzner network zone"
  type        = string
  default     = "eu-central"
}

variable "delete_protection" {
  description = "Enable delete protection on network"
  type        = bool
  default     = false
}

variable "labels" {
  description = "Labels attached to the network"
  type        = map(string)
  default     = {}
}
