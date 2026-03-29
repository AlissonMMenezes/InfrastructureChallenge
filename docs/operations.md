# Operations

Provisioning order: **[getting-started](getting-started.md)**.

## Backups (CNPG)

This project uses the **Barman Cloud** stack for CloudNativePG: the **Barman Cloud CNPG-I plugin** (`barman-cloud.cloudnative-pg.io`) runs next to the database and performs  **base backups** and continuous **WAL archiving** into S3-compatible storage, using the same Barman concepts (retention, PITR) as classic Barman, but configured through Kubernetes CRs.

**How it fits together (generic):**

1. Install the **plugin-barman-cloud** operator (`HelmRelease` in `gitops/operators/plugin-barman-cloud/`) so the cluster can load the plugin.
2. Define an `**ObjectStore`** CR (`barmancloud.cnpg.io/v1`) with `**destinationPath`**, endpoint, and `**cnpg-s3-credentials`** — that is the S3 location Barman Cloud reads and writes.
3. On the `**Cluster**`, set `**spec.plugins**` with `**name: barman-cloud.cloudnative-pg.io**`, `**isWALArchiver: true**`, and `**parameters.barmanObjectName**` pointing at that `**ObjectStore**` metadata name.
4. Create `**ScheduledBackup**` with `**method: plugin**` and `**pluginConfiguration.name: barman-cloud.cloudnative-pg.io**` so CNPG triggers base backups on a schedule; WAL is archived continuously via the plugin.

Credentials and bucket layout: **[cnpg-backup-secrets](cnpg-backup-secrets.md)**, **[postgres-backup-strategy](postgres-backup-strategy.md)**.

Extra GitOps notes: `**gitops/infrastructure/postgres/BACKUP.md`**.

### Example: demo app (`demo-app-db` in `app-dev`)

With the `**demo-app`** overlay active, the Postgres cluster is `**demo-app-db`** in namespace `**app-dev**`. The cluster wires the plugin to `**ObjectStore/demo-app-db-store**`; the overlay sets the S3 prefix to `**s3://dev-test-cnpg-backups/demo-app-db/**` (see `**demo-app/patches/postgres-objectstore-metadata.yaml**`).

**Plugin on the `Cluster`:**

```yaml
# gitops/applications/environments/dev/demo-app/patches/postgres-cluster-spec.yaml
spec:
  instances: 3
  plugins:
    - name: barman-cloud.cloudnative-pg.io
      isWALArchiver: true
      parameters:
        barmanObjectName: demo-app-db-store
```

**Scheduled backup:**

```yaml
# gitops/applications/environments/dev/demo-app/cnpg-scheduledbackup.yaml
apiVersion: postgresql.cnpg.io/v1
kind: ScheduledBackup
metadata:
  name: demo-app-db-daily
  namespace: app-dev
spec:
  schedule: "0 */5 * * * *"
  backupOwnerReference: self
  cluster:
    name: demo-app-db
  method: plugin
  pluginConfiguration:
    name: barman-cloud.cloudnative-pg.io
```

### Quick checks (demo app)

```bash
kubectl get objectstore,scheduledbackup,backup -n app-dev
kubectl describe cluster demo-app-db -n app-dev
kubectl get helmrelease plugin-barman-cloud -n cnpg-system
```

**Policy:** retention, RPO/RTO, restore drills — **[postgres-backup-strategy](postgres-backup-strategy.md)**.

## Restore

