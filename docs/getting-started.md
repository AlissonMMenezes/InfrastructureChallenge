# Getting started

1. **Terraform** — network, nodes, LBs (`terraform/environments/<env>`).  
2. **Ansible** — `bootstrap-k8s.yml` (kubeadm, Calico).  
3. **Flux** — bootstrap to **`gitops/clusters/<env>/`** (`install-fluxcd.yml` or `flux bootstrap github`).

**Need:** `HCLOUD_TOKEN`, SSH key in tfvars, Ansible **ProxyJump** to private nodes, GitHub token for Flux bootstrap.

```bash
cd terraform/environments/dev

cat dev.auto.tfvars # to make sure you the variables configured

terraform init

terraform apply
```

```bash
cd ../../ansible

export GITHUB_TOKEN=="your-token"

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

Details: **[terraform](terraform.md)**, **[ansible](ansible.md)**, **[gitops](gitops.md)**.
