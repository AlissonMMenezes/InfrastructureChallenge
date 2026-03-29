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
| **Infrastructure** | `infrastructure` | `gitops/infrastructure/` | **Cluster platform** after operators: **Let’s Encrypt** (`ClusterIssuer/letsencrypt-prod`), **OpenBao** **Kubernetes auth** bootstrap (**`openbao-kubernetes-auth/`**), public **Ingress**, **Traefik**, shared **Postgres** `Cluster` (e.g. `dev-postgres`), etc. |
| **Image automation** | (with app overlay) | `gitops/applications/environments/dev/demo-app/image-automation.yaml` | Flux **ImageRepository** / **ImagePolicy** / **ImageUpdateAutomation** (optional CI → image bumps in Git; **`update.path`** targets the same folder as **`kustomization.yaml`**) |

**Flux `dependsOn` (dev):** **`infrastructure`** waits for **`operators`** (CRDs and Helm installs, including cert-manager and OpenBao, exist before the `ClusterIssuer` and ingress manifests). **`applications`** waits for **`operators`** and **`infrastructure`** so **Let’s Encrypt** issuers and shared ingress plumbing exist before app ingresses and certificates. The root `gitops/clusters/dev/kustomization.yaml` only lists child Flux `Kustomization` files; ordering is defined on those CRs, not by file list order.

### Operators vs infrastructure (important)

- **Operators** (`gitops/operators/`): install **software operators** into the cluster — Helm charts for **CloudNativePG**, **cert-manager**, **kube-prometheus-stack**, **OpenBao**, **External Secrets Operator**, etc. Each component usually has its own namespace (`cnpg-system`, `cert-manager`, `monitoring`, `openbao-system`, `external-secrets`, …). OpenBao uses the **official Helm chart** (StatefulSet server + optional **injector** webhook); ESO syncs secrets using provider APIs (here, OpenBao via the Vault-compatible provider).

- **Infrastructure** (`gitops/infrastructure/`): **use** those APIs and wire the platform — e.g. **cert-manager** `ClusterIssuer` (Let’s Encrypt HTTP-01 via **Traefik**), **Job** + RBAC under **`openbao-kubernetes-auth/`** (configures OpenBao **`auth/kubernetes`** for External Secrets; needs **`Secret/openbao-bootstrap`** created out-of-band), **Ingress** for public **OpenBao** (`openbao.alissonmachado.com.br`), **Traefik** `HelmRelease`, **PostgreSQL `Cluster`** manifests (CNPG, e.g. under `postgres/`), and related namespaces. This is “what we run **on top of** the operators,” not the operator Helm charts themselves.

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

### OpenBao Kubernetes auth bootstrap

**Goal:** OpenBao must serve **`auth/kubernetes`** (with **`auth/kubernetes/config`** pointing at the cluster API), a **policy** for KV paths under **`demo-app`**, and a **role** **`external-secrets`** bound to **`ServiceAccount/external-secrets`** in **`external-secrets`**. The **`ClusterSecretStore`** manifest (**`gitops/applications/base/demo-app/clustersecretstore-openbao.yaml`**) already requests **Kubernetes auth** at mount **`kubernetes`** and **`role: external-secrets`**; the server-side wiring is applied by GitOps plus a one-time **root token** Secret.

