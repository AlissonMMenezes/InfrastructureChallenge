variable "network_id" {
  description = "Target Hetzner private network id"
  type        = string
}

variable "ssh_key_id" {
  description = "Existing Hetzner Cloud SSH key id to attach to servers (create one key in the parent module and pass it to every compute module call to avoid uniqueness_error / duplicate names)"
  type        = string
}

variable "labels" {
  description = "Common labels applied to all servers"
  type        = map(string)
  default     = {}
}

variable "servers" {
  description = "Server definitions"
  type = list(object({
    name               = string
    server_type        = string
    image              = string
    location           = string
    private_ip         = string
    user_data          = string
    firewall_ids       = list(number)
    labels             = map(string)
    enable_public_ipv4 = bool
    enable_public_ipv6 = bool
  }))
}
