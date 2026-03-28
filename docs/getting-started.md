# Getting started

End-to-end flow for a new environment:

1. **Terraform** — create VPC, bastion/NAT, private Kubernetes nodes, and load balancers.  
2. **Ansible** — harden hosts, install containerd and Kubernetes packages, `kubeadm init` / join, Calico.  
3. **Flux** — install controllers and bootstrap Git sync so the cluster reconciles manifests from `gitops/clusters/<env>/`.

## Prerequisites

- Hetzner Cloud API token (`HCLOUD_TOKEN`) for Terraform.
- SSH key pair; public key passed into Terraform (`ssh_public_key` / tfvars).
- Ansible controller with SSH access (typically **ProxyJump** via bastion to private nodes).
- For Flux bootstrap: GitHub token (or SSH deploy key) with rights to read/write the GitOps repo as required by [Flux](https://fluxcd.io/flux/installation/bootstrap/github/).

## Commands (summary)

```bash
# 1) Infrastructure
cd terraform/environments/dev
export HCLOUD_TOKEN="..."
terraform init
terraform plan -out tf.plan
terraform apply tf.plan

# 2) Kubernetes (edit ansible/inventory/*.ini for IPs and ProxyJump)
cd ../../ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i inventory/dev-test-cluster.ini playbooks/bootstrap-k8s.yml

# 3) GitOps (from machine with cluster kubeconfig / on control plane)
flux bootstrap github \
  --owner=<org-or-user> \
  --repository=<repo> \
  --branch=main \
  --path=./gitops/clusters/dev \
  --personal   # if user-owned repo; omit for org
```

See [Terraform](terraform.md), [Ansible](ansible.md), and [GitOps](gitops.md) for detail, troubleshooting, and alternatives (e.g. Ansible-driven Flux install).

## Validation

On a control-plane node (after bootstrap):

```bash
kubectl get nodes -o wide
kubectl get pods -A
flux get kustomizations -A    # if Flux CLI installed
kubectl get helmreleases -A
kubectl get certificate -A    # Let’s Encrypt / cert-manager
```

After DNS points at the workers load balancer, **HTTPS** endpoints from GitOps (e.g. demo app, OpenBao, Grafana — see **`docs/gitops.md`**) should respond once **`Certificate`** resources are **Ready**.
