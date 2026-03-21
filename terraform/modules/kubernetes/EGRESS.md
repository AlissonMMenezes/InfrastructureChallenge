# Private cluster → Internet egress (Hetzner NAT)

This module implements **Hetzner Cloud L3 private networking** + **one NAT gateway** (jump host). Kubernetes nodes have **no public IPv4**; all Internet use goes through the jump host (**SNAT**).

## Topology (example: `10.50.0.0/16`)

```
Internet
    │
    │  eth0 (public), default via e.g. 172.31.1.1
    ▼
┌─────────────────────────────────────┐
│  Jump / NAT  10.50.1.10 (private)     │  ← hcloud_network_route gateway
│  • iptables MASQUERADE (cluster CIDR) │
│  • hcloud_firewall (nat-fw)           │
└──────────────┬──────────────────────┘
               │ enp7s0 (private)
               │ 10.50.0.0/16 via 10.50.0.1
               ▼
        Hetzner vSwitch / SDN
               │
    ┌──────────┴──────────┐
    │                     │
    ▼                     ▼
 Master 10.50.2.10    Worker(s) 10.50.2.x
 (no public IPv4)      (no public IPv4)
```

## Correct packet path (node → `https://example.com`)

1. **Node** has **default route** `via <platform GW>` on the private NIC (e.g. `10.50.0.1` for `10.50.0.0/16`).  
   **Not** `via <jump IP>` — cross-subnet L3 routing requires the platform gateway as the Linux next hop.

2. **`hcloud_network_route`** on the VPC: **`0.0.0.0/0` → jump private IP** (e.g. `10.50.1.10`).  
   Hetzner’s SDN steers **Internet** traffic from the network to the NAT server.

3. **Jump** receives forwarded packets, **FORWARD** + **MASQUERADE** on **WAN** (`eth0` default route), source becomes jump’s **public** IP.

4. **Return** traffic hits the jump’s public IP; **conntrack** + **DNAT** reverses; reply goes back to the node over the private network.

## Terraform / cloud-init responsibilities

| Piece | Role |
|--------|------|
| `hcloud_network` + subnets | VPC + jump / cluster subnets |
| `hcloud_network_route` `0.0.0.0/0` → `jump_private_ip` | **Required** for Internet from private nodes |
| `nat-gateway` module | Jump server + **SNAT** script + **nat-fw** |
| `nat_source_cidr` | Must include **all node private IPs** (default: `cluster_subnet_cidr`) |
| `nat-worker-route.yaml.tpl` | **Default route** + **DNS** on private NIC (`systemd-networkd` + `resolved`) |
| `hcloud_firewall` **cluster** | **Egress**: TCP/UDP all ports, ICMP, plus **ESP/GRE** IPv4 where supported by Hetzner API |

## Host firewall (Ansible `security` role)

- **Nodes**: UFW default **allow outgoing** — does not restrict Internet egress.
- **Jump**: `DEFAULT_FORWARD_POLICY=ACCEPT`, `ufw route allow` private → WAN, re-run **`hetzner-nat-gateway.sh`** after UFW so **MASQUERADE** stays in place.

## Verification (on a node)

```bash
ip -4 route show default
resolvectl query example.com
curl -4 -I --connect-timeout 10 https://example.com
```

On the **jump**:

```bash
sysctl net.ipv4.ip_forward
sudo iptables -t nat -S POSTROUTING | grep MASQUERADE
```

## Common failures

| Symptom | Check |
|---------|--------|
| No default route on node | `70-hetzner-private-*.network` + `systemd-networkd`; NIC name `enp7s0` vs `ens10` |
| Default route OK, no Internet | `terraform state show` / console: **network route** `0.0.0.0/0` → jump IP |
| TCP works, DNS fails | `resolved` + per-link `DNS=` / `UseDNS=no` in same `.network` files |
| **Ping hangs** (no replies) | **`rp_filter`**: `sysctl net.ipv4.conf.all.rp_filter` should be **0** on nodes (see `99-nat-client-rpfilter.conf` / Ansible `base` role). **Jump**: re-run `hetzner-nat-gateway.sh` (ICMP **FORWARD** rules before UFW). **UFW on node**: `ufw allow in proto icmp` (Ansible `security` role). |
| Worked until Ansible | Jump: re-run `/usr/local/sbin/hetzner-nat-gateway.sh`; `ufw route` rules |

## IPv6

This baseline is **IPv4-centric** (`0.0.0.0/0` route, SNAT script IPv4). Enabling **public IPv6** on nodes would need a separate design (no NAT v6 route in this module).
