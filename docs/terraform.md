# Terraform

Provisions **Hetzner**: VPC, bastion/NAT, private Kubernetes nodes, load balancers.

- **Modules:** `terraform/modules/*`  
- **Envs:** `terraform/environments/{dev,prod}` — composite **`kubernetes`** module (topology, LBs, optional object storage).

**Run (dev):**

```bash
export HCLOUD_TOKEN=...
cd terraform/environments/dev
terraform init && terraform apply
```

**Outputs:** node IPs, **`workers_load_balancer_ipv4`** (use for public Ingress DNS). **80** must reach Traefik for ACME.

**Object storage:** module **`object-storage`** + **`object_storage_enabled`** in dev — S3 bucket for CNPG; keys still become a Kubernetes Secret (not applied by Terraform). See **`terraform/environments/dev/README.md`**, **`modules/kubernetes/EGRESS.md`** for NAT detail.
