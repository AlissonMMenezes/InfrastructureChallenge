# Getting started

End-to-end order:

1. **Configure and run Terraform** — provision network, bastion, nodes, load balancers.
2. **Create infrastructure** — `terraform apply`, then copy outputs into Ansible inventory.
3. **Configure Ansible** — install collections, align inventory with Terraform (including SSH via bastion).
4. **Bootstrap Kubernetes** — `bootstrap-k8s.yml` (kubeadm, Calico).
5. **Bootstrap Flux** — `install-fluxcd.yml` (or `flux bootstrap github`) so GitOps reconciles `gitops/clusters/<env>/`.

**Prerequisites:** `HCLOUD_TOKEN`, SSH public key in Terraform tfvars, GitHub token for Flux bootstrap, Ansible **ProxyJump** to private nodes (see SSH below).

---

## 1. Terraform setup

From the repo root, pick an environment (e.g. **dev**) and configure variables (typically **`dev.auto.tfvars`** next to **`main.tf`**).

```bash
cd terraform/environments/dev
export HCLOUD_TOKEN="HERE-GOES-YOUR-TOKEN"
cat dev.auto.tfvars   # confirm HCLOUD_TOKEN, ssh_public_key, sizing, etc.
terraform init
terraform plan        # optional: review changes
```

Details: **[terraform](terraform.md)**.

---

## 2. Create infrastructure

Apply Terraform to create Hetzner resources (VPC, bastion/NAT, cluster nodes, workers load balancer, optional object storage).

```bash
cd terraform/environments/dev
terraform apply
```

**Outputs to capture**

Example of Terraform output.
```bash
terraform output

cluster_nat_egress = {
  "hetzner_private_network_gateway_ip" = "10.50.0.1"
  "jump_subnet_cidr" = "10.50.1.0/24"
  "load_balancer_note" = "Hetzner LB only forwards inbound traffic to targets; it does not provide NAT."
  "nat_gateway_private_ip" = "10.50.1.10"
  "nat_source_cidr" = "10.50.2.0/24"
  "ssh_to_cluster_hint" = "SSH: connect to jump public IP, then ssh to master/worker private IPs on cluster subnet."
}
nodes = {
  "jump" = {
    "id" = "125224899"
    "ipv4" = "78.46.243.66"
    "ipv6" = ""
    "labels" = tomap({
      "cluster" = "dev-test"
      "environment" = "dev"
      "managed_by" = "terraform"
      "module" = "compute"
      "role" = "nat-gateway"
      "tier" = "bastion"
      "workload" = "kubernetes"
    })
    "name" = "dev-test-jump-1"
    "private_ip" = "10.50.1.10"
  }
  "master" = {
    "id" = "125224935"
    "ipv4" = ""
    "ipv6" = ""
    "labels" = tomap({
      "cluster" = "dev-test"
      "environment" = "dev"
      "managed_by" = "terraform"
      "module" = "compute"
      "role" = "master"
      "workload" = "kubernetes"
    })
    "name" = "dev-test-master-1"
    "private_ip" = "10.50.2.10"
  }
  "workers" = {
    "dev-test-worker-1" = {
      "id" = "125224934"
      "ipv4" = ""
      "ipv6" = ""
      "labels" = tomap({
        "cluster" = "dev-test"
        "environment" = "dev"
        "managed_by" = "terraform"
        "module" = "compute"
        "role" = "worker"
        "workload" = "kubernetes"
      })
      "name" = "dev-test-worker-1"
      "private_ip" = "10.50.2.11"
    }
  }
}
object_storage_bucket_name = "dev-test-cnpg-backups"
object_storage_region = "fsn1"
object_storage_s3_endpoint = "fsn1.your-objectstorage.com"
workers_load_balancer_ipv4 = "91.98.8.33"
```

Update **`ansible/inventory/dev-test-cluster.ini`** (or your inventory) so **`[bastion]`** `ansible_host` and **`ansible_ssh_common_args`** on control-plane/workers match these values.

---

## 3. Ansible setup

Install Galaxy dependencies and run playbooks from **`ansible/`** (so **`ansible.cfg`** applies).

