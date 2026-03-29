# Documentation

Technical guides for this repository. **Project delivery plan, team structure, and review process** stay in the root [`README.md`](../README.md).

| Document | Contents |
|----------|----------|
| [Getting started](getting-started.md) | Recommended order: Terraform → Ansible → Flux, and where to look next |
| [Terraform](terraform.md) | Provisioning Hetzner VMs, variables, environments |
| [Ansible](ansible.md) | Node prep, Kubernetes bootstrap, optional Flux install |
| [Demo app](demo-app.md) | **`demo-api`**: Go service, CNPG **`Secret`** → **`DATABASE_URL`**, networking |
| [GitOps (Flux)](gitops.md) | Bootstrap, sync layout, **dependsOn** ordering, **HTTPS** / Let’s Encrypt, **OpenBao** (Kubernetes auth bootstrap + **ESO**), demo app, public hostnames |
| [Repository structure](repository-structure.md) | What each top-level directory is for |
| [Architecture](architecture.md) | Network topology, cluster design, GitOps flow |
| [Operations](operations.md) | Backups, restore, monitoring, upgrades |
| [PostgreSQL upgrade strategy](postgres-upgrade-strategy.md) | CloudNativePG operator + PostgreSQL version/config upgrades (GitOps) |
| [CNPG backup secrets (S3)](cnpg-backup-secrets.md) | Create **`cnpg-s3-credentials`** for CloudNativePG → Hetzner Object Storage |
| [Security](security.md) | Security posture and controls |
| [Leadership](leadership.md) | Delivery / leadership notes |

Repository-specific GitOps layout details: [`../gitops/README.md`](../gitops/README.md).  
Ansible details and Flux variables: [`../ansible/README.md`](../ansible/README.md).  
Dev Terraform environment: [`../terraform/environments/dev/README.md`](../terraform/environments/dev/README.md).
