# Infrastructure Challenge

Hetzner VMs (**Terraform**), **kubeadm** cluster (**Ansible**), platform and apps (**Flux** GitOps). Demo API and CloudNativePG Postgres are in-tree. (Developed with [Cursor](https://cursor.com/).)

## Docs

| Topic | File |
|-------|------|
| Index | [docs/README.md](docs/README.md) |
| Order of work | [docs/getting-started.md](docs/getting-started.md) |
| Terraform / Ansible / Flux | [docs/terraform.md](docs/terraform.md), [docs/ansible.md](docs/ansible.md), [docs/gitops.md](docs/gitops.md) |
| Demo API | [docs/demo-app.md](docs/demo-app.md) |
| Backups & ops | [docs/operations.md](docs/operations.md), [docs/cnpg-backup-secrets.md](docs/cnpg-backup-secrets.md), [docs/postgres-backup-strategy.md](docs/postgres-backup-strategy.md) |
| Postgres upgrades | [docs/postgres-upgrade-strategy.md](docs/postgres-upgrade-strategy.md) |
| Design | [docs/architecture.md](docs/architecture.md), [docs/security.md](docs/security.md) |

Full documentation index (including Terraform modules, operators, and NAT): **[docs/README.md](docs/README.md)**.

## Stack (short)

- Kubernetes: **kubeadm**, **Calico**, **Traefik**, **cert-manager**, **CloudNativePG**, **kube-prometheus-stack**, optional **OpenBao** + **External Secrets**.
- Stateful backups: S3-compatible (**Hetzner Object Storage**); **`dev-postgres`** uses embedded **`barmanObjectStore`**, **`demo-app-db`** uses **Barman Cloud CNPG-I** (**`ObjectStore`** + **`plugin-barman-cloud`**). App DB auth via CNPG **`Secret`** / ESO where wired.
- **demo-api** image: GHCR (`.github/workflows/demo-app-image.yml`); image path must use a **lowercase** owner segment for OCI.

## Security (short)

No secrets in Git for production credentials. Use CNPG/EKS-style cluster secrets, ESO, or SOPS. Network policies default-deny where defined. Node SSH/firewall baseline via Ansible.

Details: [docs/security.md](docs/security.md).

## Process (short)

Changes via merge requests; `main` protected. Format/lint before commit (e.g. `terraform fmt`). Tags: `vMAJOR.MINOR.PATCH` when you release. Separate GitOps paths per environment (`gitops/clusters/<env>`); do not point dev and prod at the same cluster.

Challenge-oriented notes: [docs/leadership.md](docs/leadership.md).

---

## Planning

### Project delivery plan

#### 21.03.2026 - Planning

- [X] Planning
  - [X] Tasks Breakdown
  - [X] Date of the Deliverables

#### 21.03.2026 - Infrastructure Code

- [X] Infrastructure Code
  - [X] Terraform Code to deploy servers on Hetzner
  - [X] Ansible Code to deploy Kubernetes on the servers
  - [X] Ansible Code to deploy FluxCD on the cluster

#### 22.03.2026 - GitOps Code and Workflow

- [X] GitOps Code and Workflow
  - [X] Create manifests for required operators
    - [X] CloudNativePG
    - [X] Cert-Manager ( for lets encrypt )
    - [X] External Secrets Operator
    - [X] Kube-Prometheus-Stack
    - [X] OpenBao
    - [X] Plugin-Barman-Cloud
  - [X] Configure CloudNativePG
    - [X] 3 PostgreSQL instances
    - [X] Persistent volumes
    - [X] Failover configuration
  - [X] Configure Automated Backups
  - [X] Traefik installing as Ingress

#### 22.03.2026 - Monitoring Setup

- [X] Monitoring Setup
  - [X] Create manifests for required operators
    - [X] Service Monitor
    - [X] Exporters

#### 27.03.2026 - Work on Upgrades

- [X] Work on Upgrades
  - [X] PostgreSQL Upgrade
  - [X] GitOps Change Management

#### 28.03.2026 - Deploy Applications

- [X] Deploy Applications
  - [X] Deploy demo-app via GitOps with CNPG, **HTTPS** ingress (Let’s Encrypt)

#### 28.03.2026 - Update Documentation

- [X] Update Documentation
  - [X] Split technical docs into `docs/`; Terraform, Ansible, GitOps guides added

## Team structure

| Role | Responsibilities |
|------|------------------|
| Lead DevOps | Architecture, decisions, escalation, infrastructure automation, planning and cost supervision |
| DevOps Engineer | CI/CD, infrastructure, automation, backup/restore |
| DevOps Engineer | CI/CD, infrastructure, automation, security focus |
| SRE Engineer | Monitoring, reliability, security, incident response |

## Review process

Development follows [GitFlow](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow). **`main`** stays protected.

Merge requests should cover at least:

- No unnecessary duplication; no secrets in repository code
- Formatting and lint (e.g. **`terraform fmt`** before commit)
- [Terraform recommended practices](https://developer.hashicorp.com/terraform/cloud-docs/recommended-practices)

**Code reviews**

- [ ] All changes via merge requests
- [ ] Minimum reviewers: 1
- [ ] Automated checks (lint, tests, security scans) where available
- [ ] Optional: AI-assisted review workflows (e.g. [Sonar “Vibe and Verify”](https://www.sonarsource.com/sem/vibe-then-verify))

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

**Secrets:** external stores (e.g. [OpenBao](https://openbao.org), [OpenBao namespaces](https://openbao.org/docs/concepts/namespaces/)) and [External Secrets Operator](https://external-secrets.io/latest/) — see **`docs/gitops.md`**.

**Container registry:** CI pushes to **GHCR**; image path must be **lowercase** — align **`ImageRepository`** and **`Deployment`** with **`.github/workflows/demo-app-image.yml`**.
