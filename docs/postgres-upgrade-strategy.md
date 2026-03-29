# PostgreSQL upgrade strategy (CloudNativePG)

This document describes how to **safely upgrade** PostgreSQL managed by **CloudNativePG (CNPG)** in this repository. It applies to:

| Cluster | Namespace | Manifest |
|---------|-----------|----------|
| **`dev-postgres`** | **`postgres`** | [`gitops/infrastructure/postgres/cluster.yaml`](../gitops/infrastructure/postgres/cluster.yaml) |
| **`demo-app-db`** | **`app-dev`** | [`gitops/applications/base/demo-app/postgres-cluster.yaml`](../gitops/applications/base/demo-app/postgres-cluster.yaml) |

The **operator** is installed by Flux: [`gitops/operators/cloudnative-pg/helmrelease.yaml`](../gitops/operators/cloudnative-pg/helmrelease.yaml).

Official reference: [CloudNativePG — Upgrading PostgreSQL](https://cloudnative-pg.io/documentation/current/upgrading/) (always read the version that matches your installed operator).

## Principles

1. **Prove backups** — Take or confirm a **successful base backup** and healthy **WAL archiving** before changing versions (see **[Backup strategy](operations.md#backup-strategy)** and **[CNPG backup secrets](cnpg-backup-secrets.md)**).
2. **One moving part** — Prefer **operator upgrade** *or* **PostgreSQL image upgrade** in a single change window; avoid combining with unrelated GitOps edits so failures are easy to attribute.
3. **GitOps first** — Change manifests in Git; let **Flux** reconcile. Avoid one-off `kubectl edit` on **`Cluster`** unless you are explicitly doing a break-glass drill and will revert or backport the change to Git.
4. **Watch HA** — Multi-instance clusters (**`dev-postgres`**) roll through replicas; **`primaryUpdateStrategy: unsupervised`** allows the operator to orchestrate primary updates without manual approval—still monitor during the window.

## 1. Upgrade the CloudNativePG operator

The Helm chart version lives in **`HelmRelease/cloudnative-pg`** (`spec.chart.spec.version`).

**Recommended flow**

1. Read the **release notes** for the target chart / operator version ([CloudNativePG releases](https://github.com/cloudnative-pg/cloudnative-pg/releases)) for CRD or behavior changes.
2. Bump the version in **`gitops/operators/cloudnative-pg/helmrelease.yaml`**, merge to the branch Flux tracks.
3. Reconcile and verify:

   ```bash
   flux reconcile helmrelease cloudnative-pg -n cnpg-system --with-source
   kubectl get pods -n cnpg-system
   kubectl get crd clusters.postgresql.cnpg.io
   ```

4. Confirm existing **`Cluster`** objects become **Ready** and replication is healthy (`kubectl describe cluster <name> -n <namespace>`).

**Rollback:** Revert the chart version in Git and reconcile again. If CRDs changed incompatibly, follow the operator project’s downgrade guidance (avoid skipping major operator jumps without reading docs).

## 2. Upgrade the PostgreSQL *minor* version (patch release)

CNPG runs PostgreSQL from an **operand image** (typically **`ghcr.io/cloudnative-pg/postgresql:<major>.<minor>-<fullversion>`**). Your **`Cluster`** manifests do not pin **`spec.imageName`** today; the operator defaults apply. To move to a **newer patch** of the same major:

1. Choose a supported image tag from **`ghcr.io/cloudnative-pg/postgresql`** that matches your desired PostgreSQL major and is **compatible** with your CNPG operator version.
2. Set **`spec.imageName`** on the **`Cluster`** to that full image reference (same field for all instances of that cluster).
3. Apply via GitOps; the operator performs a **rolling update** (replicas first, then primary, according to CNPG rules and **`primaryUpdateStrategy`**).

**Verify**

```bash
kubectl get cluster -n postgres
kubectl get pods -n postgres -l cnpg.io/cluster=dev-postgres
kubectl describe cluster dev-postgres -n postgres
```

Repeat for **`demo-app-db`** in **`app-dev`**.

**Rollback:** Revert **`spec.imageName`** in Git to the previous tag and reconcile; ensure the old image is still pullable.

## 3. Upgrade PostgreSQL *major* version (e.g. 15 → 16)

Major upgrades are **not** a single field flip. CloudNativePG supports controlled paths depending on version; options include **in-place major upgrade** (when offered for your combination) or **new cluster + logical/physical migration**. This is **high risk** and environment-specific.

**Minimum discipline**

1. **Fresh verified backup** (base + WAL) and a tested **restore drill** on a non-production clone when possible.
2. Follow **[Upgrading PostgreSQL](https://cloudnative-pg.io/documentation/current/upgrading/)** for your operator version exactly (prerequisites, `primaryUpdateStrategy`, job-based upgrade, etc.).
3. Plan application compatibility (drivers, SQL, extensions).

Do **not** rely on this README alone for major jumps—use the CNPG doc and, if needed, EDB/CNPG support channels.

## 4. Change only PostgreSQL *configuration* (`postgresql.parameters`)

Edits under **`spec.postgresql.parameters`** (e.g. `max_connections`, `shared_buffers`) may trigger a **restart** of instances. Treat like a small rollout:

1. Commit the parameter change in Git.
2. Watch **`kubectl describe cluster`** and pod restarts.
3. Confirm application behavior and metrics (connections, errors).

## 5. Pre- and post-upgrade checklist

**Before**

- [ ] Recent **Backup** resource **completed** (or acceptable RPO documented).
- [ ] **`cnpg-s3-credentials`** present if S3 backup is configured.
- [ ] **Maintenance window** communicated if clients are sensitive to brief failovers.
- [ ] **Grafana / Prometheus** CNPG dashboards open (replication lag, errors).

**After**

- [ ] **`kubectl get cluster -A`** — phase **Cluster in healthy state** (wording may vary by version).
- [ ] All pods **Running**, expected **replica count**.
- [ ] Application **smoke tests** against each dependent service.
- [ ] Optional: **`VACUUM` / `ANALYZE`** or workload-specific checks per DBA policy.

## 6. Rollback summary

| Situation | Action |
|-----------|--------|
| Bad **operator** chart version | Revert **`HelmRelease`** version in Git; reconcile. |
| Bad **operand** image tag | Revert **`spec.imageName`** (or remove pin to return to default, if appropriate). |
| Data corruption / unrecoverable error | **Point-in-time** or base backup **restore** to a new **`Cluster`** (see **[Restore procedure](operations.md#restore-procedure-high-level)**); cut over apps. |

---

**Related:** [Operations](operations.md) · [GitOps (Flux)](gitops.md) · [`gitops/infrastructure/postgres/BACKUP.md`](../gitops/infrastructure/postgres/BACKUP.md)
