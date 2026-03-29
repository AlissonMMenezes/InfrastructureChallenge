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

Or: `flux bootstrap github --path=./gitops/clusters/dev` (see [getting-started](getting-started.md)). Variables: `ansible/playbooks/vars/fluxcd-github.example.yml`, **`ansible/README.md`**.

## Layout (dev)

| Layer | Path | Role |
|-------|------|------|
| Operators | `gitops/operators/` | Helm: CNPG, cert-manager, monitoring, OpenBao, ESO, … |
| Infrastructure | `gitops/infrastructure/` | ClusterIssuer, Traefik, Postgres clusters, OpenBao auth Jobs, ingress |
| Applications | `gitops/applications/environments/dev/` | App overlays (e.g. demo-app) |

**`dependsOn`:** `infrastructure` after `operators`; `applications` after `operators` + `infrastructure` (CRDs and issuers before app ingress).

**Operators** install charts; **infrastructure** consumes them (issuers, `Cluster`, Jobs). **Applications** are workloads + their CNPG `Cluster` where applicable.

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

CNPG **`Cluster/demo-app-db`** in **`app-dev`** → **`Secret/demo-app-db-app`** (`uri`) → **`DATABASE_URL`** on **`Deployment/demo-api`**. See **[demo-app](demo-app.md)**.

## CI images

**`.github/workflows/demo-app-image.yml`** → **GHCR** `ghcr.io/<owner-lower>/demo-app`. Match **`ImageRepository`** and Deployment image. Optional Flux **ImageUpdateAutomation** in the dev demo-app overlay (`ansible/README.md` for write token).

More tree detail: **`gitops/README.md`**.
