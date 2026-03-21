# Architecture

## Infrastructure layout

### Hetzner (Terraform `kubernetes` module)

- One **VPC** split into **two subnets**:
  - **Jump / bastion subnet** — host with **public IPv4**, **SSH** entry point, **SNAT/NAT** for the cluster subnet
  - **Cluster subnet** — **private-only** control-plane and workers; **default route via jump**; **SSH to nodes only from jump subnet** (plus optional extra CIDRs)
- **Load balancer** targets workers for inbound kube-apiserver (or apps); it does **not** provide outbound Internet access.

### Original challenge layout (generic)

- 3 Linux nodes per environment:
  - 1 control-plane
  - 2 workers
- Terraform provides node definitions, network CIDR metadata, firewall abstraction, environment-specific variables (`dev`, `prod`).

## Cluster architecture

- Kubernetes distribution: **kubeadm** (Ansible bootstrap); challenge docs may reference k3s as an alternate profile.
- CNI: **Calico** (Tigera operator, Ansible); can be switched to another CNI with manifest/role changes.
- Ingress: not pinned in GitOps tree; add via Flux when needed.
- Stateful data: CloudNativePG managed PostgreSQL cluster (`3` instances).
- Storage: persistent volumes via default StorageClass (replaceable with CSI).

## GitOps workflow

1. Engineer commits to Git.
2. **Flux CD** watches the bootstrap path (e.g. `gitops/clusters/<env>/` via `flux bootstrap github --path=./gitops/clusters/dev`).
3. The cluster kustomization applies Flux **`HelmRepository` / `HelmRelease`** (e.g. CloudNativePG operator) and Flux **`Kustomization`** objects that sync:
   - operator stack (Helm),
   - database cluster manifests,
   - demo application manifests.
4. Drift is reconciled on the configured intervals (`spec.interval`).

## Environment separation

- Terraform: `terraform/environments/dev` and `terraform/environments/prod`.
- GitOps root apps and value overlays separated per cluster.
- Ansible inventory separated by environment.

## Reproducibility

- Declarative configs only.
- Idempotent Ansible roles.
- Version-pinned images/manifests in Git.
- Promotion model: `dev -> prod` via pull request and review gates.