**Operational sequence:** stop application writers → define a new or replacement `**Cluster`** with `**bootstrap.recovery`** per **[CNPG recovery](https://cloudnative-pg.io/documentation/current/recovery/)** → verify → point the app at the DB `**Secret` / service** → resume traffic.

**How Barman Cloud fits in:** recovery still uses `**bootstrap.recovery`**. The plugin must read the same Barman layout in S3 as the backup chain: keep `**spec.plugins`** and an `**ObjectStore**` that match (same plugin, `barmanObjectName`, `destinationPath`). For a restore from an existing `**Backup` CR**, reference it under `**bootstrap.recovery`** (field names depend on your CNPG version). For a restore from another S3 archive, use `**externalClusters`** and `**recovery.source`** — see **[postgres-backup-strategy](postgres-backup-strategy.md)**.

Use `kubectl get backup -n app-dev` to list backups; use **PITR** only as in the CNPG doc for your operator.

### Example: demo app (`demo-app-db` / `app-dev`)

Restore from a **named backup** (replace the backup name with one from `kubectl get backup -n app-dev`). The new cluster must still declare the **Barman Cloud** plugin and the `**ObjectStore`** name used for ongoing WAL (`demo-app-db-store` in this repo’s `**demo-app`** overlay):

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: demo-app-db
  namespace: app-dev
spec:
  instances: 3
  plugins:
    - name: barman-cloud.cloudnative-pg.io
      isWALArchiver: true
      parameters:
        barmanObjectName: demo-app-db-store
  bootstrap:
    recovery:
      database: app
      owner: app
      backup:
        name: REPLACE_WITH_BACKUP_NAME
```

Commit the change in Git (or apply with care) and let the operator reconcile; then confirm `**Cluster**` status and application connectivity. Validate `**bootstrap.recovery**` field names against your **CloudNativePG** version (**[CNPG recovery](https://cloudnative-pg.io/documentation/current/recovery/)**).

**More:** **[postgres-backup-strategy](postgres-backup-strategy.md)**, `**gitops/infrastructure/postgres/BACKUP.md`**, **[Barman Cloud plugin](https://cloudnative-pg.io/plugin-barman-cloud/)**.

## Postgres upgrades

To upgrade a Major version of postgres, you can follow these steps.

Update `Cluster.spec.imageName` to a newer tag with the version you want to upgrade.

**Major version:** treat as a **migration**: plan backups, maintenance window, and usually a **new** `**Cluster`** that **recovers** from Barman archives in S3 (same plugin + compatible `**ObjectStore`** paths), then runs the **new** major’s image.

### Example: `major-upgrade-app` (major upgrade via Barman Cloud recovery)

This app has all the patches to show on how to restore a backup from the object storage and recover on the new postgres.

**1 — `ObjectStore` for the PG17 Barman archive** (recovery source; must match `**externalClusters[].plugin.parameters.barmanObjectName`**):

```yaml
# gitops/applications/environments/dev/major-upgrade-app/objectstore-pg17-archive.yaml
apiVersion: barmancloud.cnpg.io/v1
kind: ObjectStore
metadata:
  name: demo-app-db-pg17-archive
spec:
  retentionPolicy: "30d"
  configuration:
    destinationPath: s3://dev-test-cnpg-backups/demo-app-db/
    endpointURL: https://fsn1.your-objectstorage.com
    s3Credentials:
      accessKeyId:
        name: cnpg-s3-credentials
        key: ACCESS_KEY_ID
      secretAccessKey:
        name: cnpg-s3-credentials
        key: ACCESS_SECRET_KEY
    wal:
      compression: gzip
    data:
      compression: gzip
```

**2 — `Cluster` spec fragment: target image, plugin for live WAL, `externalClusters` for the recovery source:**

```yaml
# gitops/applications/environments/dev/major-upgrade-app/patches/postgres-cluster-spec.yaml
spec:
  imageName: ghcr.io/cloudnative-pg/postgresql:18.3-system-trixie
  instances: 3
  plugins:
    - name: barman-cloud.cloudnative-pg.io
      isWALArchiver: true
      parameters:
        barmanObjectName: demo-app-db-store
  externalClusters:
    - name: pg17-barman-source
      plugin:
        name: barman-cloud.cloudnative-pg.io
        parameters:
          barmanObjectName: demo-app-db-pg17-archive
          serverName: demo-app-db
```

**3 — `bootstrap.recovery`:** `**source`** must be `**externalClusters[].name`** (here `**pg17-barman-source`**), not the `**Cluster`’s** metadata name:

```yaml
# gitops/applications/environments/dev/major-upgrade-app/patches/postgres-bootstrap-recovery.yaml
spec:
  bootstrap:
    recovery:
      source: pg17-barman-source
      database: app
      owner: app
```

Overlay metadata patches rename the cluster to `**major-upgrade-app-db**` / namespace `**major-upgrade-app**`. Select this overlay in `**gitops/applications/environments/dev/kustomization.yaml**`, stop application writers during cutover, reconcile Flux, then verify `**Cluster**` status and app smoke tests.

## Monitoring

**kube-prometheus-stack**: Prometheus, Alertmanager, Grafana. Flux dashboards in Grafana **Flux** folder if enabled in Helm values. CNPG metrics where `enablePodMonitor` is set. Operator layout and PodMonitors: **[monitoring-stack.md](monitoring-stack.md)**.

**Grafana admin password** (default release name, namespace `monitoring`):

```bash
kubectl get secrets -n monitoring -l app.kubernetes.io/name=grafana
kubectl get secret -n monitoring kube-prometheus-stack-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

## TLS

`kubectl get certificate -A`. If ACME fails: DNS → LB, port **80** reachable, issuer **Ready**.

## Upgrades / scaling

Postgres: Git + Flux; watch backups and lag before changes. Apps: HPA / replica counts in Git. Nodes: Terraform + Ansible alignment.