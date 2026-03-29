# GitOps (Flux)

State under **`gitops/`**; Flux reconciles from **`gitops/clusters/<env>/`**. **One cluster ↔ one env folder** (do not apply both `dev` and `prod` to the same cluster).

## Bootstrap

```bash
export GITHUB_TOKEN=ghp_...
ansible-playbook -i inventory/dev-test-cluster.ini playbooks/install-fluxcd.yml \
  -e fluxcd_github_bootstrap=true \
  -e fluxcd_github_owner=<owner> \
  -e fluxcd_github_repository=<repo> \
  -e fluxcd_github_path=gitops/clusters/dev \
  -e fluxcd_github_read_write_key=true \
  -e fluxcd_github_personal=true   # user-owned repo
```

Or: `flux bootstrap github --path=./gitops/clusters/dev` (see [getting-started](getting-started.md)). Variables: **`ansible/playbooks/vars/fluxcd-github.example.yml`** — full options in **[ansible.md](ansible.md)**.

## Repository tree (`gitops/`)

Bootstrap path: **`gitops/clusters/<env>/`** (e.g. `flux bootstrap github --path=./gitops/clusters/dev`).

| Path | Contents |
|------|----------|
| `clusters/<env>/` | Root Flux **Kustomization**s (operators, infrastructure, applications) |
| `operators/` | **HelmRepository** + **HelmRelease** (CNPG, **plugin-barman-cloud**, cert-manager, monitoring, OpenBao, ESO, …) |
| `infrastructure/` | Platform: **ClusterIssuer**, Traefik, Postgres **Cluster**, OpenBao auth Jobs + ingress, namespaces |
| `applications/base/` , `applications/environments/<env>/` | Kustomize bases and overlays |

**Assumptions**

1. **GitRepository** name **`flux-system`** unless you rename all `sourceRef`s.  
2. **`spec.path`** is relative to repo root.  
3. One env folder per cluster.  
4. **dependsOn:** `infrastructure` → `operators`; `applications` → `operators`, `infrastructure`.

**Install:** provision cluster → `flux bootstrap github` or **`ansible/playbooks/install-fluxcd.yml`** (see **[ansible.md](ansible.md)**).

Argo CD was replaced by Flux Helm/Kustomize resources; no Argo manifests in this tree.

## Layout (dev) — summary

| Layer | Path | Role |
|-------|------|------|
| Operators | `gitops/operators/` | Helm: CNPG, **plugin-barman-cloud**, cert-manager, monitoring, OpenBao, ESO, … |
| Infrastructure | `gitops/infrastructure/` | ClusterIssuer, Traefik, Postgres clusters, OpenBao auth Jobs, ingress |
| Applications | `gitops/applications/environments/dev/` | App overlays (e.g. demo-app) |

**`dependsOn`:** `infrastructure` after `operators`; `applications` after `operators` + `infrastructure` (CRDs and issuers before app ingress).

**Operators** install charts; **infrastructure** consumes them (issuers, `Cluster`, Jobs). **Applications** are workloads + their CNPG `Cluster` where applicable.

### Operators (pointers)

- **cert-manager / issuers:** **[cert-manager-gitops.md](cert-manager-gitops.md)**
- **kube-prometheus-stack:** **[monitoring-stack.md](monitoring-stack.md)**

## Commands

```bash
flux get kustomizations -A
flux get helmreleases -A
flux reconcile kustomization infrastructure -n flux-system --with-source
```

## TLS

`ClusterIssuer/letsencrypt-prod` in **`gitops/infrastructure/cert-manager-issuers/`** — HTTP-01, **`ingressClassName: traefik`**. Workers LB must expose **80** (and **443** for clients). Set **`spec.acme.email`**. Ingresses use **`cert-manager.io/cluster-issuer: letsencrypt-prod`**.

Public hosts in this repo (patch in overlays): demo app, OpenBao, Grafana — DNS → workers LB IP (Terraform output).

## OpenBao + ESO (summary)

GitOps: **`gitops/infrastructure/openbao-kubernetes-auth/`** — init Job → **`Secret/openbao-bootstrap`**; second Job configures **`auth/kubernetes`** for Kubernetes-mounted tokens. Needs OpenBao **initialized and unsealed**; see **[operations — OpenBao](operations.md#openbao)**.

## Demo app + Postgres

CNPG **`Cluster/demo-app-db`** in **`app-dev`**, **`ObjectStore`** for Barman Cloud, **`ScheduledBackup`** (`method: plugin`) → **`Secret/demo-app-db-app`** (`uri`) → **`DATABASE_URL`** on **`Deployment/demo-api`**. See **[demo-app](demo-app.md)** and **[postgres-backup-strategy](postgres-backup-strategy.md)**.

## CI images

**`.github/workflows/demo-app-image.yml`** → **GHCR** `ghcr.io/<owner-lower>/demo-app`. Match **`ImageRepository`** and Deployment image. Optional Flux **ImageUpdateAutomation** in the dev demo-app overlay — token/bootstrap notes in **[ansible.md](ansible.md)**.
