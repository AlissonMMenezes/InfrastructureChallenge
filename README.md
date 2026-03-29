# Infrastructure Challenge

Hetzner VMs (**Terraform**), **kubeadm** cluster (**Ansible**), platform and apps (**Flux** GitOps). 

The **demo-api** connects to a Postgres Database that was provided via CloudNativePG Postgres

The `major-upgrade-app` is a separate example that shows **major version upgrades** using CNPG and **Barman Cloud** (recovery from backups on object storage). 

This Project was developed with the support of  [Cursor](https://cursor.com/).

## Docs


| Topic                      | File                                                                                                                                                                                                                                            |
| -------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Getting Started            | [docs/getting-started.md](docs/getting-started.md)                                                                                                                                                                                              |
| Terraform / Ansible / Flux | [docs/terraform.md](docs/terraform.md), [docs/ansible.md](docs/ansible.md), [docs/gitops.md](docs/gitops.md)                                                                                                                                    |
| Demo API                   | [docs/demo-app.md](docs/demo-app.md)                                                                                                                                                                                                            |
| Backups & Monitoring       | [Operations](docs/operations.md) — [Backups (CNPG)](docs/operations.md#backups-cnpg), [Restore](docs/operations.md#restore) · [cnpg-backup-secrets](docs/cnpg-backup-secrets.md) · [postgres-backup-strategy](docs/postgres-backup-strategy.md) |
| Design                     | [docs/architecture.md](docs/architecture.md)                                                                                                                                                                                                    |
| Security Considerations    | [docs/security.md](docs/security.md)                                                                                                                                                                                                            |


Full documentation index (including Terraform modules, operators, and NAT): **[docs/README.md](docs/README.md)**.

## Stack

- Kubernetes: 
  - **kubeadm**
  - **Calico**
  - **Traefik**
  - **cert-manager**
  - **CloudNativePG**
  - **kube-prometheus-stack**
  - optional
    - **OpenBao**
    - **External Secrets**
- Stateful backups: S3-compatible (**Hetzner Object Storage**);
- **demo-api** image: GHCR (`.github/workflows/demo-app-image.yml`);

---

## Planning

### Project delivery plan

#### 21.03.2026 - Planning

- [x] Planning
  - [x] Tasks breakdown
  - [x] Date of the deliverables

#### 21.03.2026 - Infrastructure code

- [x] Infrastructure code
  - [x] Terraform code to deploy servers on Hetzner
  - [x] Ansible code to deploy Kubernetes on the servers
  - [x] Ansible code to deploy FluxCD on the cluster

#### 22.03.2026 - GitOps code and workflow

- [x] GitOps code and workflow
  - [x] Create manifests for required operators
    - [x] CloudNativePG
    - [x] cert-manager (Let’s Encrypt)
    - [x] External Secrets Operator
    - [x] kube-prometheus-stack
    - [x] OpenBao
    - [x] plugin-barman-cloud
  - [x] Configure CloudNativePG
    - [x] 3 PostgreSQL instances
    - [x] Persistent volumes
    - [x] Failover configuration
  - [x] Configure automated backups
  - [x] Traefik as Ingress

#### 22.03.2026 - Monitoring setup

- [x] Monitoring setup
  - [x] Create manifests for required operators
    - [x] ServiceMonitor
    - [x] Exporters

#### 27.03.2026 - Work on upgrades

- [x] Work on upgrades
  - [x] PostgreSQL upgrade
  - [x] GitOps change management

#### 28.03.2026 - Deploy applications

- [x] Deploy applications
  - [x] Deploy demo-app via GitOps with CNPG, **HTTPS** ingress (Let’s Encrypt)

#### 28.03.2026 - Update documentation

- [x] Update documentation
  - [x] Split technical docs into `docs/`; Terraform, Ansible, GitOps guides added

## Team structure


| Role            | Responsibilities                                                                              |
| --------------- | --------------------------------------------------------------------------------------------- |
| Lead DevOps     | Architecture, decisions, escalation, infrastructure automation, planning and cost supervision |
| DevOps Engineer | CI/CD, infrastructure, automation, backup/restore                                             |
| DevOps Engineer | CI/CD, infrastructure, automation, security focus                                             |
| SRE Engineer    | Monitoring, reliability, security, incident response                                          |


## Review process

Development follows [GitFlow](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow). 

Merge requests should cover at least:

- No unnecessary duplication; no secrets in repository code
- Formatting and lint (e.g. `terraform fmt` before commit)
- [Terraform recommended practices](https://developer.hashicorp.com/terraform/cloud-docs/recommended-practices)

**Code reviews**

- All changes via merge requests
- Minimum reviewers: 1
- Automated checks (lint, tests, security scans) where available
- Optional: AI-assisted review workflows (e.g. [Sonar “Vibe and Verify”](https://www.sonarsource.com/sem/vibe-then-verify))

## Release management

Tags on **`main`** follow [Linux-style](https://www.kernel.org/doc/html/v4.11/process/2.Process.html) versioning: **`vMAJOR.MINOR.PATCH`** (e.g. **`v10.5.2`**).

Pin Terraform modules by ref when consuming shared modules:

```hcl
module "vpc" {
  source = "git::ssh://git@github.com/org/infra-modules.git//modules/vpc?ref=v1.2.0"
}
```

## Multi-environment deployments

Kubernetes config can follow a GitOps layout such as:

```text
gitops/
  clusters/
    customer1/
      dev/
      prod/
    customer2/
      dev/
      prod/
```

Central repo or [split repos](https://fluxcd.io/flux/guides/repository-structure/) per Flux. This repository maps **operators**, **infrastructure**, and **applications** in **[docs/gitops.md](docs/gitops.md)** and **[docs/architecture.md](docs/architecture.md)**.

**Secrets:** external stores (e.g. [OpenBao](https://openbao.org), [OpenBao namespaces](https://openbao.org/docs/concepts/namespaces/)) and [External Secrets Operator](https://external-secrets.io/latest/) — see **[docs/gitops.md](docs/gitops.md)**.

**Container registry:** CI pushes to **GHCR**; image path must be **lowercase** — align **`ImageRepository`** and **`Deployment`** with **`.github/workflows/demo-app-image.yml`**.