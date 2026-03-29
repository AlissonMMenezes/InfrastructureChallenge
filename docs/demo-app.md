# Demo app (`demo-api`)

**Code:** `demo-app/` — Go, **`cmd/demo-api`**, **`internal/{config,db,httpserver}`** (embedded templates + OpenAPI). **Image:** `.github/workflows/demo-app-image.yml` → **GHCR** `ghcr.io/<owner-lower>/demo-app`.

**GitOps:** base `gitops/applications/base/demo-app/`; dev overlay is selected in **`gitops/applications/environments/dev/kustomization.yaml`** (currently **`major-upgrade-app/`** — Postgres **17** operand; **`demo-app/`** is an alternate overlay with the same layout).

## HTTP

| Path | Purpose |
|------|---------|
| `GET /` | HTML dashboard + form |
| `POST /demo/item` | Form → insert → redirect `/` |
| `GET /healthz` | `{"status":"ok"}` |
| `GET/POST /items` | JSON |
| `GET /api/docs`, `/api/openapi.json` | Swagger |
| `GET /metrics` | Prometheus |

Boot: **`CREATE TABLE IF NOT EXISTS items`**.

## Postgres

1. CNPG **`Cluster/demo-app-db`** in **`app-dev`** — operand image **`spec.imageName`** (e.g. **`ghcr.io/cloudnative-pg/postgresql:17.6-system-trixie`** in **`gitops/applications/environments/dev/major-upgrade-app/patches/postgres-cluster-spec.yaml`** when that overlay is active).  
2. **Barman Cloud (CNPG-I):** **`ObjectStore/demo-app-db-store`** (`barmancloud.cnpg.io`) in **`app-dev`** holds S3 path (**`s3://dev-test-cnpg-backups/demo-app-db/`**), credentials, WAL/data options. **`Cluster.spec.plugins`** references **`barman-cloud.cloudnative-pg.io`** and **`parameters.barmanObjectName: demo-app-db-store`**. Base + patches: **`gitops/applications/base/postgres-cluster/`**, **`gitops/applications/environments/dev/<overlay>/patches/`** (same patch set under **`demo-app/`** or **`major-upgrade-app/`**).  
3. **`ScheduledBackup/demo-app-db-daily`** — **`method: plugin`**, **`pluginConfiguration.name: barman-cloud.cloudnative-pg.io`**. Requires **`HelmRelease/plugin-barman-cloud`** in **`cnpg-system`**.  
4. **`Secret/demo-app-db-app`**, key **`uri`**.  
5. **`Deployment`** sets **`DATABASE_URL`** from that secret.  
6. App uses **`DATABASE_URL`** or **`DB_*`** + **`DB_SSLMODE`** for local runs. **`LISTEN_ADDR`** default **`:8080`**.  

Upgrade path for Postgres: **[postgres-upgrade-strategy](postgres-upgrade-strategy.md)**. Backup / restore model: **[postgres-backup-strategy](postgres-backup-strategy.md)**, **[operations](operations.md#backups-cnpg)**.

Until the secret exists, pods may stay **CreateContainerConfigError**. Network: **`network-policy-demo-api-allow.yaml`**.

**Local:** `go run ./cmd/demo-api` from `demo-app/` without `DATABASE_URL` (defaults to localhost Postgres).

**Backups:** S3 prefix **`demo-app-db/`** via **`ObjectStore`** + plugin; Secret **`cnpg-s3-credentials`** in **`app-dev`** — **[cnpg-backup-secrets](cnpg-backup-secrets.md)**.
