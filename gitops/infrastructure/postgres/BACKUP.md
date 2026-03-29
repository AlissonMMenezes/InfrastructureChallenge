# CNPG backups (Hetzner Object Storage)

**Bucket:** **`dev-test-cnpg-backups`** (Terraform object-storage module in dev). **Prefixes:** **`dev-postgres/`**, **`major-upgrade-app/`** ( **`major-upgrade-app`** namespace / overlay), **`demo-app-db/`** (**`demo-app`** overlay / **`app-dev`**).

**Secret:** **`cnpg-s3-credentials`** in each namespace — keys **`ACCESS_KEY_ID`**, **`ACCESS_SECRET_KEY`** — **[`docs/cnpg-backup-secrets.md`](../../docs/cnpg-backup-secrets.md)**. **Strategy & restore concepts:** **[`docs/postgres-backup-strategy.md`](../../docs/postgres-backup-strategy.md)**. **Upgrades:** **[`docs/postgres-upgrade-strategy.md`](../../docs/postgres-upgrade-strategy.md)**.

---

## `dev-postgres` (namespace `postgres`) — classic CNPG

- **`Cluster`:** `cluster.yaml` — **`spec.backup.barmanObjectStore`** (destination path, endpoint, compression, credentials).
- **`ScheduledBackup`:** `scheduledbackup.yaml` — **`method: barmanObjectStore`**.

WAL archiving and scheduled base backups use the **built-in** CNPG Barman object-store integration (no separate **`ObjectStore`** CR).

**Restore:** follow **[CNPG recovery](https://cloudnative-pg.io/documentation/current/recovery/)** using the same bucket prefix and **`bootstrap.recovery`** from a **`Backup`** or PITR target. Operational outline: **[`docs/operations.md`](../../docs/operations.md#restore)**.

---

## `demo-app-db` (namespace `major-upgrade-app` or `app-dev`) — Barman Cloud CNPG-I plugin

Requires **`HelmRelease/plugin-barman-cloud`** in **`cnpg-system`** (`gitops/operators/plugin-barman-cloud/`) and **cert-manager**.

| Piece | Git path |
|-------|-----------|
| **`ObjectStore`** CR | Base: `gitops/applications/base/postgres-cluster/objectstore.yaml` · Patches: **`major-upgrade-app/patches/postgres-objectstore-metadata.yaml`** or **`demo-app/patches/...`** |
| **`Cluster`** plugins | Base: `postgres-cluster/cluster.yaml` · Overlay: **`postgres-cluster-spec.yaml`** |
| **`ScheduledBackup`** | **`major-upgrade-app/cnpg-scheduledbackup.yaml`** or **`demo-app/cnpg-scheduledbackup.yaml`** — **`method: plugin`**, **`pluginConfiguration.name: barman-cloud.cloudnative-pg.io`** |

**Backup flow:** CNPG triggers backups through the **plugin**; the plugin reads **`ObjectStore.spec.configuration`** (S3 path, credentials secret, WAL/data options) and uses **barman-cloud** tooling. WAL archiving is enabled via **`isWALArchiver: true`** on the plugin entry.

**Restore:** keep **`spec.plugins`** and an **`ObjectStore`** that points at the **same** bucket layout you are recovering from, then use CNPG **`bootstrap.recovery`** as documented for your version. See **[Barman Cloud plugin docs](https://cloudnative-pg.io/plugin-barman-cloud/)** and **[`docs/postgres-backup-strategy.md`](../../docs/postgres-backup-strategy.md)** (section B).

---

## Quick secret (imperative)

```bash
kubectl create secret generic cnpg-s3-credentials -n postgres \
  --from-literal=ACCESS_KEY_ID='...' --from-literal=ACCESS_SECRET_KEY='...'
kubectl create secret generic cnpg-s3-credentials -n major-upgrade-app \
  --from-literal=ACCESS_KEY_ID='...' --from-literal=ACCESS_SECRET_KEY='...'
# demo-app overlay: repeat for namespace app-dev
```

## Sanity checks

```bash
kubectl get scheduledbackup,backup -n postgres
kubectl describe cluster dev-postgres -n postgres

kubectl get objectstore,scheduledbackup,backup -n major-upgrade-app
kubectl describe cluster demo-app-db -n major-upgrade-app
```

**Schedules in Git** use a **6-field cron** (includes seconds); dev cadence is aggressive — tighten for production.
