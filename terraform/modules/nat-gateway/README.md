# `nat-gateway` (Hetzner Cloud)

Reusable module: one server with **public IPv4**, attached to a private network, **iptables MASQUERADE** for a configurable **source CIDR**, plus a matching **Hetzner Cloud Firewall** (SSH from admin CIDR, forwarded traffic from clients).

## Use cases

- Bastion / jump host that **SNATs** a downstream private subnet (e.g. Kubernetes nodes without public IPs).
- Any “NAT instance” pattern on Hetzner.

## Usage

```hcl
module "egress" {
  source = "../nat-gateway"

  name              = "myenv"
  server_name       = "myenv-nat-1"
  network_id        = hcloud_network.main.id
  private_ip        = "10.0.1.10"
  nat_source_cidr   = "10.0.2.0/24"
  allow_ssh_cidr    = "203.0.113.0/24"
  ssh_key_id        = hcloud_ssh_key.admin.id
  location          = "fsn1"
}
```

Point downstream hosts’ **default route** at `private_ip` (see `../kubernetes/cloud-init/nat-worker-route.yaml.tpl` for an example).

## Outputs

- `server`, `server_id`, `private_ip`, `public_ipv4`, `firewall_id`

## Notes

- **NAT is configured only through Terraform:** [`cloud-init/nat-gateway.yaml.tpl`](cloud-init/nat-gateway.yaml.tpl) → `locals.user_data` → `hcloud_server.user_data`. See [`cloud-init/README.md`](cloud-init/README.md) for create-time behavior and **`terraform apply -replace=...`** when the template changes.
- Clients use the **Hetzner platform gateway** as default route + **`hcloud_network_route` `0.0.0.0/0` → this host** (see kubernetes module / `EGRESS.md`).
- **UFW** on the gateway can flush iptables; re-run `/usr/local/sbin/hetzner-nat-gateway.sh` after enabling UFW or set `DEFAULT_FORWARD_POLICY=ACCEPT` (see Ansible `security` role).
