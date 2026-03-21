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
    cluster    = var.cluster_name
    managed_by = "terraform"
    workload   = "kubernetes"
  })

  jump_server_name = "${var.cluster_name}-jump-1"

  # Hetzner Cloud Networks are L3: nodes must default-route to the platform gateway (e.g. x.x.0.1),
  # and the network route 0.0.0.0/0 → NAT private IP sends Internet traffic to the jump host.
  hetzner_private_network_gateway_ip = coalesce(var.private_network_gateway_ip, cidrhost(var.network_cidr, 1))

  route_via_jump_user_data = templatefile("${path.module}/cloud-init/nat-worker-route.yaml.tpl", {
    private_network_gateway_ip = local.hetzner_private_network_gateway_ip
    nat_gateway_private_ip     = var.jump_private_ip
  })

  master_user_data = var.master_public_ipv4_enabled ? "" : local.route_via_jump_user_data

  worker_user_data = var.workers_public_ipv4_enabled ? "" : local.route_via_jump_user_data

  effective_worker_private_ips = length(var.worker_private_ips) > 0 ? var.worker_private_ips : [
    for i in range(var.worker_count) : cidrhost(var.cluster_subnet_cidr, 11 + i)
  ]

  ssh_sources_cluster = concat([var.jump_subnet_cidr], var.extra_ssh_source_cidrs)

  worker_servers = [
    for idx in range(var.worker_count) : {
      name               = "${var.cluster_name}-worker-${idx + 1}"
      server_type        = var.worker_server_type
      image              = var.image
      location           = var.location
      private_ip         = local.effective_worker_private_ips[idx]
      user_data          = local.worker_user_data
      firewall_ids       = [hcloud_firewall.cluster.id]
      labels             = { role = "worker" }
      enable_public_ipv4 = var.workers_public_ipv4_enabled
      enable_public_ipv6 = var.workers_public_ipv6_enabled
    }
  ]

  master_server = {
    name               = "${var.cluster_name}-master-1"
    server_type        = var.master_server_type
    image              = var.image
    location           = var.location
    private_ip         = var.master_private_ip
    user_data          = local.master_user_data
    firewall_ids       = [hcloud_firewall.cluster.id]
    labels             = { role = "master" }
    enable_public_ipv4 = var.master_public_ipv4_enabled
    enable_public_ipv6 = var.master_public_ipv6_enabled
  }

  servers = concat([local.master_server], local.worker_servers)

  worker_target_ids = [
    for worker in local.worker_servers : module.compute.server_ids[worker.name]
  ]
}

resource "terraform_data" "jump_architecture_precheck" {
  input = var.cluster_name

  lifecycle {
    precondition {
      condition     = var.jump_public_ipv4_enabled
      error_message = "Jump/bastion must have public IPv4 (jump_public_ipv4_enabled = true) for admin SSH and NAT egress for the cluster subnet."
    }
    precondition {
      condition     = !var.master_public_ipv4_enabled
      error_message = "Use a private-only control-plane: set master_public_ipv4_enabled = false. Access the API via the load balancer or from inside the network."
    }
  }
}

# One SSH key per cluster: avoids Hetzner API uniqueness_error when both NAT and node compute
# modules each tried to manage a separate hcloud_ssh_key with different names.
resource "hcloud_ssh_key" "cluster" {
  name       = "${var.cluster_name}-ssh"
  public_key = var.ssh_public_key
}

# Smooth upgrade: keep the same Hetzner key object when refactoring out of module.compute.
moved {
  from = module.compute.hcloud_ssh_key.this
  to   = hcloud_ssh_key.cluster
}

module "nat_gateway" {
  source = "../nat-gateway"

  name                = var.cluster_name
  server_name         = local.jump_server_name
  network_id          = module.network.network_id
  private_ip          = var.jump_private_ip
  nat_source_cidr     = var.cluster_subnet_cidr
  allow_ssh_cidr      = var.allow_ssh_cidr
  ssh_key_id          = hcloud_ssh_key.cluster.id
  server_type         = var.jump_server_type
  image               = var.image
  location            = var.location
  public_ipv4_enabled = var.jump_public_ipv4_enabled
  public_ipv6_enabled = var.jump_public_ipv6_enabled
  labels              = merge(local.common_labels, { tier = "bastion" })

  depends_on = [
    module.network,
    terraform_data.jump_architecture_precheck,
    hcloud_ssh_key.cluster,
  ]
}

# Required by Hetzner: SDN sends Internet-bound traffic from the private network to the NAT gateway.
# Without this, default via the virtual gateway alone will not reach the public Internet.
resource "hcloud_network_route" "internet_via_nat" {
  network_id  = module.network.network_id
  destination = "0.0.0.0/0"
  gateway     = var.jump_private_ip

  depends_on = [
    module.network,
    module.nat_gateway,
  ]
}

# Cluster nodes: no direct SSH from Internet; SSH only from jump subnet (+ optional extra CIDRs)
resource "hcloud_firewall" "cluster" {
  name = "${var.cluster_name}-cluster-fw"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = local.ssh_sources_cluster
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "6443"
    source_ips = concat([var.network_cidr], [var.allow_ssh_cidr])
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "10250"
    source_ips = [var.network_cidr]
  }

  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "8472"
    source_ips = [var.network_cidr]
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

  # ICMP (ping, PTB, etc.): not covered by tcp/udp rules; include v4 + v6 destinations.
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

  # Other IPv4 egress (IPsec ESP, GRE) — Hetzner API allows only a subset of protocols (not ah/ipip/sctp).
  dynamic "rule" {
    for_each = toset(["esp", "gre"])
    content {
      direction       = "out"
      protocol        = rule.value
      destination_ips = ["0.0.0.0/0"]
    }
  }

  labels = merge(local.common_labels, { tier = "cluster" })

  depends_on = [terraform_data.jump_architecture_precheck]
}

module "network" {
  source = "../network"

  name     = "${var.cluster_name}-network"
  ip_range = var.network_cidr
  subnets = {
    jump    = var.jump_subnet_cidr
    cluster = var.cluster_subnet_cidr
  }
  network_zone = var.network_zone
  labels       = local.common_labels
}

module "compute" {
  source = "../compute"

  network_id = module.network.network_id
  ssh_key_id = hcloud_ssh_key.cluster.id
  servers    = local.servers
  labels     = local.common_labels
  depends_on = [
    module.nat_gateway,
    hcloud_firewall.cluster,
    module.network,
    hcloud_ssh_key.cluster,
    hcloud_network_route.internet_via_nat,
  ]
}

module "workers_lb" {
  source = "../loadbalancer"

  name                   = "${var.cluster_name}-workers"
  load_balancer_type     = var.lb_type
  location               = var.location
  network_id             = module.network.network_id
  target_server_ids      = local.worker_target_ids
  use_private_ip_targets = true
  services               = var.lb_services
  labels                 = local.common_labels
}
