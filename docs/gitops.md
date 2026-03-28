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
| **Infrastructure** | `infrastructure` | `gitops/infrastructure/` | **Cluster platform** after operators: Traefik, CloudNativePG **database clusters**, shared infra |
| **Image automation** | (included in cluster kustomize) | `gitops/clusters/dev/image-automation/` | Flux **ImageRepository** / **ImagePolicy** / **ImageUpdateAutomation** (optional CI → image bumps in Git) |

`dependsOn` in the Flux `Kustomization` CRs enforces order where needed (e.g. infrastructure after operators).

### Operators vs infrastructure (important)

- **Operators** (`gitops/operators/`): install **software operators** into the cluster — Helm charts for **CloudNativePG**, **cert-manager**, **kube-prometheus-stack**, etc. Each operator usually has its own namespace (`cnpg-system`, `cert-manager`, `monitoring`, …). These components **extend the API** (CRDs) and run controller pods.

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

## CI and image automation

If **`gitops/clusters/dev/image-automation/`** is enabled, Flux can watch container registries (e.g. GHCR) and commit image tag updates back to Git. Ensure the Git credentials Flux uses allow **push** if you use **ImageUpdateAutomation** (see **`ansible/README.md`** Flux variables).
