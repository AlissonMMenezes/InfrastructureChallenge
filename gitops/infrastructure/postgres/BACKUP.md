# CloudNativePG backups → Hetzner Object Storage

Clusters **`dev-postgres`** (namespace **`postgres`**) and **`demo-app-db`** (namespace **`app-dev`**) archive WAL and base backups to bucket **`dev-test-cnpg-backups`** under separate prefixes (`dev-postgres/`, `demo-app-db/`).

**Step-by-step: creating S3 keys and the `cnpg-s3-credentials` Secret** → **[`docs/cnpg-backup-secrets.md`](../../docs/cnpg-backup-secrets.md)**.  
**Upgrades (operator / Postgres / parameters)** → **[`docs/postgres-upgrade-strategy.md`](../../docs/postgres-upgrade-strategy.md)**.

## Prerequisites

1. **Bucket** exists (e.g. Terraform **`object_storage_enabled = true`** in **`terraform/environments/dev`**, which defaults the bucket name to **`dev-test-cnpg-backups`** when **`cluster_name`** is **`dev-test`**).
2. **S3 credentials** with read/write/list/delete on that bucket.
3. **`endpointURL`** matches your Hetzner object storage region (here **`fsn1`** → **`https://fsn1.your-objectstorage.com`**). If you use another region, change **`endpointURL`** in both **`Cluster`** manifests and recreate/reload instances if needed.

## Kubernetes Secret (not stored in Git)

Create **`Secret/cnpg-s3-credentials`** in **`postgres`** and **`app-dev`** — see **[`docs/cnpg-backup-secrets.md`](../../docs/cnpg-backup-secrets.md)** for Hetzner console steps, **`kubectl`** commands, rotation, and a declarative **`stringData`** example.

Quick copy-paste (same key names the **`Cluster`** manifests reference):

```bash
kubectl create secret generic cnpg-s3-credentials -n postgres \
  --from-literal=ACCESS_KEY_ID='<hetzner-s3-access-key>' \
  --from-literal=ACCESS_SECRET_KEY='<hetzner-s3-secret-key>'

kubectl create secret generic cnpg-s3-credentials -n app-dev \
  --from-literal=ACCESS_KEY_ID='<hetzner-s3-access-key>' \
  --from-literal=ACCESS_SECRET_KEY='<hetzner-s3-secret-key>'
```

Key names **`ACCESS_KEY_ID`** and **`ACCESS_SECRET_KEY`** match the [CloudNativePG S3 credential convention](https://cloudnative-pg.io/documentation/current/appendixes/object_stores/).

Until this secret exists, the operator may report backup/WAL archive errors; Postgres can still run.

## What GitOps applies

| Resource | Role |
|----------|------|
| **`Cluster.spec.backup.barmanObjectStore`** | WAL archive + base backup destination, retention **30d**. |
| **`ScheduledBackup`** | Base backup every **5 minutes** (`0 */5 * * * *` — dev/demo only; use a lower frequency in production). |

## Verify

```bash
kubectl get scheduledbackup -n postgres
kubectl get backup -n postgres
kubectl describe cluster dev-postgres -n postgres
```

For **`demo-app-db`**, use namespace **`app-dev`**.
