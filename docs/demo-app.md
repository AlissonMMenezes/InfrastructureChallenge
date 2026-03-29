# Demo app (`demo-api`)

**Code:** `demo-app/` — Go, **`cmd/demo-api`**, **`internal/{config,db,httpserver}`** (embedded templates + OpenAPI). **Image:** `.github/workflows/demo-app-image.yml` → **GHCR** `ghcr.io/<owner-lower>/demo-app`.

**GitOps:** base `gitops/applications/base/demo-app/`; dev overlay `gitops/applications/environments/dev/demo-app/` (ingress, replicas, optional image automation).

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

1. CNPG **`Cluster/demo-app-db`** in **`app-dev`**.  
2. **`Secret/demo-app-db-app`**, key **`uri`**.  
3. **`Deployment`** sets **`DATABASE_URL`** from that secret.  
4. App uses **`DATABASE_URL`** or **`DB_*`** + **`DB_SSLMODE`** for local runs. **`LISTEN_ADDR`** default **`:8080`**.

Until the secret exists, pods may stay **CreateContainerConfigError**. Network: **`network-policy-demo-api-allow.yaml`**.

**Local:** `go run ./cmd/demo-api` from `demo-app/` without `DATABASE_URL` (defaults to localhost Postgres).

**Backups:** prefix **`demo-app-db/`** — **[cnpg-backup-secrets](cnpg-backup-secrets.md)**.
