terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.50.0"
    }
  }
}

locals {
  servers_by_name = { for s in var.servers : s.name => s }
  common_labels = merge(var.labels, {
    managed_by = "terraform"
    module     = "compute"
  })
}

resource "hcloud_server" "this" {
  for_each = local.servers_by_name

  name         = each.value.name
  server_type  = each.value.server_type
  image        = each.value.image
  location     = each.value.location
  user_data    = each.value.user_data
  firewall_ids = each.value.firewall_ids

  labels = merge(local.common_labels, each.value.labels)

  ssh_keys = [var.ssh_key_id]

  network {
    network_id = var.network_id
    ip         = each.value.private_ip
  }

  public_net {
    ipv4_enabled = each.value.enable_public_ipv4
    ipv6_enabled = each.value.enable_public_ipv6
  }
}
