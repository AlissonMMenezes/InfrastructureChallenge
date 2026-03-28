# Dev Environment (Hetzner)

This environment provisions infrastructure through `hetzner-cluster.tf`, which uses the composite `kubernetes` module.

**End-to-end NAT / egress** (topology, routes, firewalls, checks): see [`../modules/kubernetes/EGRESS.md`](../modules/kubernetes/EGRESS.md).

## Network layout (security baseline)

- **VPC** `network_cidr` (e.g. `10.50.0.0/16`)
- **Jump / bastion subnet** `jump_subnet_cidr` (e.g. `10.50.1.0/24`) — implemented by the reusable **`terraform/modules/nat-gateway`** module: **public IPv4**, **SNAT** for `cluster_subnet_cidr`, **SSH** entry point for admins
- **Cluster subnet** `cluster_subnet_cidr` (e.g. `10.50.2.0/24`) — **control-plane and workers** use **private IPs only** (no public IPv4 on the master by default)

**Hetzner load balancers** only handle **inbound** traffic. By default the module creates a **workers** LB (see `lb_services`: **80→30080** and **443→30443**, typical ingress NodePorts). Exposing the **Kubernetes API** on a public LB is **optional** (`expose_kubernetes_api_via_load_balancer`): a second LB targets the **control-plane** on **6443** (one target pool per LB, so API and workers cannot share one LB). They do **not** provide outbound NAT.

Egress for cluster nodes (Hetzner L3 networks):

1. **`hcloud_network_route`** `0.0.0.0/0` → **jump private IP** (SDN sends Internet traffic to the NAT host).
2. **Default route on nodes** → **Hetzner virtual gateway** (first address in `network_cidr`, e.g. `10.50.0.1` for `10.50.0.0/16`) — **not** the jump IP as the next hop.
3. **MASQUERADE** on the jump host for `cluster_subnet_cidr`.

If you only pointed the default route at the jump IP, cross-subnet L3 routing would fail and nodes would not get working egress.

### Routing: jump (NAT) vs cluster nodes (expected to differ)

| Host | Typical default route | Role |
|------|----------------------|------|
| **Jump / NAT** | `default via 172.31.1.1 dev eth0` (Hetzner **public** gateway) | Dual-homed: Internet on **eth0**, private VPC on **enp7s0**; **iptables MASQUERADE** sends client traffic out **eth0**. |
| **Master / workers** (no public IPv4) | `default via 10.50.0.1 dev enp7s0` | Single path: all off-VPC traffic to **10.50.0.1**; Hetzner **network route** `0.0.0.0/0` → jump private IP steers Internet flows to the NAT host. |

Nodes **must not** mirror the jump’s `default via eth0` table—they have no usable public path. That difference is correct.

**ICMP:** Hetzner Cloud Firewalls do not imply ICMP from TCP/UDP rules. The cluster and NAT firewalls allow **ICMP in/out** to `0.0.0.0/0` and `::/0`. Ansible UFW allows **ICMP / IPv6-ICMP** to nodes and the bastion from **any** source, and **forwarded ICMP** on the NAT host without source restriction.

## Prerequisites

- Terraform `>= 1.6.0`
- Hetzner Cloud API token
- SSH public key content to inject into created servers

## Required environment variables

```bash
export HCLOUD_TOKEN="your_hetzner_api_token"
```

## Required Terraform variables

`terraform/environments/dev/variables.tf` requires:

- `ssh_public_key`

You can pass it through a `.tfvars` file.

## Example `dev.auto.tfvars`

```hcl
ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... your@email"
```

## Run

From this directory (`terraform/environments/dev`):

```bash
terraform init
terraform plan -out tf.plan
terraform apply tf.plan
```

## Useful outputs

- `nodes` — `jump`, `master`, `workers` (IPs)
- `kube_api_load_balancer_ipv4` — set when `expose_kubernetes_api_via_load_balancer = true`
- `workers_load_balancer_ipv4` — set when `lb_services` is non-empty
- `cluster_nat_egress` — NAT gateway private IP and hints

### Upgrading from the old single workers LB (API on `lb_services`)

Previously, API exposure used `lb_services` on the **workers** LB (incorrect target for apiserver). The module now uses an optional **`kube_api_lb`** to the **master**; the **workers** LB stays on by default and can be turned off with `lb_services = []`.

After changing module addresses, refresh state so Terraform does not recreate resources unnecessarily:

```bash
terraform state mv 'module.kubernetes.module.workers_lb' 'module.kubernetes.module.workers_lb[0]'
```

Only run this if your state still has `module.workers_lb` without `[0]` and your new plan expects `module.workers_lb[0]`. If you removed the workers LB (`lb_services = []`), Terraform will destroy the old workers LB and create `module.kubernetes.module.kube_api_lb[0]` instead — review the plan.

## SSH and Ansible

1. SSH to **jump** public IP (from `terraform output`).
2. From jump, SSH to **10.50.2.10** (master) / **10.50.2.11+** (workers).

Update `ansible/inventory/dev-test-cluster.ini`: set `REPLACE_JUMP_PUBLIC_IP` to the jump host’s **public** IPv4, and add a **`[bastion]`** group (see that file). The kubeadm playbook runs **`base` + `security`** on `bastion` first so UFW does not strip NAT rules on the jump host.

Optional: `extra_ssh_source_cidrs` on the module to allow SSH to cluster nodes from a VPN CIDR in addition to the jump subnet.
