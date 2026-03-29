# PostgreSQL backup strategy

CloudNativePG here stores **physical base backups** and **archived WAL** in S3-compatible object storage (`barmanObjectStore`). That matches the model described in **[Barman](https://docs.pgbarman.org/)** (base backup + continuous archiving → **PITR**). Use **[docs.pgbarman.org](https://docs.pgbarman.org/)** when you define **RPO/RTO**, retention, and recovery runbooks—not only when editing manifests.

## Barman concepts → this repo

| Concept | Where it lives |
|---------|----------------|
| Base (physical) backup | **`ScheduledBackup`**, `method: barmanObjectStore` |
| WAL archive | **`Cluster.spec.backup.barmanObjectStore`** |
| Retention window | **`Cluster.spec.backup.retentionPolicy`** + bucket lifecycle (if any) |
| Credentials | **`Secret/cnpg-s3-credentials`** — **[cnpg-backup-secrets](cnpg-backup-secrets.md)** |
| Operator view of runs | **`Backup`** CRs, **`kubectl describe cluster …`** |

**Commands and Git layout:** **[operations — Backups](operations.md#backups-cnpg)**, **`gitops/infrastructure/postgres/BACKUP.md`**. **Upgrades:** **[postgres-upgrade-strategy](postgres-upgrade-strategy.md)**.

## Policy checklist

- Adopt shared terms from the Barman manual: **base backup**, **WAL**, **PITR**, **retention**.
- Write down **RPO/RTO** and **restore tests** (frequency, owner, success criteria).
- Match **`retentionPolicy`**, backup schedule, and bucket rules to that policy and compliance.
- Watch CNPG backup/archive status and alerts; fix failed archives before RPO slips.
- Rotate object-store keys via the Secret workflow in **[cnpg-backup-secrets](cnpg-backup-secrets.md)**.
