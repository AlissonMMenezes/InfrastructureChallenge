# GitOps layout (Flux v2)

Bootstrap path: **`gitops/clusters/<env>/`** (e.g. `flux bootstrap github --path=./gitops/clusters/dev`).

| Path | Contents |
|------|----------|
| `clusters/<env>/` | Root Flux **Kustomization**s (operators, infrastructure, applications) |
| `operators/` | **HelmRepository** + **HelmRelease** (CNPG, cert-manager, monitoring, OpenBao, ESO, …) |
| `infrastructure/` | Platform: **ClusterIssuer**, Traefik, Postgres **Cluster**, OpenBao auth Jobs + ingress, namespaces |
| `applications/base/` , `applications/environments/<env>/` | Kustomize bases and overlays |

**Assumptions**

1. **GitRepository** name **`flux-system`** unless you rename all `sourceRef`s.  
2. **`spec.path`** is relative to repo root.  
3. One env folder per cluster.  
4. **dependsOn:** `infrastructure` → `operators`; `applications` → `operators`, `infrastructure`.

**Install:** provision cluster → `flux bootstrap github` or **`ansible/playbooks/install-fluxcd.yml`** (see **`docs/gitops.md`**, **`ansible/README.md`**).

Argo CD was replaced by Flux Helm/Kustomize resources; no Argo manifests in this tree.
