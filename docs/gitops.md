# GitOps (Flux CD)

The cluster desired state for operators, platform add-ons, and applications lives in **`gitops/`**. **Flux** reconciles Git to the cluster on an interval.

## Bootstrap

Point Flux at **one environment folder** per cluster (do not apply both `dev` and `prod` to the same cluster).

```bash
export GITHUB_TOKEN=ghp_...   # PAT with permissions required by Flux + your repo
ansible-playbook -i inventory/dev-test-cluster.ini playbooks/install-fluxcd.yml \
  -e fluxcd_github_bootstrap=true \
  -e fluxcd_github_owner=AlissonMMenezes \
  -e fluxcd_github_repository=InfrastructureChallenge \
  -e fluxcd_github_path=gitops/clusters/dev \
  -e fluxcd_github_read_write_key=true \
  -e fluxcd_github_personal=true
```

Alternative: Ansible **`ansible/playbooks/install-fluxcd.yml`** with **`fluxcd_github_path=gitops/clusters/dev`** (see **`ansible/README.md`**).

Flux creates the **`flux-system`** namespace, **`GitRepository`**, and root **`Kustomization`** that syncs `gitops/clusters/<env>/`.

## What `gitops/clusters/dev/` does

The dev entrypoint (`kustomization.yaml`) pulls in, in order:

| Bundle | Flux `Kustomization` resource | Path on disk | Role |
|--------|------------------------------|--------------|------|
| **Operators** | `operators` | `gitops/operators/` | Third-party **operators** installed with **Helm** (Flux `HelmRepository` + `HelmRelease`) |
| **Applications** | `applications` | `gitops/applications/environments/dev/` | App workloads (Kustomize / plain manifests), e.g. demo app |
| **Infrastructure** | `infrastructure` | `gitops/infrastructure/` | **Cluster platform** after operators: **Let’s Encrypt** `ClusterIssuer`, Traefik, CloudNativePG **database clusters**, shared infra |
| **Image automation** | (included in cluster kustomize) | `gitops/clusters/dev/image-automation/` | Flux **ImageRepository** / **ImagePolicy** / **ImageUpdateAutomation** (optional CI → image bumps in Git) |

`dependsOn` in the Flux `Kustomization` CRs enforces order where needed (e.g. infrastructure after operators).

### Operators vs infrastructure (important)

- **Operators** (`gitops/operators/`): install **software operators** into the cluster — Helm charts for **CloudNativePG**, **cert-manager**, **kube-prometheus-stack**, **OpenBao**, **External Secrets Operator**, etc. Each component usually has its own namespace (`cnpg-system`, `cert-manager`, `monitoring`, `openbao-system`, `external-secrets`, …). OpenBao uses the **official Helm chart** (StatefulSet server + optional **injector** webhook); ESO syncs secrets using provider APIs (here, OpenBao via the Vault-compatible provider).

- **Infrastructure** (`gitops/infrastructure/`): **use** those APIs and wire the platform — e.g. **Traefik** ingress HelmRelease, **PostgreSQL `Cluster`** manifests (CNPG), Traefik/Postgres namespaces and supporting objects. This is “what we run **on top of** the operators,” not the operator Helm charts themselves.

- **Applications** (`gitops/applications/`): **tenant/workload** manifests (demo API, ServiceMonitors, NetworkPolicies), often layered as **base** + **environment** overlays.

## Sync flow (conceptual)

1. You merge a change to `main` in the Git repo.
2. **source-controller** pulls the commit (`GitRepository`).
3. **kustomize-controller** applies the root `gitops/clusters/<env>/` kustomization, which creates/updates child Flux `Kustomization` and `HelmRelease` objects.
4. **helm-controller** installs/upgrades Helm releases referenced by `HelmRelease`.
5. Child Flux `Kustomization` objects apply app and infra kustomize paths.

Drift is corrected on each `spec.interval`.

## Useful commands

```bash
flux get kustomizations -A
flux get helmreleases -A
flux reconcile kustomization operators -n flux-system --with-source
flux reconcile kustomization infrastructure -n flux-system --with-source
```

## Layout reference

See **`gitops/README.md`** in the repo for directory conventions, bootstrap assumptions, and path rules.

## Demo app: PostgreSQL (CNPG), OpenBao, and External Secrets Operator

The **dev** overlay patches the CloudNativePG **`Cluster/demo-app-db`** to **`spec.instances: 3`**. **External Secrets Operator** (installed from **`gitops/operators/external-secrets/`**) drives two flows without custom scripts:

1. **`PushSecret/cnpg-demo-app-to-openbao`** (namespace **`app-dev`**) copies CNPG’s **`Secret/demo-app-db-app`** into OpenBao KV v2 at **`secret/demo-app/postgres`** (maps **`hostname` → `host`**, **`uri` → `connection_string`**, plus **`username`**, **`password`**, **`port`**, **`dbname`**).
2. **`ExternalSecret/demo-app-postgres`** materializes the same path into Kubernetes **`Secret/demo-app-postgres`** with keys **`DB_*`** for **`demo-api`** (`envFrom`).

**`ClusterSecretStore/openbao`** uses the Vault-compatible provider against **`http://openbao.openbao-system.svc.cluster.local:8200`** and **Kubernetes auth** with **`ServiceAccount/external-secrets`** in **`external-secrets`**.

### OpenBao bootstrap (not in Git)

On OpenBao, enable the **`secret`** KV v2 mount (if not already), **Kubernetes auth** at **`kubernetes`**, and a role **`external-secrets`** bound to **`external-secrets`/`external-secrets`** with a policy that allows **read and write** on **`secret/data/demo-app/postgres`**. Until that exists, **`ClusterSecretStore`** and the **PushSecret** / **ExternalSecret** resources stay degraded; **`demo-api`** pods need **`demo-app-postgres`** before they can start.

The OpenBao **injector** is optional for this app; the demo API no longer uses sidecar injection for DB credentials.

## CI and image automation

If **`gitops/clusters/dev/image-automation/`** is enabled, Flux can watch container registries (e.g. GHCR) and commit image tag updates back to Git. Ensure the Git credentials Flux uses allow **push** if you use **ImageUpdateAutomation** (see **`ansible/README.md`** Flux variables).
