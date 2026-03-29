# CNPG S3 backup secret

Workloads that talk to S3 for Postgres backups need `**Secret/cnpg-s3-credentials**` in the **same namespace** as the `**Cluster`**, with keys `**ACCESS_KEY_ID**` and `**ACCESS_SECRET_KEY**`.



**Barman Cloud plugin** (`demo-app-db`): the `**ObjectStore`** CR references the same secret name/keys under `**spec.configuration.s3Credentials**` — the Secret shape is unchanged.



**Create** (replace values; avoid logging secrets):

```bash
kubectl create secret generic cnpg-s3-credentials -n postgres \
  --from-literal=ACCESS_KEY_ID='...' \
  --from-literal=ACCESS_SECRET_KEY='...'
kubectl create secret generic cnpg-s3-credentials -n major-upgrade-app \
  --from-literal=ACCESS_KEY_ID='...' \
  --from-literal=ACCESS_SECRET_KEY='...'
# If using the demo-app overlay instead: use namespace app-dev.
```

**Rotate:** delete the secret in the namespace, recreate. Keys: Hetzner Console → Object Storage → S3 credentials.