terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.50.0"
    }
  }
}

resource "hcloud_load_balancer" "this" {
  name               = var.name
  load_balancer_type = var.load_balancer_type
  location           = var.location
  network_zone       = var.network_zone
  algorithm {
    type = var.algorithm_type
  }
  labels = var.labels
}

resource "hcloud_load_balancer_network" "this" {
  load_balancer_id = hcloud_load_balancer.this.id
  network_id       = var.network_id
}

resource "hcloud_load_balancer_target" "servers" {
  for_each = {
    for idx, id in var.target_server_ids : tostring(idx) => id
  }

  type             = "server"
  load_balancer_id = hcloud_load_balancer.this.id
  server_id        = each.value
  use_private_ip   = var.use_private_ip_targets
}

resource "hcloud_load_balancer_service" "this" {
  for_each = {
    for svc in var.services : "${svc.protocol}-${svc.listen_port}" => svc
  }

  load_balancer_id = hcloud_load_balancer.this.id
  protocol         = each.value.protocol
  listen_port      = each.value.listen_port
  destination_port = each.value.destination_port
  proxyprotocol    = each.value.proxyprotocol

  health_check {
    protocol = each.value.health_check_protocol
    port     = each.value.health_check_port
    interval = each.value.health_check_interval
    timeout  = each.value.health_check_timeout
    retries  = each.value.health_check_retries
  }
}
