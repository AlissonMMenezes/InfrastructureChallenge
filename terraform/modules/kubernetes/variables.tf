variable "cluster_name" {
  description = "Kubernetes cluster name prefix"
  type        = string
}

variable "location" {
  description = "Hetzner location for servers and load balancer"
  type        = string
  default     = "fsn1"
}

variable "network_zone" {
  description = "Hetzner network zone"
  type        = string
  default     = "eu-central"
}

variable "network_cidr" {
  description = "Private network CIDR containing jump and cluster subnets"
  type        = string
  default     = "10.60.0.0/16"
}

variable "private_network_gateway_ip" {
  description = "Hetzner Cloud virtual gateway for this network (first hop for private NIC). Default: first host in network_cidr (e.g. 10.50.0.1 for 10.50.0.0/16). Must match Hetzner docs; do not set to the NAT server IP."
  type        = string
  nullable    = true
  default     = null
}

variable "jump_subnet_cidr" {
  description = "Subnet for bastion / jump host and NAT gateway (e.g. 10.60.1.0/24)"
  type        = string
  default     = "10.60.1.0/24"
}

variable "cluster_subnet_cidr" {
  description = "Subnet for control-plane and workers only (e.g. 10.60.2.0/24)"
  type        = string
  default     = "10.60.2.0/24"
}

variable "jump_private_ip" {
  description = "Private IP of jump host on jump_subnet (hcloud_network_route 0.0.0.0/0 gateway + iptables SNAT target for cluster subnet)"
  type        = string
  default     = "10.60.1.10"
}

variable "jump_server_type" {
  description = "Hetzner server type for jump / NAT host"
  type        = string
  default     = "cx23"
}

variable "jump_public_ipv4_enabled" {
  description = "Jump host must have public IPv4 for admin SSH and Internet egress/NAT"
  type        = bool
  default     = true
}

variable "jump_public_ipv6_enabled" {
  description = "Attach public IPv6 to jump host"
  type        = bool
  default     = false
}

variable "image" {
  description = "Server image"
  type        = string
  default     = "ubuntu-24.04"
}

variable "master_server_type" {
  description = "Server type for control-plane node"
  type        = string
  default     = "cpx21"
}

variable "worker_server_type" {
  description = "Server type for worker nodes"
  type        = string
  default     = "cpx21"
}

variable "ssh_public_key" {
  description = "SSH public key content"
  type        = string

  validation {
    condition     = length(trimspace(var.ssh_public_key)) > 0
    error_message = "ssh_public_key must not be empty."
  }
}

variable "master_private_ip" {
  description = "Private IP for control-plane on cluster_subnet_cidr"
  type        = string
  default     = "10.60.2.10"
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2

  validation {
    condition     = var.worker_count >= 1
    error_message = "worker_count must be at least 1."
  }
}

variable "worker_private_ips" {
  description = "Optional private IPs on cluster_subnet_cidr; if empty, auto from cluster_subnet_cidr"
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.worker_private_ips) == 0 || length(var.worker_private_ips) == var.worker_count
    error_message = "worker_private_ips must be empty or have the same length as worker_count."
  }
}

variable "master_public_ipv4_enabled" {
  description = "Attach public IPv4 to master (disabled for private-only control-plane behind jump)"
  type        = bool
  default     = false
}

variable "master_public_ipv6_enabled" {
  description = "Attach public IPv6 to master"
  type        = bool
  default     = false
}

variable "workers_public_ipv4_enabled" {
  description = "Attach public IPv4 to workers"
  type        = bool
  default     = false
}

variable "workers_public_ipv6_enabled" {
  description = "Attach public IPv6 to workers"
  type        = bool
  default     = false
}

variable "extra_ssh_source_cidrs" {
  description = "Extra CIDRs allowed to SSH to cluster nodes (in addition to jump_subnet_cidr), e.g. corporate VPN"
  type        = list(string)
  default     = []
}

variable "allow_ssh_cidr" {
  description = "CIDR allowed to SSH to jump host and (with network_cidr) for kube API exposure"
  type        = string
  default     = "0.0.0.0/0"
}

variable "labels" {
  description = "Common labels for resources"
  type        = map(string)
  default     = {}
}

variable "lb_type" {
  description = "Hetzner load balancer type (used for the workers LB and as the default type for the optional Kubernetes API LB)"
  type        = string
  default     = "lb11"
}

variable "expose_kubernetes_api_via_load_balancer" {
  description = "Optional: when true, create a dedicated Hetzner load balancer targeting the control-plane only (master), forwarding to kube-apiserver on 6443. Default false (no public API LB). The workers load balancer is controlled separately by lb_services. Hetzner uses one target pool per LB, so API and worker NodePort services require two LBs."
  type        = bool
  default     = false
}

variable "kubernetes_api_lb_listen_port" {
  description = "Public listen port on the Kubernetes API load balancer (maps to apiserver 6443 on the control-plane)"
  type        = number
  default     = 443

  validation {
    condition     = var.kubernetes_api_lb_listen_port >= 1 && var.kubernetes_api_lb_listen_port <= 65535
    error_message = "kubernetes_api_lb_listen_port must be between 1 and 65535."
  }
}

variable "kubernetes_api_lb_type" {
  description = "Hetzner load balancer type for the optional API LB; null uses lb_type"
  type        = string
  nullable    = true
  default     = null
}

variable "lb_services" {
  description = "Services on the workers load balancer (NodePort / ingress, etc.). By default forwards public TCP 80→30080 and 443→30443 on workers (typical ingress NodePorts). Set to [] to skip the workers load balancer entirely."
  type = list(object({
    protocol              = string
    listen_port           = number
    destination_port      = number
    proxyprotocol         = bool
    health_check_protocol = string
    health_check_port     = number
    health_check_interval = number
    health_check_timeout  = number
    health_check_retries  = number
  }))
  default = [
    {
      protocol              = "tcp"
      listen_port           = 80
      destination_port      = 30080
      proxyprotocol         = false
      health_check_protocol = "tcp"
      health_check_port     = 30080
      health_check_interval = 10
      health_check_timeout  = 5
      health_check_retries  = 3
    },
    {
      protocol              = "tcp"
      listen_port           = 443
      destination_port      = 30443
      proxyprotocol         = false
      health_check_protocol = "tcp"
      health_check_port     = 30443
      health_check_interval = 10
      health_check_timeout  = 5
      health_check_retries  = 3
    }
  ]
}
