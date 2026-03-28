# Ansible

Ansible configures **Linux baselines**, **firewalls**, **Kubernetes (kubeadm)**, **Calico (Tigera)**, and **Flux CD**.

## Layout

- **`ansible/ansible.cfg`** — roles path, collections path (run playbooks from `ansible/` so this file is picked up).
- **`ansible/inventory/`** — per-environment inventory (e.g. `dev-test-cluster.ini`).
- **`ansible/playbooks/`** — entry playbooks.
- **`ansible/roles/`** — `base`, `security`, `kubernetes`, `fluxcd`, …

Full collection requirements: `ansible/requirements.yml` — install before first run:

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
```

## Inventory (Hetzner layout)

Private cluster nodes are reached via **bastion**:

- **`[bastion]`** (or jump) — public IP; Terraform output.
- **`[kubeadm_control_plane]`** / **`[kubeadm_workers]`** — private IPs on the cluster subnet.
- **`[kubeadm_cluster]`** — parent group including both (INI `:children`).

Set **`ansible_ssh_common_args='-o ProxyJump=user@bastion'`** (or `ProxyCommand`) on nodes behind the jump host.

Set **`kubernetes_version`** on `kubeadm_cluster` to a **published** minor on [pkgs.k8s.io](https://pkgs.k8s.io/) (e.g. `1.35`).

Example reference: `ansible/inventory/dev-test-cluster.ini`.

## Bootstrap Kubernetes

Playbook: **`playbooks/bootstrap-k8s.yml`**

Typical stages:

1. **Prepare all nodes** in `kubeadm_cluster`: `base` + `kubernetes` role — prechecks, containerd, Kubernetes packages, kubelet.
2. **Control plane**: `kubeadm init`, admin kubeconfig, join token.
3. **Workers**: `kubeadm join`.
4. **CNI**: Calico (Tigera operator) on control plane.
5. **Verification**: API / nodes readiness.

```bash
cd ansible
ansible-playbook -i inventory/dev-test-cluster.ini playbooks/bootstrap-k8s.yml
```

Role and variable details: **`ansible/README.md`**.

## Install Flux

If you do not use `flux bootstrap` from your laptop, you can install Flux with:


```bash
export GITHUB_TOKEN=ghp_...   # PAT with permissions required by Flux + your repo
ansible-playbook -i inventory/dev-test-cluster.ini playbooks/install-fluxcd.yml \
  -e fluxcd_github_bootstrap=true \
  -e fluxcd_github_owner=AlissonMMenezes \
  -e fluxcd_github_repository=InfrastructureChallenge \
  -e fluxcd_github_path=gitops/clusters/dev \
  -e fluxcd_github_read_write_key=true \
  -e fluxcd_github_personal=true
```

Configure GitHub bootstrap, path, and token per **`ansible/playbooks/vars/fluxcd-github.example.yml`** and **`ansible/README.md`**.

The GitOps path should match the cluster (e.g. **`./gitops/clusters/dev`**).

## Bastion / NAT

The **`security`** role on the bastion must keep **NAT/SNAT** working after UFW changes. The **`kubernetes`** role assumes Debian/Ubuntu (`apt`, `systemd`).

## Validation

From the control plane:

```bash
kubectl get nodes -o wide
kubectl get pods -A
```
