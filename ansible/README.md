# Ansible (kubeadm + Flux)

Run from **`ansible/`** so **`ansible.cfg`** applies.

## Requirements

Ansible 2.14+, SSH to nodes (often **ProxyJump** via bastion), Debian/Ubuntu targets, sudo.

## Setup

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
```

## Inventory

Groups: **`kubeadm_control_plane`**, **`kubeadm_workers`**, **`kubeadm_cluster`** (`:children` both). Set **`ansible_ssh_common_args='-o ProxyJump=user@bastion'`** on private nodes. **`kubernetes_version`**: published minor on pkgs.k8s.io (e.g. `1.31`). Example: **`inventory/dev-test-cluster.ini`**.

```bash
ansible -i inventory/dev-test-cluster.ini kubeadm_cluster -m ping
```

## Kubernetes

```bash
ansible-playbook -i inventory/dev-test-cluster.ini playbooks/bootstrap-k8s.yml
```

Order: prepare nodes (containerd, packages) → **kubeadm init** → join workers → **Calico** → checks. **`pod_network_cidr`** must match kubeadm. Details: **`roles/kubernetes/`**, **`docs/ansible.md`**.

## Flux

**Controllers only:**

```bash
ansible-playbook -i inventory/dev-test-cluster.ini playbooks/install-fluxcd.yml
```

**GitHub bootstrap** (token on controller):

```bash
export GITHUB_TOKEN=ghp_...
ansible-playbook -i inventory/dev-test-cluster.ini playbooks/install-fluxcd.yml \
  -e fluxcd_github_bootstrap=true \
  -e fluxcd_github_owner=OWNER \
  -e fluxcd_github_repository=REPO \
  -e fluxcd_github_path=gitops/clusters/dev \
  -e fluxcd_github_read_write_key=true \
  -e fluxcd_github_personal=true   # user repo
```

Example vars: **`playbooks/vars/fluxcd-github.example.yml`**. **`fluxcd_github_bootstrap: true`** runs **`flux bootstrap github`** (not **`flux install`**).

## Variables

**Flux:** **`roles/fluxcd/defaults/main.yml`** — version, path, image automation components, **`fluxcd_github_*`**.  
**Kubernetes:** **`roles/kubernetes/defaults/main.yml`** — CNI, containerd, verify timeouts, prechecks.

## Notes

- **`host_key_checking = false`** in **`ansible.cfg`** — tighten for production.  
- Workers without internet need NAT/proxy (**`docs/terraform.md`**, **`modules/kubernetes/EGRESS.md`**).  
- Bastion **UFW:** keep **`hetzner_private_network_cidr`** aligned with Terraform if you use **`security`** role there.

Verbose debug: **`-vvv`** (no tokens in logs).
