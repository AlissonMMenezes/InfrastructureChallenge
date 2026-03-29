# CNPG backups (Hetzner Object Storage)

**Clusters:** `dev-postgres` (`postgres`), `demo-app-db` (`app-dev`) → bucket **`dev-test-cnpg-backups`**, prefixes **`dev-postgres/`**, **`demo-app-db/`**.

**Secret:** **`cnpg-s3-credentials`** in each namespace — **[`docs/cnpg-backup-secrets.md`](../../docs/cnpg-backup-secrets.md)**. **Upgrades:** **[`docs/postgres-upgrade-strategy.md`](../../docs/postgres-upgrade-strategy.md)**.

**GitOps:** `Cluster.spec.backup.barmanObjectStore` + **ScheduledBackup** (dev cadence in repo is aggressive — relax for prod).

**Quick secret:**

```bash
kubectl create secret generic cnpg-s3-credentials -n postgres \
  --from-literal=ACCESS_KEY_ID='...' --from-literal=ACCESS_SECRET_KEY='...'
kubectl create secret generic cnpg-s3-credentials -n app-dev \
  --from-literal=ACCESS_KEY_ID='...' --from-literal=ACCESS_SECRET_KEY='...'
```

**Check:** `kubectl get scheduledbackup,backup -n postgres` (and `app-dev`); `kubectl describe cluster dev-postgres -n postgres`.
