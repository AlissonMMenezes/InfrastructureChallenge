# CNPG S3 backup secret

Workloads that talk to S3 for Postgres backups need **`Secret/cnpg-s3-credentials`** in the **same namespace** as the **`Cluster`**, with keys **`ACCESS_KEY_ID`** and **`ACCESS_SECRET_KEY`**.

- **Classic CNPG** (`dev-postgres`): referenced from **`Cluster.spec.backup.barmanObjectStore.s3Credentials`** ([object stores appendix](https://cloudnative-pg.io/documentation/current/appendixes/object_stores/)).
- **Barman Cloud plugin** (`demo-app-db`): the **`ObjectStore`** CR references the same secret name/keys under **`spec.configuration.s3Credentials`** — the Secret shape is unchanged.

**Clusters in this repo:** `dev-postgres` → namespace **`postgres`**; `demo-app-db` → **`app-dev`**. Same bucket **`dev-test-cnpg-backups`**, different prefixes — **`gitops/infrastructure/postgres/BACKUP.md`**, **[postgres-backup-strategy](postgres-backup-strategy.md)**.

**Create** (replace values; avoid logging secrets):

```bash
kubectl create secret generic cnpg-s3-credentials -n postgres \
  --from-literal=ACCESS_KEY_ID='...' \
  --from-literal=ACCESS_SECRET_KEY='...'
kubectl create secret generic cnpg-s3-credentials -n app-dev \
  --from-literal=ACCESS_KEY_ID='...' \
  --from-literal=ACCESS_SECRET_KEY='...'
```

**Rotate:** delete the secret in the namespace, recreate. Keys: Hetzner Console → Object Storage → S3 credentials.

**Verify:** `kubectl get secret cnpg-s3-credentials -n postgres` (and `app-dev`); `kubectl describe cluster dev-postgres -n postgres` and `kubectl describe cluster demo-app-db -n app-dev`; for the plugin path also `kubectl get objectstore -n app-dev`.

Declarative: use **`stringData`** in a manifest only via SOPS/SealedSecrets/ESO — do not commit plaintext.