**Prerequisite:** initialize and unseal OpenBao — see **[Operations → OpenBao initialize and unseal](operations.md#openbao-initialize-and-unseal)**.

**Helm:** **`gitops/operators/openbao/helmrelease.yaml`** sets **`server.route.authDelegator.enabled: true`** so the OpenBao server **ServiceAccount** can participate in **TokenReview** (required for **`auth/kubernetes/config`**).

**GitOps path:** **`gitops/infrastructure/openbao-kubernetes-auth/`** (synced by the **`infrastructure`** Flux `Kustomization`) contains:

| Artifact | Role |
|----------|------|
| **`external-secrets-openbao.hcl`** | Policy **`external-secrets-openbao`** (KV v2 under **`secret/data/demo-app/*`** and **`secret/metadata/demo-app/*`**) — versioned in Git. |
| **`bootstrap.sh`** | Enables **`secret`** KV v2 (if needed), **`auth enable kubernetes`** (if not already in server config), writes full **`auth/kubernetes/config`** (host + CA + token reviewer), applies the policy, creates roles **`external-secrets`** and **`default`** (wildcard SA/NS; tighten for production). |
| **Job** **`openbao-kubernetes-auth-bootstrap`** | Runs the script as **`ServiceAccount/openbao`**; root token from **`BAO_ROOT_TOKEN`** (**`secretKeyRef`**, optional) and/or mounted **`Secret/openbao-bootstrap`** key **`root-token`** (you create this; never commit it). **`restartPolicy: OnFailure`**. |
| **RBAC** | **`ClusterRoleBinding/openbao-auth-delegator`** → **`system:auth-delegator`** (TokenReview for **`auth/kubernetes`**; chart may also create **`openbao-server-binding`**). **`Role`** + **`RoleBinding`** so **`ServiceAccount/openbao`** can **`get`** **`Secret/openbao-bootstrap`**. |

**Operator steps (once per cluster / after init + unseal):**

1. **Create the bootstrap Secret** (never commit the root token to Git):

   ```bash
   kubectl create secret generic openbao-bootstrap -n openbao-system \
     --from-literal=root-token='YOUR_ROOT_TOKEN'
   ```

2. **If the Job already completed** without configuring auth (missing Secret, OpenBao still sealed, etc.), delete it so it runs again:

   ```bash
   kubectl delete job -n openbao-system openbao-kubernetes-auth-bootstrap
   ```

   Flux will recreate the Job on the next **`infrastructure`** reconcile, or run **`flux reconcile kustomization infrastructure -n flux-system --with-source`**.

3. **Verify:** `kubectl logs -n openbao-system job/openbao-kubernetes-auth-bootstrap` should end with **`OpenBao Kubernetes auth ready`**. **`ExternalSecret`** / **`PushSecret`** should leave **`ReplicaFailure`** once OpenBao accepts Kubernetes logins.

Until this succeeds, **`PushSecret`** / **`ExternalSecret`** for the demo app stay degraded; **`demo-api`** needs **`Secret/demo-app-postgres`**.

The OpenBao **injector** is optional for this app; the demo API does not use sidecar injection for DB credentials.

## HTTPS (Let’s Encrypt) and public hostnames

- **`ClusterIssuer/letsencrypt-prod`** lives under **`gitops/infrastructure/cert-manager-issuers/`** and uses **HTTP-01** with **`ingressClassName: traefik`**. Edit **`spec.acme.email`** in that manifest for a valid contact address for Let’s Encrypt. The **workers load balancer** must forward **TCP 80** (and **443** for clients) to Traefik NodePorts (see Terraform module defaults).
- **cert-manager** creates TLS Secrets referenced by **Ingress** `spec.tls` when you set the annotation **`cert-manager.io/cluster-issuer: letsencrypt-prod`**.
- **Demo app:** **`Ingress/demo-api`** in **`app-dev`** — host patched in **`gitops/applications/environments/dev/demo-app/`** (e.g. `demo-app.alissonmachado.com.br`), TLS secret **`demo-api-tls`**.
- **OpenBao:** **`Ingress/openbao`** in **`openbao-system`** — **`gitops/infrastructure/openbao-ingress/`**, host **`openbao.alissonmachado.com.br`**, TLS **`openbao-tls`**. In-cluster workloads should keep using **`http://openbao.openbao-system.svc.cluster.local:8200`**; exposing the UI/API on the Internet is high risk — restrict access in production. **Browser login:** after init/unseal, open **`https://openbao.alissonmachado.com.br/`** and sign in with **Token** (root token from **`bao operator init`**); see **[Operations → OpenBao web UI login](operations.md#openbao-web-ui-login)**.
- **OpenBao Helm (`gitops/operators/openbao/helmrelease.yaml`):** **`global.externalBaoAddr`** is the API URL for **injector/CSI when the server is not deployed by this chart** (non-empty forces **external** mode and skips the StatefulSet; pair with **`server.enabled: false`** and a real out-of-cluster OpenBao). For the **bundled standalone server** and public Ingress, leave **`externalBaoAddr`** empty and set **`api_addr`** in **`server.standalone.config`** to the same public **`https://`** URL so redirects and client identity match the browser hostname.
- **Grafana:** **`kube-prometheus-stack`** Helm values enable **`grafana.ingress`** (class **traefik**, host **`grafana.alissonmachado.com.br`**, TLS **`grafana-tls`**, **`grafana.ini.server.root_url`** set for correct redirects). Namespace **`monitoring`**. **How to read the Grafana admin password:** see **[Operations → Grafana admin password](operations.md#grafana-admin-password-kube-prometheus-stack)**.

Point **DNS A/AAAA** records for those hostnames at the **workers load balancer** address from Terraform. Let’s Encrypt validation requires **HTTP on port 80** to succeed from the public Internet.

## CI and image automation

The workflow **`.github/workflows/demo-app-image.yml`** pushes to **GHCR** using the GitHub owner name **lowercased** in the image path (`ghcr.io/<owner-lower>/demo-app`), because OCI repository names must be lowercase. Align **`ImageRepository`** / **`deployment`** image references with that path.

If **`image-automation.yaml`** is included in the dev **demo-app** overlay, Flux can watch container registries (e.g. GHCR) and commit image tag updates back to Git. Ensure the Git credentials Flux uses allow **push** if you use **ImageUpdateAutomation** (see **`ansible/README.md`** Flux variables).
