# Getting started

1. **Terraform** — network, nodes, LBs (`terraform/environments/<env>`).
2. **Ansible** — `bootstrap-k8s.yml` (kubeadm, Calico).
3. **Flux** — bootstrap to `**gitops/clusters/<env>/`** (`install-fluxcd.yml` or `flux bootstrap github`).

**Need:** `HCLOUD_TOKEN`, SSH key in tfvars, Ansible **ProxyJump** to private nodes, GitHub token for Flux bootstrap.

## SSH via the bastion (jump host)

Kubernetes nodes use **private IPs** on the VPC. The **bastion** (jump / NAT host) has the **public** IPv4 you SSH to first.

1. After `**terraform apply`**, read the jump address from Terraform, for example:
  ```bash
   cd terraform/environments/dev
   terraform output nodes
  ```
   The `**jump**` object includes `**ipv4**` — that is the bastion’s public address. Copy `**master**` / `**workers**` private IPs the same way when updating Ansible inventory.
2. **SSH to the bastion only:**
  ```bash
   ssh root@<JUMP_PUBLIC_IPV4>
  ```
3. **SSH to a cluster node in one step** (same pattern as `**ansible/inventory/dev-test-cluster.ini`** — `**ProxyJump**`):
  ```bash
   ssh -J root@<JUMP_PUBLIC_IPV4> root@10.50.2.10
   ssh -J root@<JUMP_PUBLIC_IPV4> root@10.50.2.11
  ```
   Example (substitute IPs from `**terraform output nodes**` and your inventory):
4. Keep `**[bastion]**` `ansible_host` and `**ansible_ssh_common_args**` on `**[kubeadm_control_plane]**` / `**[kubeadm_workers]**` in sync with `**terraform output nodes**` so Ansible and ad hoc SSH match.

```bash
cd terraform/environments/dev

cat dev.auto.tfvars # to make sure your variables are configured

terraform init

terraform apply
```

```bash
cd ../../ansible

export GITHUB_TOKEN="your-token"

ansible-galaxy collection install -r requirements.yml

ansible-playbook -i inventory/dev-test-cluster.ini playbooks/bootstrap-k8s.yml

ansible-playbook -i inventory/dev-test-cluster.ini playbooks/install-fluxcd.yml \
  -e fluxcd_github_bootstrap=true \
  -e fluxcd_github_owner=AlissonMMenezes \
  -e fluxcd_github_repository=InfrastructureChallenge \
  -e fluxcd_github_path=gitops/clusters/dev \
  -e fluxcd_github_read_write_key=true \
  -e fluxcd_github_personal=true
```

**Smoke:** `kubectl get nodes`, `flux get kustomizations -A`, `kubectl get certificate -A` after DNS + ingress.

## URLs after the cluster is running

Ingress traffic hits **Traefik** on the workers load balancer. Point **DNS A (or AAAA) records** for each public hostname at the LB IPv4 from Terraform:

```bash
terraform output workers_load_balancer_ipv4
```

TLS uses **cert-manager** (`ClusterIssuer/letsencrypt-prod`) with HTTP-01 via Traefik; **port 80** must reach the cluster for certificate issuance.

Example hostnames wired in this repo (change `**alissonmachado.com.br`** to your domain in GitOps patches if needed):


| What                   | URL                                                                                               | Where it is defined                                                                                                                                                                                                                     |
| ---------------------- | ------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Demo API** (HTTPS)   | `https://demo-app.alissonmachado.com.br` **or** `https://major-upgrade-app.alissonmachado.com.br` | Only **one** dev overlay is active — see `**gitops/applications/environments/dev/kustomization.yaml`** (`demo-app` vs `major-upgrade-app`). Ingress patches: `demo-app/patches/ingress.yaml`, `major-upgrade-app/patches/ingress.yaml`. |
| **API docs** (Swagger) | `https://<same-demo-host>/api/docs`                                                               | Same Ingress as the demo app.                                                                                                                                                                                                           |
| **Grafana**            | `https://grafana.alissonmachado.com.br`                                                           | `**gitops/operators/kube-prometheus-stack/helmrelease.yaml`** (`grafana.ingress.hosts`). Admin password: **[operations — Monitoring](docs/operations.md#monitoring)**.                                                                                               |
| **OpenBao** (UI / API) | `https://openbao.alissonmachado.com.br`                                                           | `**gitops/infrastructure/openbao-ingress/ingress.yaml`**.                                                                                                                                                                               |


Prometheus and Alertmanager UIs are not given public Ingresses by default; use `**kubectl port-forward**` or Grafana if you need them locally.

Details: **[terraform](terraform.md)**, **[ansible](ansible.md)**, **[gitops](gitops.md)**.