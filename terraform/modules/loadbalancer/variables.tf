variable "name" {
  description = "Load balancer name"
  type        = string
}

variable "load_balancer_type" {
  description = "Hetzner load balancer type"
  type        = string
  default     = "lb11"
}

variable "location" {
  description = "Hetzner location"
  type        = string
  default     = null
}

variable "network_zone" {
  description = "Hetzner network zone"
  type        = string
  default     = null
}

variable "algorithm_type" {
  description = "Balancing algorithm"
  type        = string
  default     = "round_robin"
}

variable "labels" {
  description = "Labels for load balancer resources"
  type        = map(string)
  default     = {}
}

variable "network_id" {
  description = "Private network id to attach"
  type        = string
}

variable "target_server_ids" {
  description = "Server ids to register as targets"
  type        = list(number)
  default     = []
}

variable "use_private_ip_targets" {
  description = "Use private IP for server targets"
  type        = bool
  default     = true
}

variable "services" {
  description = "Load balancer services"
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
  default = []
}
