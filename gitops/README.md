# GitOps (Flux CD)

This tree is intended for **Flux v2** (`flux bootstrap github` / `flux install` + manual `GitRepository`).

## Layout

| Path | Purpose |
|------|---------|
| **`clusters/<env>/`** | Cluster bootstrap path: kustomize bundle of Flux `HelmRepository`, `HelmRelease`, and `Kustomization` objects. Point **`flux bootstrap github --path`** here (e.g. `./gitops/clusters/dev`). |
| **`operators/postgres/`** | CNPG Helm install + Flux `Kustomization` CRs that sync `manifests/<env>/`. |
| **`applications/demo-app/`** | Flux `Kustomization` CRs that sync `manifests/<env>/`. |
| **`applications/*/manifests/`** | Plain Kubernetes manifests + **kustomize** `Kustomization` (kustomize.config.k8s.io). |
| **`operators/*/manifests/`** | Same for operators (CNPG `Cluster`, backups, monitors). |

## Bootstrap assumptions

1. **GitRepository name** child resources use **`flux-system`** in namespace **`flux-system`** — the default name created by **`flux bootstrap github`**. If you rename it, update every `spec.sourceRef.name` in the `flux-kustomization-*.yaml` files.

2. **Paths** are relative to the **Git repository root** (e.g. `./gitops/...`). If your monorepo root differs, adjust `spec.path` on each Flux `Kustomization`.

3. **One cluster ↔ one env folder**: do not apply both `clusters/dev` and `clusters/prod` to the same cluster; they each define the same `HelmRepository`/`HelmRelease` names.

## Install flow (summary)

1. Provision Kubernetes (e.g. Ansible `bootstrap-k8s.yml`).
2. Bootstrap Flux against this repo, matching the path you use for that cluster, for example:

   ```bash
   export GITHUB_TOKEN=...
   flux bootstrap github \
     --owner=<org-or-user> \
     --repository=<repo> \
     --branch=main \
     --path=./gitops/clusters/dev \
     --personal   # if owner is a user account
   ```

3. Or install Flux with Ansible (`install-fluxcd.yml`) and create **`GitRepository`** / root **`Kustomization`** yourself to point at `./gitops/clusters/<env>`.

## Migrated from Argo CD

Former **`argoproj.io/v1alpha1` `Application`** manifests were replaced with:

- **Helm** apps → **`HelmRepository`** + **`HelmRelease`**
- **Directory / kustomize** apps → **`kustomize.toolkit.fluxcd.io` `Kustomization`** with `spec.sourceRef` → **`GitRepository/flux-system`**

Argo-specific placeholders under **`infrastructure/argocd/`** were removed; use the Ansible **`fluxcd`** role or **`flux bootstrap`** for controller install.
