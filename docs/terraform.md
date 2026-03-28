# Terraform

Terraform provisions **Hetzner Cloud** resources: network, NAT/bastion, Kubernetes nodes (private IPs), and **load balancers** for inbound traffic.

## Layout

- **Modules** under `terraform/modules/` — reusable pieces (`network`, `compute`, `nat-gateway`, `loadbalancer`, `kubernetes`, `storage`, …).
- **Environments** under `terraform/environments/<env>/` — `dev` and `prod` wire modules with environment-specific variables.

The composite **`kubernetes`** module (used by `terraform/environments/dev`) defines the full topology: VPC, jump/NAT subnet, cluster subnet, private control-plane and workers, optional API LB, workers LB (e.g. **80→30080**, **443→30443** for ingress NodePorts).

## Prerequisites

- Terraform **≥ 1.6** (see environment README if stricter).
- `HCLOUD_TOKEN` exported in your shell.

```bash
export HCLOUD_TOKEN="your_hetzner_api_token"
```

- **SSH public key** for cloud-init on servers (required variable — see `variables.tf` per environment).

## Configure

Use a tfvars file (do not commit secrets). Example pattern for dev:

`terraform/environments/dev/dev.auto.tfvars`:

```hcl
ssh_public_key = "ssh-ed25519 AAAA... comment"
```

See **`terraform/environments/dev/README.md`** for network CIDRs, routing/NAT behaviour, outputs (`nodes`, load balancer IPs), and upgrade notes.

## Run (dev example)

```bash
cd terraform/environments/dev
terraform init
terraform plan -out tf.plan
terraform apply tf.plan
```

## Outputs

Use Terraform outputs to fill **Ansible inventory** (`ansible_host`, bastion jump host, private IPs). Typical outputs include:

- Node addresses (`jump`, `master`, `workers`).
- `workers_load_balancer_ipv4` when worker LB services are enabled.
- `kube_api_load_balancer_ipv4` when API exposure via LB is enabled.

## Production

Use `terraform/environments/prod/` with its own tfvars and review module variables for sizing, backups, and LB settings.

## Hetzner Object Storage (backup bucket)

The **`terraform/modules/object-storage`** module creates an **S3-compatible bucket** on [Hetzner Object Storage](https://docs.hetzner.com/storage/object-storage/) using the **`aminueza/minio`** provider (the `hcloud` provider cannot manage buckets today).

In **`terraform/environments/dev`**, set **`object_storage_enabled = true`** and add **S3 access/secret keys** from the Hetzner Cloud Console. The default bucket name is **`{cluster_name}-cnpg-backups`** (override with `object_storage_bucket_name`).

The bucket resource uses **`prevent_destroy`** so destroying the rest of the infrastructure does **not** wipe backups. See **`terraform/environments/dev/README.md`** for details and how to retire a bucket intentionally.

## Further reading

- [`terraform/environments/dev/README.md`](../terraform/environments/dev/README.md) — dev topology, routing, firewalls.
- [`terraform/modules/kubernetes/EGRESS.md`](../terraform/modules/kubernetes/EGRESS.md) — NAT/egress deep dive.
