# Ansible

From **`ansible/`** (so **`ansible.cfg`** applies): node baseline, **kubeadm**, **Calico**, optional **Flux**.

```bash
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i inventory/dev-test-cluster.ini playbooks/bootstrap-k8s.yml
ansible-playbook -i inventory/dev-test-cluster.ini playbooks/install-fluxcd.yml
```

**Inventory:** private nodes via **`ProxyJump`** to bastion; **`kubernetes_version`** must exist on [pkgs.k8s.io](https://pkgs.k8s.io/). Example: **`inventory/dev-test-cluster.ini`**.

**Flux GitHub bootstrap:** `-e fluxcd_github_bootstrap=true` and owner/repo/path vars — see **`ansible/README.md`** and **`playbooks/vars/fluxcd-github.example.yml`**.

Role defaults: **`roles/kubernetes/defaults/main.yml`**, **`roles/fluxcd/defaults/main.yml`**.
