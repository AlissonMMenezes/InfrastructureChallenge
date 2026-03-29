# Creating Kubernetes Secrets for CloudNativePG S3 backups

CloudNativePG needs **S3-compatible credentials** in the **same namespace** as each **`Cluster`** that uses **`spec.backup.barmanObjectStore`**. This repo expects a **`Secret`** named **`cnpg-s3-credentials`** with two keys used by the [AWS-style credential layout](https://cloudnative-pg.io/documentation/current/appendixes/object_stores/#aws-access-key) Barman Cloud understands.

GitOps manifests (bucket **`dev-test-cnpg-backups`**, Hetzner endpoint) live under **`gitops/`** — see **[`gitops/infrastructure/postgres/BACKUP.md`](../gitops/infrastructure/postgres/BACKUP.md)** for the full backup layout and verification commands.

## 1. Obtain Hetzner Object Storage S3 keys

1. Open the [Hetzner Cloud Console](https://console.hetzner.cloud/).
2. Select your project → **Security** → **Object Storage** (or **Storage** → **Object Storage**, depending on UI version).
3. Create or select a **bucket** (e.g. **`dev-test-cnpg-backups`**) in a region that matches your **`Cluster`** `endpointURL` (this repo uses **`fsn1`** → **`https://fsn1.your-objectstorage.com`**).
4. Create **S3 credentials** (access key + secret key).  
   Official guide: [Generating S3 keys](https://docs.hetzner.com/storage/object-storage/getting-started/generating-s3-keys).

The access key must be allowed to **read, write, list, and delete** objects in that bucket (backup retention deletes old objects).

**Optional:** If you use Terraform in **`terraform/environments/dev`**, enable **`object_storage_enabled`** and set **`object_storage_access_key`** / **`object_storage_secret_key`** (see **`dev.auto.tfvars.example`**) so Terraform can create the bucket; you still create the **Kubernetes** `Secret` yourself (Terraform does not push credentials into the cluster).

## 2. Create the Secret in each namespace

This repository configures **two** CNPG clusters with S3 backup:

| Cluster        | Namespace   |
|----------------|-------------|
| **`dev-postgres`** | **`postgres`** |
| **`demo-app-db`**  | **`app-dev`**  |

Use the **same** S3 keys in both secrets unless you intentionally use different IAM-style policies per workload.

### Using `kubectl` (recommended)

Replace the placeholders with your real keys (avoid shell history logging in shared environments — prefer **`read -s`** or a secrets manager).

```bash
export HETZNER_S3_ACCESS_KEY='your-access-key-id'
export HETZNER_S3_SECRET_KEY='your-secret-access-key'

kubectl create secret generic cnpg-s3-credentials -n postgres \
  --from-literal=ACCESS_KEY_ID="$HETZNER_S3_ACCESS_KEY" \
  --from-literal=ACCESS_SECRET_KEY="$HETZNER_S3_SECRET_KEY"

kubectl create secret generic cnpg-s3-credentials -n app-dev \
  --from-literal=ACCESS_KEY_ID="$HETZNER_S3_ACCESS_KEY" \
  --from-literal=ACCESS_SECRET_KEY="$HETZNER_S3_SECRET_KEY"

unset HETZNER_S3_ACCESS_KEY HETZNER_S3_SECRET_KEY
```

**Required key names inside the Secret** (CNPG / Barman expect these exact keys):

- **`ACCESS_KEY_ID`**
- **`ACCESS_SECRET_KEY`**

### If the Secret already exists

Kubernetes rejects **`kubectl create`** when the object exists. Update in place:

```bash
kubectl delete secret cnpg-s3-credentials -n postgres
kubectl create secret generic cnpg-s3-credentials -n postgres \
  --from-literal=ACCESS_KEY_ID='...' \
  --from-literal=ACCESS_SECRET_KEY='...'
```

Repeat for **`app-dev`** if needed. After rotation, you may need to **reload** CNPG pods so they pick up the new Secret (see [CloudNativePG reload](https://cloudnative-pg.io/documentation/current/operator_conf/#reloading-secrets) / `kubectl cnpg reload` if you use the plugin).

## 3. Check that the Secret is present

```bash
kubectl get secret cnpg-s3-credentials -n postgres
kubectl get secret cnpg-s3-credentials -n app-dev
```

You should see **`Opaque`** secrets; do **not** commit their contents to Git.

## 4. Confirm backups are progressing

```bash
kubectl get scheduledbackup,backup -n postgres
kubectl get scheduledbackup,backup -n app-dev
kubectl describe cluster dev-postgres -n postgres
kubectl describe cluster demo-app-db -n app-dev
```

Look for healthy **continuous archiving** / **backup** status in the **`Cluster`** status. If credentials are wrong, status and operator logs will mention S3 / authentication errors.

## 5. Declarative alternative (YAML)

You can apply a **`Secret`** manifest if you generate it safely (e.g. **SOPS**, **Sealed Secrets**, **External Secrets**). The data values must be **base64-encoded** as usual for Kubernetes:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: cnpg-s3-credentials
  namespace: postgres   # or app-dev
type: Opaque
stringData:
  ACCESS_KEY_ID: "your-access-key"
  ACCESS_SECRET_KEY: "your-secret-key"
```

Using **`stringData`** avoids manual base64. **Do not** commit real values.

---

**Related:** [`gitops/infrastructure/postgres/BACKUP.md`](../gitops/infrastructure/postgres/BACKUP.md) · [Operations → Backup strategy](operations.md#backup-strategy)
