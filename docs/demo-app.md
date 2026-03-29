# Demo app (`demo-api`)

The **demo-api** workload runs from `demo-app/` and connects to **PostgreSQL provisioned by CloudNativePG (CNPG)**. **You do not put database passwords in Git** — CNPG creates a `**Secret`** with a connection URI; the `**Deployment**` exposes it as `**DATABASE_URL**`.


| Overlay                 | Role                                                                                                                                 | Namespace           | S3 prefix (Barman)                             |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------ | ------------------- | ---------------------------------------------- |
| `**demo-app**`          | Normal CNPG install: `bootstrap.initdb`, Barman Cloud plugin backups.                                                                | `app-dev`           | `demo-app-db/`                                 |
| `**major-upgrade-app**` | Major upgrade example: `bootstrap.recovery` and extra `ObjectStore` — **[postgres-upgrade-strategy](postgres-upgrade-strategy.md)**. | `major-upgrade-app` | `major-upgrade-app/` (and PG17 archive prefix) |


## GitOps layout (demo-app)

The dev overlay composes the base app + CNPG resources and patches names, namespace, and ingress:

```yaml
# gitops/applications/environments/dev/demo-app/kustomization.yaml (excerpt)
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../../base/demo-app/
  - cnpg-scheduledbackup.yaml
  - image-automation.yaml
patches:
  - path: patches/ingress.yaml
    target:
      group: networking.k8s.io
      kind: Ingress
      name: demo-api
      namespace: app-dev
  - path: patches/postgres-cluster-metadata.yaml
    target:
      group: postgresql.cnpg.io
      kind: Cluster
      name: app-postgres
      namespace: app
```

The `**postgres-cluster-metadata**` patch renames the base cluster to `**demo-app-db**` in `**app-dev**`:

```yaml
# gitops/applications/environments/dev/demo-app/patches/postgres-cluster-metadata.yaml
- op: replace
  path: /metadata/name
  value: demo-app-db
- op: replace
  path: /metadata/namespace
  value: app-dev
```

## Connecting to Postgres (CNPG + Secret)

1. **CNPG `Cluster`** defines the database and owner. With `bootstrap.initdb`, the operator creates the database and user, then creates a `**Secret**` named `**{clusterName}-{owner}**` (for example cluster `**demo-app-db**` and owner `**app**` → `**demo-app-db-app**`) with keys such as `**uri**`. See [CloudNativePG secrets](https://cloudnative-pg.io/documentation/current/applications/).
2. `**Deployment/demo-api**` references that Secret so the pod receives the same URI as env `**DATABASE_URL**`.

**Cluster bootstrap (application user):**

```yaml
# gitops/applications/base/postgres-cluster/cluster.yaml (spec excerpt)
spec:
  bootstrap:
    initdb:
      database: app
      owner: app
```

**Deployment** — inject `**DATABASE_URL`** from the CNPG-generated Secret:

```yaml
# gitops/applications/base/demo-app/deployment.yaml (excerpt)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-api
  namespace: app-dev
spec:
  template:
    spec:
      containers:
        - name: demo-api
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: demo-app-db-app
                  key: uri
```

**Ingress host** (overlay; use your own domain in Git):

```yaml
# gitops/applications/environments/dev/demo-app/patches/ingress.yaml
- op: replace
  path: /spec/rules/0/host
  value: demo-app.alissonmachado.com.br
- op: replace
  path: /spec/tls/0/hosts/0
  value: demo-app.alissonmachado.com.br
```

The container reads `**DATABASE_URL**` from the environment (the value injected above). For behavior outside Kubernetes, see the `**demo-app**` source under `cmd/demo-api` and `internal/`.

Until `**Secret/demo-app-db-app**` exists, pods can stay `**CreateContainerConfigError**`. Inspect (redact when sharing):

```bash
kubectl get secret demo-app-db-app -n app-dev -o jsonpath='{.data.uri}' | base64 -d; echo
```

More backup/ops context: **[operations](operations.md#backups-cnpg)**, **[cnpg-backup-secrets](cnpg-backup-secrets.md)**.

## HTTP


| Path                                 | Purpose                      |
| ------------------------------------ | ---------------------------- |
| `GET /`                              | HTML dashboard + form        |
| `POST /demo/item`                    | Form → insert → redirect `/` |
| `GET /healthz`                       | `{"status":"ok"}`            |
| `GET/POST /items`                    | JSON                         |
| `GET /api/docs`, `/api/openapi.json` | Swagger                      |
| `GET /metrics`                       | Prometheus                   |


## Postgres stack (demo-app )

1. `**Cluster/demo-app-db`** in `**app-dev**` — `bootstrap.initdb` from `gitops/applications/base/postgres-cluster/` plus `environments/dev/demo-app/patches/`.
2. **Barman Cloud (CNPG-I):** `ObjectStore/demo-app-db-store`, S3 prefix `s3://dev-test-cnpg-backups/demo-app-db/`, `ScheduledBackup` with `method: plugin`.
3. `**HelmRelease/plugin-barman-cloud`** in `cnpg-system`.
4. **Connection** — CNPG `**Secret/demo-app-db-app`** key `**uri**` → `**DATABASE_URL**` on `**Deployment/demo-api**` (see above).

**Network:** `network-policy-demo-api-allow.yaml`.

**Backups:** **[cnpg-backup-secrets](cnpg-backup-secrets.md)**.