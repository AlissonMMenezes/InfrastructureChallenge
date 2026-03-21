output "firewall_id" {
  description = "Hetzner firewall id attached to the NAT gateway"
  value       = hcloud_firewall.this.id
}

output "server_id" {
  description = "NAT gateway server id"
  value       = module.compute.server_ids[var.server_name]
}

output "private_ip" {
  description = "Private IPv4 of the NAT gateway (use as default route for clients)"
  value       = var.private_ip
}

output "public_ipv4" {
  description = "Public IPv4 of the NAT gateway"
  value       = module.compute.servers[var.server_name].ipv4
}

output "server" {
  description = "Full server record from compute module"
  value       = module.compute.servers[var.server_name]
}
