terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.50.0"
    }
  }
}

resource "hcloud_network" "this" {
  name              = var.name
  ip_range          = var.ip_range
  delete_protection = var.delete_protection
  labels            = var.labels
}

resource "hcloud_network_subnet" "this" {
  for_each = var.subnets

  network_id   = hcloud_network.this.id
  type         = var.subnet_type
  network_zone = var.network_zone
  ip_range     = each.value
}
