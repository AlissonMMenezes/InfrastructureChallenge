# Terraform

Provisions **Hetzner**: VPC, bastion/NAT, private Kubernetes nodes, load balancers.

- **Modules:** `terraform/modules/*`  
- **Envs:** `terraform/environments/{dev,prod}` — composite **`kubernetes`** module (topology, LBs, optional object storage).

## Dev environment (`terraform/environments/dev`)

Composite **`kubernetes`** module: VPC, bastion/NAT, private control-plane + workers, workers LB (**80→30080**, **443→30443**), optional API LB (**6443**). **Egress:** SDN route `0.0.0.0/0` → jump; nodes default via VPC gateway; **MASQUERADE** on jump. Detail: **`terraform/modules/kubernetes/EGRESS.md`**.

**Prereqs:** Terraform ≥ 1.6, `HCLOUD_TOKEN`, **`ssh_public_key`** (tfvars).

```bash
export HCLOUD_TOKEN=...
cd terraform/environments/dev
terraform init && terraform apply
```

**Outputs:** node IPs, **`workers_load_balancer_ipv4`** (public Ingress DNS — **80** must reach Traefik for ACME), **`object_storage_*`** when enabled.

**DNS:** public Ingress names → **`workers_load_balancer_ipv4`**.

**Object storage:** `object_storage_enabled = true` + keys → S3 bucket via **minio** provider; **`prevent_destroy`** on bucket. CNPG uses the bucket for **`dev-postgres/`**, **`major-upgrade-app/`**, and **`demo-app-db/`** prefixes (see **[postgres-backup-strategy](postgres-backup-strategy.md)**). Keys become **`cnpg-s3-credentials`** in Kubernetes (not applied by Terraform).

**Ansible:** jump public IP + private node IPs → **`ansible/inventory/dev-test-cluster.ini`**.

**NAT module (standalone docs):** **[terraform-nat-gateway.md](terraform-nat-gateway.md)**.

**State migration:** if upgrading module addressing for LBs, follow plan notes in Git history or `terraform state mv` only when plan indicates.
