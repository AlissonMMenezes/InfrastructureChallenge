# Infrastructure - Challenge

This repository deploys a Kubernetes cluster on **Hetzner** using **Terraform**, **Ansible (kubeadm)**, and **GitOps (Flux CD v2)**.

All the code developed here was done with the support of [Cursor](https://cursor.com/).

## Documentation

Technical runbooks and how-tos live under **`docs/`**:

- **[Documentation index](docs/README.md)** — table of contents  
- **[Getting started](docs/getting-started.md)** — Terraform → Ansible → Flux order  
- **[Terraform](docs/terraform.md)** — provision VMs and networking  
- **[Ansible](docs/ansible.md)** — bootstrap Kubernetes and Flux  
- **[GitOps (Flux)](docs/gitops.md)** — sync model, **operators vs infrastructure vs applications**  
- **[Architecture](docs/architecture.md)** — network topology and cluster design  
- **[Repository structure](docs/repository-structure.md)** — what each top-level folder is for  

Also: [`ansible/README.md`](ansible/README.md), [`gitops/README.md`](gitops/README.md), [`terraform/environments/dev/README.md`](terraform/environments/dev/README.md).

## Scope and assumptions

- Target environment: virtual machines on **Hetzner**.
- Kubernetes: **kubeadm** (minor aligned with [pkgs.k8s.io](https://pkgs.k8s.io/), e.g. `1.31`+).
- GitOps: **Flux v2** (`GitRepository`, `HelmRelease`, `Kustomization`).
- Stateful data: **CloudNativePG**; backups target **S3-compatible** storage (see [`docs/operations.md`](docs/operations.md)).

## Security-by-default (summary)

- Least-privilege RBAC for workloads and service accounts.
- Namespace isolation and default-deny-oriented network policies where defined in GitOps.
- Secrets referenced via Kubernetes secrets / external-secret patterns (SOPS/ESO-ready).
- Hardened node baseline via Ansible (SSH, firewall, fail2ban).

Details: [`docs/security.md`](docs/security.md).

---

## Planning

### Project Delivery Plan

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
  - [X] Configure CloudNativePG
    - [X] 3 PostgreSQL instances
    - [X] Persistent volumes
    - [X] Failover configuration
  - [ ] Configure Automated Backups
  - [X] Traefik installing as Ingress

#### 22.03.2026 - Monitoring Setup
- [X] Monitoring Setup
  - [X] Create manifests for required operators
    - [X] Service Monitor
    - [X] Exporters

#### 27.03.2026 - Work on Upgrades
- [ ] Work on Upgrades
  - [ ] PostgreSQL Upgrade
  - [X] GitOps Change Management

#### 28.03.2026 - Deploy Applications
- [ ] Deploy Applications
  - [ ] Deploy demo-app on the infrastructure

#### 28.03.2026 - Update Documentation
- [X] Update Documentation
  - [X] Split technical docs into `docs/`; Terraform, Ansible, GitOps guides added

## Team Structure
| Role | Responsibilities | 
|------|------------------|
| Lead DevOps | Architecture, decisions, escalation, Infrastructure Automation, Team Planning and Costs Supervision|
| DevOps Engineer | CI/CD, infrastructure, automation and Backup/Restore |
| DevOps Engineer | CI/CD, infrastructure, automation and Security Focus |
| SRE Engineer | Monitoring, reliability, security, Incident Response Owner |


---

## Review Process

For the development process we have to follow the [GitFlow](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow)

**Main branch needs always to be protected**

A Merge Request template needs to be created in order to establish the minium review criterias:

Eg.

* No code duplication
* No secrets in the code
* Code needs to be properly formatted, terraform for example, you should always run **terraform fmt** before commiting
* Always follow the best practices [Terraform Best Practices](https://developer.hashicorp.com/terraform/cloud-docs/recommended-practices)



### Code Reviews
- [ ] All changes via Merge Requests
- [ ] Minimum reviewers: 1
- [ ] Automated checks (lint, tests, security scans):
- [ ] Use AI for automated checks, Reviews and Suggestions [Vibe and Verify example](https://www.sonarsource.com/sem/vibe-then-verify)




## Release Management
### Release Strategy

Every code that is merged to the main branch needs to have a tag the follows the [Linux Versioning](https://www.kernel.org/doc/html/v4.11/process/2.Process.html) standard.

  
    major-version.minor-version.patch

eg.

    v10.5.2

In the case of terraform modules for example, the version needs to be pinned liked this:

```
module "vpc" {
  source = "git::ssh://git@github.com/org/infra-modules.git//modules/vpc?ref=v1.2.0"
}
```

So we can make new releases without breaking the existing code.


## Multi-Environment Deployments

### Customer-Specific Configurations

#### Strategy

For Kubernetes workloads we can do all the configurations using [GitOps](https://www.gitops.tech/#what-is-gitops)

```
gitops/
  clusters/
    customer1/
      dev/
      prod/
    customer2/
      dev/
      prod/
```

Then all the management can be centralized, or case the customer needs to have access to the configuration, FluxCD allows to have the configuration in a separated repository: [Ways of structuring your repositories](https://fluxcd.io/flux/guides/repository-structure/)

See **[GitOps (Flux)](docs/gitops.md)** and **[Architecture](docs/architecture.md)** for how this repo maps **operators**, **infrastructure**, and **applications**.


#### Secrets Separation

All the secrets can be separated using an external secret management solution, like [OpenBao](https://openbao.org)

Each customer could have their own namespaces.

Docs about [OpenBao Namespaces](https://openbao.org/docs/concepts/namespaces/)

The secrets can be dynamically synced into the applications using the [External Secrets Operator](https://external-secrets.io/latest/)
