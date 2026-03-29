# Demo app (`demo-api`)

**Code:** `demo-app/` — Go, **`cmd/demo-api`**, **`internal/{config,db,httpserver}`** (embedded templates + OpenAPI). **Image:** `.github/workflows/demo-app-image.yml` → **GHCR** `ghcr.io/<owner-lower>/demo-app`.

**GitOps:** base `gitops/applications/base/demo-app/`; dev overlay is selected in **`gitops/applications/environments/dev/kustomization.yaml`**. **`major-upgrade-app/`** uses namespace **`major-upgrade-app`**, Postgres **17**, S3 prefix **`major-upgrade-app/`**; **`demo-app/`** uses **`app-dev`** and prefix **`demo-app-db/`**. Flux **ImageRepository/ImagePolicy/ImageUpdateAutomation** for this repo stay in **`flux-system`** (**`major-upgrade-flux-image-automation.yaml`** when the major-upgrade overlay is active).

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

1. CNPG **`Cluster/demo-app-db`** in **`major-upgrade-app`** (or **`app-dev`** with the **`demo-app`** overlay) — operand image **`spec.imageName`** (e.g. **`ghcr.io/cloudnative-pg/postgresql:17.6-system-trixie`** in **`major-upgrade-app/patches/postgres-cluster-spec.yaml`**).  
2. **Barman Cloud (CNPG-I):** **`ObjectStore/demo-app-db-store`** in the **same namespace** as the cluster; S3 path **`s3://dev-test-cnpg-backups/major-upgrade-app/`** (major-upgrade overlay) or **`.../demo-app-db/`** (**demo-app** overlay). **`Cluster.spec.plugins`** → **`barman-cloud.cloudnative-pg.io`**, **`parameters.barmanObjectName: demo-app-db-store`**. Base **`gitops/applications/base/postgres-cluster/`** + overlay **`patches/`**.  
3. **`ScheduledBackup/demo-app-db-daily`** — **`method: plugin`**, **`pluginConfiguration.name: barman-cloud.cloudnative-pg.io`**. Requires **`HelmRelease/plugin-barman-cloud`** in **`cnpg-system`**.  
4. **`Secret/demo-app-db-app`**, key **`uri`**.  
5. **`Deployment`** sets **`DATABASE_URL`** from that secret.  
6. App uses **`DATABASE_URL`** or **`DB_*`** + **`DB_SSLMODE`** for local runs. **`LISTEN_ADDR`** default **`:8080`**.  

Upgrade path for Postgres: **[postgres-upgrade-strategy](postgres-upgrade-strategy.md)**. Backup / restore model: **[postgres-backup-strategy](postgres-backup-strategy.md)**, **[operations](operations.md#backups-cnpg)**.

Until the secret exists, pods may stay **CreateContainerConfigError**. Network: **`network-policy-demo-api-allow.yaml`**.

**Local:** `go run ./cmd/demo-api` from `demo-app/` without `DATABASE_URL` (defaults to localhost Postgres).

**Backups:** S3 prefix per overlay (**`major-upgrade-app/`** vs **`demo-app-db/`**); Secret **`cnpg-s3-credentials`** in the app namespace — **[cnpg-backup-secrets](cnpg-backup-secrets.md)**.
