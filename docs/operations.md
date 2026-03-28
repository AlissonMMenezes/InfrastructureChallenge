# Operations lifecycle

For provisioning and GitOps bootstrap order, see **[Getting started](getting-started.md)**.

## Backup strategy

- CloudNativePG `ScheduledBackup` runs periodic backups.
- Destination: S3-compatible object storage (`s3://cnpg-backups/<env>`).
- Recommended schedule:
  - Full/base backup daily
  - WAL archival continuous

## Restore procedure (high level)

1. Pause writes from dependent applications.
2. Create a new `Cluster` manifest with `bootstrap.recovery` from backup.
3. Verify data consistency checks.
4. Switch service endpoint or update app secret/connection details.
5. Resume traffic.

## Monitoring

- CloudNativePG emits metrics; service monitors are enabled.
- Prometheus alerts cover:
  - replication lag,
  - backup failures,
  - pod restarts,
  - PVC saturation,
  - failover events.

## Upgrades

- Minor PostgreSQL upgrades performed by updating image tags in Git.
- Flux CD reconciles manifest changes; CNPG orchestrates rolling restarts.
- Pre-checks:
  - recent successful backup,
  - low replication lag,
  - maintenance window active.

## Scaling

- Vertical: adjust resource requests/limits and storage classes.
- Horizontal for DB: add replicas where topology supports.
- App scaling: HPA on CPU/memory or custom metrics.
