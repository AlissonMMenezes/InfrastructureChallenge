# Documentation

All project documentation lives under **`docs/`** (except the repository **[README.md](../README.md)** at the root).

| Doc | What |
|-----|------|
| [getting-started.md](getting-started.md) | Terraform → Ansible → Flux |
| [terraform.md](terraform.md) | Hetzner provisioning (dev env, object storage) |
| [terraform-nat-gateway.md](terraform-nat-gateway.md) | `nat-gateway` Terraform module + cloud-init |
| [ansible.md](ansible.md) | Kubeadm cluster bootstrap, Flux playbooks, inventory |
| [gitops.md](gitops.md) | Flux layout, repo tree, TLS, OpenBao bootstrap summary |
| [cert-manager-gitops.md](cert-manager-gitops.md) | cert-manager operator + ClusterIssuers |
| [monitoring-stack.md](monitoring-stack.md) | kube-prometheus-stack, CNPG PodMonitors |
| [demo-app.md](demo-app.md) | demo-api; **`demo-app`** = normal CNPG Postgres; **`major-upgrade-app`** = major-upgrade example (CNPG + Barman) |
| [operations.md](operations.md) | Barman backup & restore (YAML + `kubectl`), Grafana password, OpenBao, TLS |
| [cnpg-backup-secrets.md](cnpg-backup-secrets.md) | `cnpg-s3-credentials` Secret |
| [postgres-backup-strategy.md](postgres-backup-strategy.md) | Barman / CNPG backup & restore: classic vs **Barman Cloud plugin** + **`ObjectStore`** |
| [postgres-upgrade-strategy.md](postgres-upgrade-strategy.md) | CNPG / Postgres upgrades |
| [architecture.md](architecture.md) | Network and components |
| [repository-structure.md](repository-structure.md) | Top-level dirs |
| [security.md](security.md) | Posture summary |
| [leadership.md](leadership.md) | Delivery / org bullets |
