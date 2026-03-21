# Ansible: Kubernetes (kubeadm) & Flux CD

This folder provisions a **kubeadm** cluster on Debian/Ubuntu nodes and can install **Flux v2** (CLI + controllers, optionally **GitHub bootstrap**).

---

## What gets installed

| Stage | Playbook | What it does |
|-------|----------|----------------|
| **Kubernetes** | `playbooks/bootstrap-k8s.yml` | `base` + `kubernetes` roles: containerd, kubeadm/kubelet/kubectl, control-plane init, worker join, **Calico** CNI (Tigera operator), API/node checks. |
| **Flux CD** | `playbooks/install-fluxcd.yml` | `fluxcd` role: Flux CLI on every control-plane node; **`flux install`** or **`flux bootstrap github`** once (first control-plane). |

---

## Requirements

- **Ansible** 2.14+ on the machine you run playbooks from (controller).
- **SSH** access to all nodes (often via a **bastion / jump host** and private IPs — see inventory example below).
- **Target OS**: Debian/Ubuntu (roles use `apt`, `systemd`).
- **sudo/root** on nodes (`become: true` in playbooks).
- **Outbound internet** on nodes for Kubernetes packages and images (or configure **apt proxy** — see [Apt / private workers](#apt--private-workers)).
- **Collections**: `community.general`, `kubernetes.core` (installed from `requirements.yml`).

---

## Repository layout (this folder)

```text
ansible/
├── ansible.cfg              # roles_path, collections_paths, host_key_checking, …
├── requirements.yml         # Ansible collections
├── inventory/               # INI or YAML inventory (example: dev-test-cluster.ini)
├── playbooks/
│   ├── bootstrap-k8s.yml    # full cluster bootstrap
│   ├── install-fluxcd.yml   # Flux after cluster exists
│   └── vars/
│       └── fluxcd-github.example.yml
└── roles/
    ├── base/
    ├── kubernetes/
    ├── fluxcd/
    └── security/            # used by other playbooks if referenced
```

Run all commands from the **`ansible/`** directory so **`ansible.cfg`** is picked up:

```bash
cd ansible
```

---

## Step 1 — Install collections

```bash
ansible-galaxy collection install -r requirements.yml
```

Collections are installed under `./collections` (see `ansible.cfg` `collections_paths`) or your user Ansible paths.

---

## Step 2 — Configure inventory

### Groups

| Group | Purpose |
|-------|---------|
| **`kubeadm_control_plane`** | One or more control-plane nodes (first init target). |
| **`kubeadm_workers`** | Worker nodes to join the cluster. |
| **`kubeadm_cluster`** | Parent group: should include **both** control-plane and workers (use `:children` in INI). |

Optional **`[bastion]`** is for documentation / other playbooks (e.g. UFW); cluster playbooks use whatever SSH you configure on each host.

### Example INI (`inventory/dev-test-cluster.ini`)

- Set **`ansible_host`** to each server’s address (private IP behind a jump host is common).
- Use **`ansible_ssh_common_args='-o ProxyJump=user@bastion'`** (or `ProxyCommand`) so Ansible reaches private nodes.
- Set **`kubernetes_version`** to a **published** minor on pkgs.k8s.io (e.g. `1.31`, `1.32` — not every number exists).

```ini
[bastion]
jump ansible_host=203.0.113.50 ansible_user=root

[kubeadm_control_plane]
master ansible_host=10.50.2.10 ansible_user=root ansible_ssh_common_args='-o ProxyJump=root@203.0.113.50'

[kubeadm_workers]
worker ansible_host=10.50.2.11 ansible_user=root ansible_ssh_common_args='-o ProxyJump=root@203.0.113.50'

[kubeadm_cluster:children]
kubeadm_control_plane
kubeadm_workers

[kubeadm_cluster:vars]
kubernetes_version=1.31

[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

### YAML inventory / `group_vars`

You can use YAML inventory or put variables in `inventory/group_vars/kubeadm_cluster.yml`:

```yaml
kubernetes_version: "1.31"
```

If unset, the **`kubernetes`** role default in `roles/kubernetes/defaults/main.yml` applies.

### Connectivity check (optional)

```bash
ansible -i inventory/dev-test-cluster.ini kubeadm_cluster -m ping
```

---

## Step 3 — Bootstrap Kubernetes

### Run the playbook

```bash
cd ansible
ansible-playbook -i inventory/dev-test-cluster.ini playbooks/bootstrap-k8s.yml
```

### What the playbook does (order)

1. **Prepare all nodes** (`hosts: kubeadm_cluster`): **`base`**, **`kubernetes`** roles — containerd, Kubernetes apt repo/packages, kubelet, validation, etc.
2. **Initialize control plane** (`hosts: kubeadm_control_plane`): kubeadm init, kubeconfig for root.
3. **Join workers** (`hosts: kubeadm_workers`): kubeadm join using the token/command from the first control-plane.
4. **Install CNI** (Calico) on control-plane: **`kubectl apply`** Tigera operator manifest + templated **`Installation`** / **`APIServer`** CRs (`pod_network_cidr` must match kubeadm); role installs **`python3-kubernetes`** for other `kubernetes.core` use.
5. **Verify cluster**: wait for API **`/readyz`**, **`kubectl get nodes`**.

### After bootstrap — quick checks

On a control-plane node (or via Ansible ad-hoc):

- **`kubectl get nodes`** — all **Ready**.
- **`kubectl get pods -A`** — system pods running.

The **`kubernetes`** role copies **`/etc/kubernetes/admin.conf`** to **`~/.kube/config`** for the SSH user (e.g. root), so **`kubectl`** does not fall back to **`http://localhost:8080`**.

### SSH host keys

`ansible.cfg` sets **`host_key_checking = False`** so new hosts are not blocked by fingerprint prompts. For production, prefer verifying keys (e.g. `known_hosts` or **`StrictHostKeyChecking=accept-new`** in `ssh_args`).

---

## Step 4 — Install Flux CD

**Prerequisite:** Kubernetes is up and **`/etc/kubernetes/admin.conf`** exists on control-plane nodes (normal after `bootstrap-k8s.yml`).

### 4a — Default: `flux install` (no Git repo wiring)

Installs Flux controllers into the cluster (plus image automation controllers by default — see variables).

```bash
cd ansible
ansible-playbook -i inventory/dev-test-cluster.ini playbooks/install-fluxcd.yml
```

- Flux **CLI** is installed on **every** **`kubeadm_control_plane`** host.
- **`flux install`** and **`flux check`** run **once** (first host in the group) so HA control planes are not reconciled multiple times.

### 4b — GitHub bootstrap (GitOps)

Creates or updates a GitHub repository, commits Flux manifests, and configures the cluster to sync from Git. Requires a **GitHub token** on the Ansible controller.

1. Create a **personal access token** with permissions suitable for Flux (see [Flux: Bootstrap for GitHub](https://fluxcd.io/flux/installation/bootstrap/github/) for current scopes — classic PAT often uses **repo** and **`admin:public_key`** or fine-grained equivalents).

2. Export the token and run the playbook with variables (or use a vars file / Vault):

```bash
export GITHUB_TOKEN=ghp_your_token_here
cd ansible
ansible-playbook -i inventory/dev-test-cluster.ini playbooks/install-fluxcd.yml \
  -e fluxcd_github_bootstrap=true \
  -e fluxcd_github_owner=my-org-or-user \
  -e fluxcd_github_repository=fleet-infra \
  -e fluxcd_github_path=gitops/clusters/dev
```

For a **user** account (not an org), add **`-e fluxcd_github_personal=true`**.

**Example vars file** (no secrets in repo): `playbooks/vars/fluxcd-github.example.yml`

```bash
export GITHUB_TOKEN=ghp_...
ansible-playbook -i inventory/dev-test-cluster.ini playbooks/install-fluxcd.yml \
  -e @playbooks/vars/fluxcd-github.example.yml
```

You can set **`fluxcd_github_token`** via **Ansible Vault** instead of **`GITHUB_TOKEN`** in the shell. The bootstrap task uses **`no_log: true`** to limit token exposure in logs.

### Flux behaviour summary

| Mode | When | Result |
|------|------|--------|
| **`flux install`** | `fluxcd_github_bootstrap: false` (default) | Controllers only; you manage GitOps objects yourself. |
| **`flux bootstrap github`** | `fluxcd_github_bootstrap: true` | Controllers + GitHub repo + cluster sync wiring. |

When GitHub bootstrap is **enabled**, **`flux install`** is **not** run (**`fluxcd_cluster_install`** is ignored).

---

## Flux CD variables (reference)

Defined in **`roles/fluxcd/defaults/main.yml`**; override via inventory, `group_vars`, `-e`, or vars files.

| Variable | Purpose |
|----------|---------|
| **`fluxcd_version`** | Flux release **without** leading `v` (e.g. `2.4.0`). |
| **`fluxcd_kubeconfig`** | Admin kubeconfig on the node (default **`/etc/kubernetes/admin.conf`**). |
| **`fluxcd_image_automation`** | **`true`** (default): adds **`image-reflector-controller`** and **`image-automation-controller`**. |
| **`fluxcd_components_extra`** | Extra comma-separated controllers merged into **`--components-extra=`** (deduped). |
| **`fluxcd_network_policy`** | **`true`**: **`--network-policy`**; **`false`**: **`--network-policy=false`**. |
| **`fluxcd_cluster_install`** | **`false`**: CLI only (no **`flux install`**). Ignored if GitHub bootstrap is on. |
| **`fluxcd_verify`** | **`false`**: skip **`flux check`**. |
| **`fluxcd_github_bootstrap`** | **`true`**: **`flux bootstrap github`** instead of **`flux install`**. |
| **`fluxcd_github_owner`** / **`fluxcd_github_repository`** | GitHub owner and repo name. |
| **`fluxcd_github_path`** | Path inside repo (this monorepo: **`gitops/clusters/dev`** or **`gitops/clusters/prod`**). |
| **`fluxcd_github_branch`** | Branch (default **`main`**). |
| **`fluxcd_github_personal`** | User repo (**`--personal`**). |
| **`fluxcd_github_private`** | **`--private=true`** / **`false`**. |
| **`fluxcd_github_token_auth`** | **`true`** (default): **`--token-auth`**. |
| **`fluxcd_github_hostname`** | GitHub Enterprise hostname (optional). |
| **`fluxcd_github_reconcile`** | **`true`**: **`--reconcile`**. |
| **`fluxcd_github_bootstrap_extra_args`** | Extra args as a **list** of strings. |
| **`fluxcd_github_token`** | Optional; else **`GITHUB_TOKEN`** from controller env. |

---

## Kubernetes role notes (reference)

### Version source

Set **`kubernetes_version`** on **`kubeadm_cluster`** so apt uses **`pkgs.k8s.io/.../v<minor>/deb/`**. Must be a **published** minor (e.g. `1.31`).

### Kubeadm preflight: unique `product_uuid` and MACs

The **`kubernetes`** role runs **`validate_cluster_node_identity.yml`** when **`kubernetes_validate_unique_node_identity`** is `true`: collects non-loopback MACs and **`product_uuid`**, asserts **no duplicates** across **`kubeadm_cluster`**. Disable only if you must (**not** recommended): **`kubernetes_validate_unique_node_identity: false`**.

### Control-plane port precheck

**`precheck_control_plane_ports.yml`** fails if **TCP 6443** (or **`kubernetes_apiserver_port`**) is already listening **before** first bootstrap. If **`/etc/kubernetes/admin.conf`** exists, the check is skipped. Tunables: **`kubernetes_precheck_apiserver_port_skip_when_bootstrapped`**, **`kubernetes_precheck_apiserver_port_free`**.

### Container runtime & Kubernetes apt

Installs **containerd**, then Kubernetes packages via deb822 **`kubernetes.sources`**, **`Release.key`** → keyring, etc. Optional **`kubernetes_apt_enable_keyserver_fallback`** helps with **NO_PUBKEY**. See **`roles/kubernetes/defaults/main.yml`**.

### Calico CNI (Tigera operator)

**`roles/kubernetes/tasks/cni.yml`** applies the upstream **Tigera operator** manifest, then **`calico-custom-resources.yaml.j2`** ( **`Installation`** + **`APIServer`** ). The **`Installation`** `ipPools[].cidr` is **`{{ pod_network_cidr }}`** and must match **`kubeadm init --pod-network-cidr`**.

Variables in **`roles/kubernetes/defaults/main.yml`**: **`kubernetes_calico_version`**, **`kubernetes_calico_tigera_operator_manifest_url`**, and **`kubernetes_calico_wait_*`** timeouts/retries.

**UFW:** **`security`** allows **UDP 4789** (VXLAN) and **TCP 179** (BGP) on cluster nodes. Replacing **Flannel** (UDP 8472) with Calico.

**Existing clusters** already using Flannel are **not** migrated automatically — remove Flannel and install Calico manually or rebuild the cluster.

### Verify timings

**`kubernetes_verify_api_retries`**, **`kubernetes_verify_api_delay`**, **`kubernetes_verify_nodes_retries`**, **`kubernetes_verify_nodes_delay`** in **`roles/kubernetes/defaults/main.yml`** control post-CNI waits.

---

## Apt / private workers

If workers have **no route to the public internet**, `apt update` fails until you add **NAT** or an **HTTP(S) proxy** reachable from workers.

Example **`group_vars/all.yml`**:

```yaml
apt_force_ipv4: true
apt_http_proxy: "http://10.50.1.10:3128"
apt_https_proxy: ""
```

The **`base`** role writes apt proxy snippets and optional IPv4 forcing; see role tasks for details.

---

## Bastion / NAT and `hetzner_private_network_cidr`

If you use the **`security`** role on **`[bastion]`**, keep **`hetzner_private_network_cidr`** in `group_vars/all.yml` aligned with your cloud network (e.g. Terraform **`network_cidr`**) so UFW forwarding rules match your topology.

---

## Quick command cheat sheet

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml

# Kubernetes
ansible-playbook -i inventory/dev-test-cluster.ini playbooks/bootstrap-k8s.yml

# Flux (install only)
ansible-playbook -i inventory/dev-test-cluster.ini playbooks/install-fluxcd.yml

# Flux (GitHub bootstrap)
export GITHUB_TOKEN=...
ansible-playbook -i inventory/dev-test-cluster.ini playbooks/install-fluxcd.yml \
  -e fluxcd_github_bootstrap=true \
  -e fluxcd_github_owner=OWNER \
  -e fluxcd_github_repository=REPO \
  -e fluxcd_github_path=gitops/clusters/dev
```

---

## Playbook paths & config

- Prefer running from **`ansible/`** so **`./ansible.cfg`** applies (**`roles_path = ./roles`**).
- There is also **`playbooks/ansible.cfg`** with **`roles_path = ../roles`** if you ever `cd playbooks` — stay consistent with how you invoke **`ansible-playbook`**.

If anything fails, re-run with **`-vvv`** for verbose SSH/task output (avoid posting tokens or secrets).
