terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.50.0"
    }
  }
}

locals {
  common_labels = merge(var.labels, {
    role       = "nat-gateway"
    managed_by = "terraform"
  })

  # Sole source of NAT bootstrap: rendered cloud-config passed to Hetzner as user_data (no Ansible).
  user_data = templatefile("${path.module}/cloud-init/nat-gateway.yaml.tpl", {
    nat_source_cidr = var.nat_source_cidr
  })

  servers = [
    {
      name               = var.server_name
      server_type        = var.server_type
      image              = var.image
      location           = var.location
      private_ip         = var.private_ip
      user_data          = local.user_data
      firewall_ids       = [hcloud_firewall.this.id]
      labels             = { role = "nat-gateway" }
      enable_public_ipv4 = var.public_ipv4_enabled
      enable_public_ipv6 = var.public_ipv6_enabled
    }
  ]
}

resource "hcloud_firewall" "this" {
  name = "${var.name}-nat-fw"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = [var.allow_ssh_cidr]
  }

  rule {
    direction       = "out"
    protocol        = "tcp"
    port            = "1-65535"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction       = "out"
    protocol        = "udp"
    port            = "1-65535"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }

  # ICMP to/from Internet (ping host, SNAT replies, PTB).
  rule {
    direction       = "out"
    protocol        = "icmp"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "icmp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  dynamic "rule" {
    for_each = toset(["esp", "gre"])
    content {
      direction       = "out"
      protocol        = rule.value
      destination_ips = ["0.0.0.0/0"]
    }
  }

  dynamic "rule" {
    for_each = toset(["tcp", "udp"])
    content {
      direction  = "in"
      protocol   = rule.value
      port       = "1-65535"
      source_ips = [var.nat_source_cidr]
    }
  }

  labels = local.common_labels
}

module "compute" {
  source = "../compute"

  network_id = var.network_id
  ssh_key_id = var.ssh_key_id
  servers    = local.servers
  labels     = local.common_labels
  depends_on = [hcloud_firewall.this]
}
