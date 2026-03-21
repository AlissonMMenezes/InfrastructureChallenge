output "network" {
  description = "Network module outputs"
  value = {
    id             = module.network.network_id
    name           = module.network.network_name
    subnets        = module.network.subnet_ip_ranges
    jump_subnet    = var.jump_subnet_cidr
    cluster_subnet = var.cluster_subnet_cidr
  }
}

output "jump" {
  description = "Bastion / NAT gateway (from nat-gateway module; SSH here first)"
  value       = module.nat_gateway.server
}

output "nat_gateway" {
  description = "NAT gateway module outputs (firewall, ids)"
  value = {
    firewall_id = module.nat_gateway.firewall_id
    server_id   = module.nat_gateway.server_id
    private_ip  = module.nat_gateway.private_ip
    public_ipv4 = module.nat_gateway.public_ipv4
  }
}

output "master" {
  description = "Control-plane (private IP only by default)"
  value       = module.compute.servers["${var.cluster_name}-master-1"]
}

output "workers" {
  description = "Worker node details"
  value = {
    for worker_name in [for worker in local.worker_servers : worker.name] :
    worker_name => module.compute.servers[worker_name]
  }
}

output "load_balancer" {
  description = "Workers load balancer details"
  value = {
    id   = module.workers_lb.id
    ipv4 = module.workers_lb.ipv4
  }
}

output "cluster_nat_egress" {
  description = "Cluster nodes use Hetzner virtual GW + network route 0.0.0.0/0 to jump for SNAT (not the load balancer)."
  value = {
    nat_gateway_private_ip             = var.jump_private_ip
    hetzner_private_network_gateway_ip = local.hetzner_private_network_gateway_ip
    nat_source_cidr                    = var.cluster_subnet_cidr
    jump_subnet_cidr                   = var.jump_subnet_cidr
    ssh_to_cluster_hint                = "SSH: connect to jump public IP, then ssh to master/worker private IPs on cluster subnet."
    load_balancer_note                 = "Hetzner LB only forwards inbound traffic to targets; it does not provide NAT."
  }
}

# Back-compat alias
output "worker_nat_egress" {
  description = "Deprecated: use cluster_nat_egress"
  value       = { nat_gateway_private_ip = var.jump_private_ip, nat_source_cidr = var.cluster_subnet_cidr }
}
