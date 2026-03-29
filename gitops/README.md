# GitOps (Flux CD)

This tree is intended for **Flux v2** (`flux bootstrap github` / `flux install` + manual `GitRepository`).

## Layout

| Path | Purpose |
|------|---------|
| **`clusters/<env>/`** | Cluster bootstrap path: kustomize bundle of Flux `HelmRepository`, `HelmRelease`, and `Kustomization` objects. Point **`flux bootstrap github --path`** here (e.g. `./gitops/clusters/dev`). |
| **`applications/environments/<env>/demo-app/`** (example) | Dev **demo-app** overlay can include **`image-automation.yaml`** next to **`kustomization.yaml`** so registry policies and the **`ImageUpdateAutomation`** path stay with the app. |
| **`infrastructure/`** | Shared platform: **Let’s Encrypt** `ClusterIssuer`, **OpenBao** **`auth/kubernetes`** bootstrap (**`openbao-kubernetes-auth/`**), **OpenBao** `Ingress`, **Traefik** `HelmRelease`, CloudNativePG **`Cluster`** (e.g. **`postgres/`**), namespaces. Synced by **`clusters/dev/infrastructure.yaml`** with **`dependsOn: operators`**. |
| **`operators/cert-manager/`** | Jetstack **`HelmRepository`** + **`cert-manager`** **`HelmRelease`** (ACME / Let’s Encrypt TLS). |
| **`operators/kube-prometheus-stack/`** | **`prometheus-community`** **`HelmRepository`** + **`kube-prometheus-stack`** (Prometheus, **Grafana** + **Flux** dashboards folder, **PodMonitor** for Flux controllers, KSM **CRS** for **`gotk_resource_info`**, ingress/TLS for Grafana). See **`operators/kube-prometheus-stack/README.md`**. |
| **`operators/cloudnative-pg/`** | CNPG Helm **`HelmRepository`** + **`HelmRelease`** (operator install). |
| **`operators/openbao/`** | Official **OpenBao** Helm repo + **`HelmRelease`** in **`openbao-system`** (server + optional **injector**). See [OpenBao K8s docs](https://openbao.org/docs/platform/k8s/helm/). |
| **`operators/external-secrets/`** | **External Secrets Operator** Helm chart — sync secrets from/to OpenBao (Vault API) and other providers; demo app uses **`PushSecret`** + **`ExternalSecret`**. |
| **`operators/postgres/`** (legacy / prod samples) | Older layout in some branches; **dev** uses **`operators/cloudnative-pg`**. |
| **`applications/base/`**, **`applications/environments/<env>/`** | **Kustomize** bases and overlays (e.g. demo app: **`base/demo-app/`**, dev patch **`environments/dev/demo-app/`**). Flux **`applications`** `Kustomization` points at **`environments/dev/`** for the dev cluster. |
| **`infrastructure/cert-manager-issuers/`** | **`ClusterIssuer`** for **Let’s Encrypt** (HTTP-01, Traefik ingress class). |
| **`infrastructure/openbao-kubernetes-auth/`** | **Job** + RBAC: configures OpenBao **`auth/kubernetes`**, policy, and role **`external-secrets`** for **ESO** (after **`Secret/openbao-bootstrap`** with **`root-token`**; see **`docs/gitops.md`**). |
| **`infrastructure/openbao-ingress/`** | **`Ingress`** exposing OpenBao on a public hostname (TLS via cert-manager). |

## Bootstrap assumptions

1. **GitRepository name** child resources use **`flux-system`** in namespace **`flux-system`** — the default name created by **`flux bootstrap github`**. If you rename it, update every `spec.sourceRef.name` in the `flux-kustomization-*.yaml` files.

2. **Paths** are relative to the **Git repository root** (e.g. `./gitops/...`). If your monorepo root differs, adjust `spec.path` on each Flux `Kustomization`.

3. **One cluster ↔ one env folder**: do not apply both `clusters/dev` and `clusters/prod` to the same cluster; they each define the same `HelmRepository`/`HelmRelease` names.

4. **Dev child `Kustomization` order:** **`infrastructure`** → `dependsOn: [operators]`. **`applications`** → `dependsOn: [operators, infrastructure]`. See **`docs/gitops.md`** for HTTPS hostnames and secrets flows.

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
