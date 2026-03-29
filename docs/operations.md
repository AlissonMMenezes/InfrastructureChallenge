# Operations

Provisioning order: **[getting-started](getting-started.md)**.

## Backups (CNPG)

Clusters **`dev-postgres`** (`postgres`) and **`demo-app-db`** (`app-dev`) use bucket **`dev-test-cnpg-backups`** with prefixes **`dev-postgres/`** and **`demo-app-db/`**. Endpoint URLs in Git must match your Hetzner region (e.g. `fsn1`).

Create **`Secret/cnpg-s3-credentials`** (keys **`ACCESS_KEY_ID`**, **`ACCESS_SECRET_KEY`**) in **`postgres`** and **`app-dev`**: **[cnpg-backup-secrets](cnpg-backup-secrets.md)**, **`gitops/infrastructure/postgres/BACKUP.md`**.

**Two models (see [postgres-backup-strategy](postgres-backup-strategy.md)):**

- **`dev-postgres`:** classic CNPG **`spec.backup.barmanObjectStore`** + **`ScheduledBackup`** (`method: barmanObjectStore`). Manifests under **`gitops/infrastructure/postgres/`**.
- **`demo-app-db`:** **[Barman Cloud CNPG-I plugin](https://cloudnative-pg.io/plugin-barman-cloud/)** — **`ObjectStore`** CR + **`Cluster.spec.plugins`** (`barman-cloud.cloudnative-pg.io`) + **`ScheduledBackup`** (`method: plugin`). Operator: **`HelmRelease/plugin-barman-cloud`** (`gitops/operators/plugin-barman-cloud/`). App manifests: **`gitops/applications/base/postgres-cluster/`** + dev overlay (**`gitops/applications/environments/dev/major-upgrade-app/`** or **`demo-app/`** — same patches; active overlay is listed in **`environments/dev/kustomization.yaml`**).

**Quick checks**

```bash
# Shared / classic cluster
kubectl get scheduledbackup,backup -n postgres
kubectl describe cluster dev-postgres -n postgres

# Demo app — plugin path
kubectl get objectstore,scheduledbackup,backup -n app-dev
kubectl describe cluster demo-app-db -n app-dev
kubectl get helmrelease plugin-barman-cloud -n cnpg-system
```

**Policy:** retention, RPO/RTO, and restore testing — **[postgres-backup-strategy](postgres-backup-strategy.md)**.

## Restore

High-level flow for **both** paths: **stop application writers** (scale deployment or block traffic) → **recover into a `Cluster`** from object storage (or from a **`Backup`** CR) per **[CNPG recovery](https://cloudnative-pg.io/documentation/current/recovery/)** → **verify** (read-only queries, app smoke test) → **point apps** at the recovered DB (**`Secret`** / service name if changed) → **resume** traffic.

### dev-postgres (embedded `barmanObjectStore`)

Recovery **`bootstrap`** stanzas reference the same bucket/prefix and credential pattern as **`Cluster.spec.backup`**. Use **`kubectl get backup -n postgres`** and CNPG docs for **`bootstrap.recovery`** from backup / PITR.

### demo-app-db (Barman Cloud plugin)

Recovery must remain consistent with the **plugin + `ObjectStore`** model: the replacement **`Cluster`** should declare the same **`spec.plugins`** (and an **`ObjectStore`** that matches the bucket path you are restoring from) so WAL and base backups remain readable by **barman-cloud**. Do **not** mix a recovery cluster that only has legacy **`spec.backup.barmanObjectStore`** if the data in the bucket was written by the plugin path unless you are following a documented CNPG migration. Prefer creating **`Backup`** objects from healthy schedules before disaster, and restoring from those per CNPG.

Details and file pointers: **[postgres-backup-strategy](postgres-backup-strategy.md)**, **`gitops/infrastructure/postgres/BACKUP.md`**.

## Postgres upgrades

**[postgres-upgrade-strategy](postgres-upgrade-strategy.md)** (operator chart, operand image, parameters). Follow [CNPG upgrading](https://cloudnative-pg.io/documentation/current/upgrading/) for your operator version.

## Monitoring

**kube-prometheus-stack**: Prometheus, Alertmanager, Grafana. Flux dashboards in Grafana **Flux** folder if enabled in Helm values. CNPG metrics where **`enablePodMonitor`** is set. Operator layout and PodMonitors: **[monitoring-stack.md](monitoring-stack.md)**.

**Grafana admin password** (default release name, namespace `monitoring`):

```bash
kubectl get secrets -n monitoring -l app.kubernetes.io/name=grafana
kubectl get secret -n monitoring kube-prometheus-stack-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

## TLS

`kubectl get certificate -A`. If ACME fails: DNS → LB, port **80** reachable, issuer **Ready**.

## OpenBao

- **Ingress** is sensitive; in-cluster clients should use **`http://openbao.openbao-system.svc.cluster.local:8200`** where possible.
- **Init / unseal:** GitOps Job **`openbao-init-store-keys`** or manual `bao operator init` / `bao operator unseal` on pod **`openbao-0`** (see [OpenBao docs](https://openbao.org/docs/)). Same PVC: unseal after restart; do not re-init.
- **ESO:** After **`Secret/openbao-bootstrap`** exists, Job **`openbao-kubernetes-auth-bootstrap`** configures **`auth/kubernetes`**. Retry: delete the Job; Flux recreates it.
- **UI login:** HTTPS ingress host → sign in with **Token** (root token from init — not the unseal key). If **403**: wrong token, sealed server, or `api_addr` mismatch vs browser URL.

## Upgrades / scaling

Postgres: Git + Flux; watch backups and lag before changes. Apps: HPA / replica counts in Git. Nodes: Terraform + Ansible alignment.