```bash
cd ../../ansible
ansible-galaxy collection install -r requirements.yml
```

Confirm **inventory** matches Terraform: bastion public IP, private IPs for **`[kubeadm_control_plane]`** and **`[kubeadm_workers]`**, **`ProxyJump`** to the bastion. See **[ansible](ansible.md)**.

### SSH via the bastion (jump host)

Cluster nodes use **private** IPs. SSH to the **bastion** first, or use **ProxyJump** in one command (same pattern as the inventory).

1. **Bastion only**

   ```bash
   ssh root@<JUMP_PUBLIC_IPV4>
   ```

2. **Jump straight to a node** (example private IPs; use yours from **`terraform output nodes`**)

   ```bash
   ssh -J root@<JUMP_PUBLIC_IPV4> root@10.50.2.10
   ssh -J root@<JUMP_PUBLIC_IPV4> root@10.50.2.11
   ```

Keep **`[bastion]`** `ansible_host` and **`ansible_ssh_common_args`** on **`[kubeadm_control_plane]`** / **`[kubeadm_workers]`** in sync with Terraform so Ansible and ad hoc SSH match.

---

## 4. Bootstrap Kubernetes

Runs kubeadm (control plane + workers), **Calico**, and checks. **`kubernetes_version`** in inventory must match a published minor on pkgs.k8s.io.

```bash
cd ../../ansible
ansible-playbook -i inventory/dev-test-cluster.ini playbooks/bootstrap-k8s.yml
```

Use **`kubectl`** from the bastion (copy kubeconfig from the control plane if needed) or tunnel — see **[ansible](ansible.md)**.

---

## 5. Bootstrap Flux CD

Installs Flux and optionally bootstraps GitHub so the cluster tracks **`gitops/clusters/<env>/`**. Set **`GITHUB_TOKEN`** (repo access for deploy keys / bootstrap).


The parameters **fluxcd_github_read_write_key=true** is need to use the **Image Automation**.
```bash
export GITHUB_TOKEN="ghp_your_token_here"

ansible-playbook -i inventory/dev-test-cluster.ini playbooks/install-fluxcd.yml \
  -e fluxcd_github_bootstrap=true \
  -e fluxcd_github_owner=YOUR_GITHUB_USER_OR_ORG \
  -e fluxcd_github_repository=YOUR_REPO_NAME \
  -e fluxcd_github_path=gitops/clusters/dev \
  -e fluxcd_github_read_write_key=true \
  -e fluxcd_github_personal=true
```

See **[gitops](gitops.md)**.

**Smoke checks** (after DNS and ingress are wired):

```bash
kubectl get nodes
flux get kustomizations -A
kubectl get certificate -A
```

---

## URLs after the cluster is running

Ingress hits **Traefik** on the workers load balancer. Point **DNS A/AAAA** for your hostnames at:

```bash
cd terraform/environments/dev
terraform output workers_load_balancer_ipv4
```

TLS uses **cert-manager** (**`ClusterIssuer/letsencrypt-prod`**) with HTTP-01 via Traefik; **port 80** must reach the cluster for certificate issuance.

Example hostnames in this repo (replace the domain in GitOps patches if needed):

| What | URL | Where it is defined |
|------|-----|---------------------|
| **Demo API** (HTTPS) | `https://demo-app.alissonmachado.com.br` |  Ingress: **`demo-app/patches/ingress.yaml`** |
| **API docs** (Swagger) | `https://<same-demo-host>/api/docs` | Same Ingress as the demo app. |
| **Grafana** | `https://grafana.alissonmachado.com.br` | **`gitops/operators/kube-prometheus-stack/helmrelease.yaml`** (`grafana.ingress.hosts`). Admin password: **[operations — Monitoring](operations.md#monitoring)**. |
| **OpenBao** (UI / API) | `https://openbao.alissonmachado.com.br` | **`gitops/infrastructure/openbao-ingress/ingress.yaml`**. |


---

**More:** **[terraform](terraform.md)**, **[ansible](ansible.md)**, **[gitops](gitops.md)**.
