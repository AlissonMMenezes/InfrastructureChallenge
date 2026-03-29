# PostgreSQL upgrades (CloudNativePG)

| Cluster | Namespace | Manifest |
|---------|-----------|----------|
| `dev-postgres` | `postgres` | `gitops/infrastructure/postgres/cluster.yaml` |
| `demo-app-db` | `app-dev` | `gitops/applications/base/demo-app/postgres-cluster.yaml` |

Operator: `gitops/operators/cloudnative-pg/helmrelease.yaml`. **Authoritative:** [CNPG upgrading](https://cloudnative-pg.io/docs/1.28/installation_upgrade#upgrades).

## Choosing / changing the Postgres version

- **`Cluster.spec.imageName`** — full image ref for that cluster; changing it triggers a rolling operand upgrade (see [package tags](https://github.com/cloudnative-pg/postgresql/pkgs/container/postgresql)). Match **[operator-supported](https://cloudnative-pg.io/documentation/current/supported_releases/)** images.
- **`POSTGRES_IMAGE_NAME`** — set under **`HelmRelease/cloudnative-pg`** → **`values.config.data`** ([operator config](https://cloudnative-pg.io/documentation/current/operator_conf/)). This is the **default** operand image for **`Cluster`** objects that **omit** **`imageName`**. After changing operator config, **restart** the operator deployment if the chart does not roll it automatically. Keep this value **aligned** with the image you intend as standard when you use explicit **`imageName`** everywhere, so defaults and docs stay consistent.

Optional rollout spacing (same **`config.data`**): **`CLUSTERS_ROLLOUT_DELAY`**, **`INSTANCES_ROLLOUT_DELAY`** (seconds) to stagger upgrades during large operator reconciliations.

## Rules

1. Confirm backups / WAL OK before changes (**[operations](operations.md)**, **[cnpg-backup-secrets](cnpg-backup-secrets.md)**).  
2. One change type per window (operator *or* image *or* params).  
3. GitOps only; avoid stray `kubectl edit` on **`Cluster`**.  
4. Watch replicas during rolling updates.

## Operator

Bump **`HelmRelease`** chart version → merge → `flux reconcile helmrelease cloudnative-pg -n cnpg-system --with-source` → check **`Cluster`** Ready / replication. Rollback: revert chart version in Git.

## Minor / patch (operand)

Set **`spec.imageName`** on **`Cluster`** to a supported **`ghcr.io/cloudnative-pg/postgresql:...`** tag for your operator version; reconcile. Rollback: revert tag in Git.

## Major

Not a single-field change. Needs tested backup, restore drill, and CNPG doc procedure for your version.

## Parameters

`spec.postgresql.parameters` may restart instances — commit in Git, watch rollout.

## Checklist

**Before:** backup OK, `cnpg-s3-credentials` if using S3, maintenance window if needed.  
**After:** `kubectl get cluster -A`, pods Running, app smoke tests.

**Rollback:** revert HelmRelease / `imageName` / params; for corruption use new `Cluster` from backup (**[operations — restore](operations.md#restore-outline)**).
