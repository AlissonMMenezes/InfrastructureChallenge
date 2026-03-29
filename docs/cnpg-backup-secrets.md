# CNPG S3 backup secret

CNPG expects **`Secret/cnpg-s3-credentials`** in the **same namespace** as the **`Cluster`**, keys **`ACCESS_KEY_ID`** and **`ACCESS_SECRET_KEY`** ([CNPG object stores](https://cloudnative-pg.io/documentation/current/appendixes/object_stores/)).

**Clusters in this repo:** `dev-postgres` → namespace **`postgres`**; `demo-app-db` → **`app-dev`**. Same bucket **`dev-test-cnpg-backups`**, different prefixes — see **`gitops/infrastructure/postgres/BACKUP.md`**.

**Create** (replace values; avoid logging secrets):

```bash
kubectl create secret generic cnpg-s3-credentials -n postgres \
  --from-literal=ACCESS_KEY_ID='...' \
  --from-literal=ACCESS_SECRET_KEY='...'
kubectl create secret generic cnpg-s3-credentials -n app-dev \
  --from-literal=ACCESS_KEY_ID='...' \
  --from-literal=ACCESS_SECRET_KEY='...'
```

**Rotate:** delete secret in namespace, recreate. Keys: Hetzner Console → Object Storage → S3 credentials.

**Verify:** `kubectl get secret cnpg-s3-credentials -n postgres` (and `app-dev`); `kubectl describe cluster <name> -n <ns>` for backup / WAL status.

Declarative: use **`stringData`** in a manifest only via SOPS/SealedSecrets/ESO — do not commit plaintext.
