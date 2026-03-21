variable "ssh_public_key" {
  description = "SSH public key for Hetzner nodes"
  type        = string
}

variable "master_server_type" {
  description = "Hetzner server type for Kubernetes master node"
  type        = string
  default     = "cx23"
}

variable "worker_server_type" {
  description = "Hetzner server type for Kubernetes worker nodes"
  type        = string
  default     = "cx23"
}
