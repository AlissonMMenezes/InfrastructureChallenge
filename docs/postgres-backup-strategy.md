# PostgreSQL backup strategy (CloudNativePG + Barman)

This repository uses **S3-compatible object storage** (Hetzner Object Storage, bucket layout in **`gitops/infrastructure/postgres/BACKUP.md`**) for **physical base backups** and **WAL archiving**, following **[Barman](https://docs.pgbarman.org/)** ideas (base backup + continuous archiving → **PITR**). Use **[docs.pgbarman.org](https://docs.pgbarman.org/)** when you define **RPO/RTO**, retention, and recovery runbooks.

There are **two CNPG integration styles** in-tree:

| Cluster | Namespace | How Barman talks to S3 |
|---------|-----------|-------------------------|
| **`dev-postgres`** | `postgres` | **Embedded** config on the **`Cluster`**: **`spec.backup.barmanObjectStore`** (classic CNPG). |
| **`demo-app-db`** | `app-dev` | **Barman Cloud CNPG-I plugin**: **`ObjectStore`** CR (`barmancloud.cnpg.io`) + **`Cluster.spec.plugins`** + **`HelmRelease/plugin-barman-cloud`** in `cnpg-system`. |

Both paths store data under the same bucket with **different prefixes** (`dev-postgres/`, `demo-app-db/`). Credentials are the same **Kubernetes Secret** shape: **`cnpg-s3-credentials`** in the cluster namespace — **[cnpg-backup-secrets](cnpg-backup-secrets.md)**.

---

## A. `dev-postgres` — embedded `barmanObjectStore`

| Concept | Where it lives |
|---------|----------------|
| Base (physical) backup | **`ScheduledBackup`**, **`method: barmanObjectStore`** — `gitops/infrastructure/postgres/scheduledbackup.yaml` |
| WAL archive | **`Cluster.spec.backup.barmanObjectStore`** — `gitops/infrastructure/postgres/cluster.yaml` |
| Retention | **`Cluster.spec.backup.retentionPolicy`** + bucket lifecycle (if any) |
| Operator / runs | **`Backup`** CRs, **`kubectl describe cluster dev-postgres -n postgres`** |

**Restore (outline):** stop writers → new **`Cluster`** with **`bootstrap.recovery`** from a **`Backup`** or point-in-time target → verify → repoint apps → resume. Follow **[CNPG recovery](https://cloudnative-pg.io/documentation/current/recovery/)** for your operator version.

---

## B. `demo-app-db` — Barman Cloud plugin + `ObjectStore`

Components:

1. **`HelmRelease/plugin-barman-cloud`** (`gitops/operators/plugin-barman-cloud/`) — CNPG-I plugin deployment in **`cnpg-system`** (needs **cert-manager** and **CloudNativePG ≥ 1.26**).
2. **`ObjectStore`** (`barmancloud.cnpg.io/v1`) — S3 **destination**, WAL/data compression, **`spec.retentionPolicy`**. Base: `gitops/applications/base/postgres-cluster/objectstore.yaml`; dev renames/prefix patch: `gitops/applications/environments/dev/<overlay>/patches/postgres-objectstore-metadata.yaml` (e.g. **`major-upgrade-app`** or **`demo-app`**).
3. **`Cluster.spec.plugins`** — entry **`name: barman-cloud.cloudnative-pg.io`**, **`isWALArchiver: true`**, **`parameters.barmanObjectName`** = **`ObjectStore` metadata.name** (same namespace as the **`Cluster`**). Base + dev spec patch: `postgres-cluster/cluster.yaml`, `.../patches/postgres-cluster-spec.yaml`.
4. **`ScheduledBackup`**, **`method: plugin`**, **`pluginConfiguration.name: barman-cloud.cloudnative-pg.io`** — `gitops/applications/environments/dev/<overlay>/cnpg-scheduledbackup.yaml` (same file in **`demo-app/`** and **`major-upgrade-app/`**).

| Concept | Where it lives |
|---------|----------------|
| Base (physical) backup | **`ScheduledBackup`** with **`method: plugin`** (plugin executes **barman-cloud** backup against the linked **`ObjectStore`**) |
| WAL archive | Plugin sidecar / **`isWALArchiver`** using the same **`ObjectStore`** configuration |
| Retention | **`ObjectStore.spec.retentionPolicy`** (+ bucket lifecycle if you add it) |
| Credentials | **`ObjectStore.spec.configuration.s3Credentials`** → **`Secret/cnpg-s3-credentials`** (same keys as classic CNPG) |
| Operator view | **`kubectl get backup,scheduledbackup -n app-dev`**, **`kubectl get objectstore -n app-dev`**, **`kubectl describe cluster demo-app-db -n app-dev`** |

**Restore (outline):** treat recovery like any CNPG cluster from object storage, but the **declarative** side must include the **same plugin + `ObjectStore`** (or equivalent recovery stanza) so the instance manager can read **barman-cloud** layout in the bucket. Typical flow: **pause writers** → define a **new** **`Cluster`** (or clone) with **`bootstrap.recovery`** from a **`Backup`** CR or recovery source that matches your scenario → **verify** data → **point `demo-api`** at the new DB URI if the service name changed → resume traffic. Authoritative procedure: **[CNPG recovery](https://cloudnative-pg.io/documentation/current/recovery/)** and **[Barman Cloud plugin](https://cloudnative-pg.io/plugin-barman-cloud/)** docs for plugin-specific fields.

---

## Policy checklist

- Use Barman terminology consistently: **base backup**, **WAL**, **PITR**, **retention**.
- Write down **RPO/RTO** and **restore tests** (frequency, owner, success criteria).
- Align **`retentionPolicy`** (per path above), **backup schedule**, and bucket lifecycle with that policy.
- Watch **backup** and **WAL archive** health (`Backup` phases, CNPG status, alerts); fix failed archives before RPO slips.
- Rotate object-store keys via **[cnpg-backup-secrets](cnpg-backup-secrets.md)** (update **`Secret`**, ensure **`ObjectStore`** / **`Cluster`** still reference the same secret name).

**Runbooks:** **[operations — Backups](operations.md#backups-cnpg)** · **[Restore](operations.md#restore)** · **`gitops/infrastructure/postgres/BACKUP.md`** · **Upgrades:** **[postgres-upgrade-strategy](postgres-upgrade-strategy.md)**.
