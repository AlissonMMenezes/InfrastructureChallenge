# Terraform dev (Hetzner)

Composite **`kubernetes`** module: VPC, bastion/NAT, private control-plane + workers, workers LB (**80→30080**, **443→30443**), optional API LB (**6443**). **Egress:** SDN route `0.0.0.0/0` → jump; nodes default via VPC gateway; **MASQUERADE** on jump. Detail: **`modules/kubernetes/EGRESS.md`**.

**DNS:** public Ingress names → **`workers_load_balancer_ipv4`** (`terraform output`). **Port 80** must hit Traefik for ACME.

**Prereqs:** Terraform ≥ 1.6, `HCLOUD_TOKEN`, **`ssh_public_key`** (tfvars).

**Object storage:** `object_storage_enabled = true` + keys → S3 bucket via **minio** provider; **`prevent_destroy`** on bucket. Keys still go into K8s as **`cnpg-s3-credentials`** (not applied by Terraform).

```bash
export HCLOUD_TOKEN=...
terraform init && terraform apply
```

**Outputs:** `nodes`, `workers_load_balancer_ipv4`, `object_storage_*` when enabled.

**Ansible:** jump public IP + private node IPs → **`ansible/inventory/dev-test-cluster.ini`**.

**State migration:** if upgrading module addressing for LBs, follow plan notes in Git history or `terraform state mv` only when plan indicates.
