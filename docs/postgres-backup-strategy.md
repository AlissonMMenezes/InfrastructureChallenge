# PostgreSQL backup strategy (CloudNativePG + Barman)

This repository uses **S3-compatible object storage** (Hetzner Object Storage) for **physical base backups** and **WAL archiving**.

**[Barman Cloud Plugin](https://cloudnative-pg.io/plugin-barman-cloud/docs/intro/)** is installed as an Operator to manage the backups (base backup + continuous archiving → **PITR**). 

The decision to use it, is because that is the solution recommended but hte CloudNativePG Documentation.

There are **two CNPG integration styles** in-tree:


| Cluster            | Namespace                        | How Barman talks to S3                                                                                                                                                                                              |
| ------------------ | -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `**dev-postgres`** | `postgres`                       | **Embedded** config on the `**Cluster`**: `**spec.backup.barmanObjectStore`** (classic CNPG).                                                                                                                       |
| `**demo-app-db**`  | `major-upgrade-app` or `app-dev` | **Barman Cloud CNPG-I plugin**: `**ObjectStore`** CR (`barmancloud.cnpg.io`) + `**Cluster.spec.plugins`** + `**HelmRelease/plugin-barman-cloud**` in `cnpg-system` (see `**environments/dev/kustomization.yaml**`). |


Both paths store data under the same bucket with **different prefixes** (`dev-postgres/`, `**major-upgrade-app/`**, `**demo-app-db/`**).** 



**Credentials are the same Kubernetes Secret shape: `**cnpg-s3-credentials`** in the cluster namespace — **[cnpg-backup-secrets](cnpg-backup-secrets.md)**.

---


| Concept                | Where it lives                                                                                                                                                                             |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Base (physical) backup | `**ScheduledBackup`** with `**method: plugin**` (plugin executes **barman-cloud** backup against the linked `**ObjectStore`**)                                                             |
| WAL archive            | Plugin sidecar / `**isWALArchiver`** using the same `**ObjectStore**` configuration                                                                                                        |
| Retention              | `**ObjectStore.spec.retentionPolicy**` (+ bucket lifecycle if you add it)                                                                                                                  |
| Credentials            | `**ObjectStore.spec.configuration.s3Credentials**` → `**Secret/cnpg-s3-credentials**` (same keys as classic CNPG)                                                                          |
| Operator view          | `**kubectl get backup,scheduledbackup**`, `**kubectl get objectstore**`, `**kubectl describe cluster demo-app-db**` in `**major-upgrade-app**` or `**app-dev**` (match the active overlay) |


---

## Policy checklist

- Use Barman terminology consistently: **base backup**, **WAL**, **PITR**, **retention**.
- Write down **RPO/RTO** and **restore tests** (frequency, owner, success criteria).
- Align `**retentionPolicy`** (per path above), **backup schedule**, and bucket lifecycle with that policy.
- Watch **backup** and **WAL archive** health (`Backup` phases, CNPG status, alerts); fix failed archives before RPO slips.
- Rotate object-store keys via **[cnpg-backup-secrets](cnpg-backup-secrets.md)** (update `**Secret`**, ensure `**ObjectStore`** / `**Cluster**` still reference the same secret name).

**Runbooks:** **[operations — Backups & Barman](operations.md#backups-cnpg)** (YAML snippets + checks) · **[Restore](operations.md#restore)** · [`gitops/infrastructure/postgres/BACKUP.md`](../gitops/infrastructure/postgres/BACKUP.md) · **Upgrades:** **[postgres-upgrade-strategy](postgres-upgrade-strategy.md)**.