# Ansible role: `kubernetes`

Phased kubeadm bootstrap; consumed by **`playbooks/bootstrap-k8s.yml`**.

| Phase | `tasks_from` | Hosts | Purpose |
|--------|----------------|--------|---------|
| Prepare | *(default `main.yml`)* | `kubeadm_cluster` | Unique DMI **product_uuid**, API port precheck, containerd, kubelet/kubeadm/kubectl |
| Control plane | `control_plane.yml` | `kubeadm_control_plane` | `kubeadm init`, kubeconfig, join token |
| Workers | `workers.yml` | `kubeadm_workers` | `kubeadm join`; optional **`~/.kube/config`** from admin kubeconfig (**`kubernetes_copy_admin_kubeconfig_to_workers`**) |
| CNI | `cni.yml` | `kubeadm_control_plane` | Calico via `kubernetes.core` |
| Verify | `verify_cluster.yml` | `kubeadm_control_plane` | `kubernetes.core.k8s_info` until API + nodes ready |

**Collections:** `kubernetes.core` (≥ 2.4 for Calico manifest URL). **Python:** `python3-kubernetes` on nodes for `kubernetes.core` (role installs it in `cni.yml`).

**Variables:** see **`defaults/main.yml`**. Override **`kubernetes_version`** per environment in inventory.
