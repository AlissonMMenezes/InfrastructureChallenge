output "server_ids" {
  value = { for k, srv in hcloud_server.this : k => srv.id }
}

output "servers" {
  value = {
    for k, srv in hcloud_server.this : k => {
      id         = srv.id
      name       = srv.name
      ipv4       = srv.ipv4_address
      ipv6       = srv.ipv6_address
      private_ip = local.servers_by_name[k].private_ip
      labels     = srv.labels
    }
  }
}
