output "network_id" {
  value = hcloud_network.this.id
}

output "network_name" {
  value = hcloud_network.this.name
}

output "subnet_ids" {
  value = { for k, s in hcloud_network_subnet.this : k => s.id }
}

output "subnet_ip_ranges" {
  value = { for k, s in hcloud_network_subnet.this : k => s.ip_range }
}

# Back-compat: first subnet by key order (avoid relying on order — use subnet_ip_ranges by name)
output "subnet_ip_range" {
  description = "Deprecated: use subnet_ip_ranges. Returns one subnet value for legacy callers."
  value       = length(hcloud_network_subnet.this) > 0 ? values(hcloud_network_subnet.this)[0].ip_range : null
}
