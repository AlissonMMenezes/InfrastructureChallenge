# Operations lifecycle

For provisioning and GitOps bootstrap order, see **[Getting started](getting-started.md)**.

## Backup strategy

- CloudNativePG `ScheduledBackup` runs periodic backups.
- Destination: S3-compatible object storage (`s3://cnpg-backups/<env>`).
- Recommended schedule:
  - Full/base backup daily
  - WAL archival continuous

## Restore procedure (high level)

1. Pause writes from dependent applications.
2. Create a new `Cluster` manifest with `bootstrap.recovery` from backup.
3. Verify data consistency checks.
4. Switch service endpoint or update app secret/connection details.
5. Resume traffic.

## Monitoring

- **kube-prometheus-stack** provides Prometheus, Alertmanager, and **Grafana**. When **Grafana ingress** is enabled in the Helm values, the UI is served at **`https://grafana.alissonmachado.com.br`** (TLS via cert-manager).
- **Flux CD:** **`PodMonitor`** in **`flux-system`** plus **kube-state-metrics** custom-resource metrics expose **`gotk_reconcile_*`**, **`gotk_resource_info`**, etc. In Grafana, open folder **Flux** for **Flux** (cluster reconciliation) and **Flux Control Plane** dashboards (from **`gitops/operators/kube-prometheus-stack/`**). After upgrade, allow a few minutes for dashboard download jobs and KSM to reload CRS config.
- CloudNativePG emits metrics; **ServiceMonitors** are enabled where configured.
- Prometheus alerts cover:
  - replication lag,
  - backup failures,
  - pod restarts,
  - PVC saturation,
  - failover events.

### Grafana admin password (kube-prometheus-stack)

The Grafana subchart stores bootstrap credentials in a **Secret** in the **`monitoring`** namespace. With the default **HelmRelease** name **`kube-prometheus-stack`** and no **`grafana.admin.existingSecret`**, the object is usually **`kube-prometheus-stack-grafana`**.

1. **Confirm the Secret name** (if your release name differs, adjust):

   ```bash
   kubectl get secrets -n monitoring -l app.kubernetes.io/name=grafana
   ```

   Or list by name pattern:

   ```bash
   kubectl get secrets -n monitoring | grep grafana
   ```

2. **Read the password** (replace the Secret name if yours differs):

   ```bash
   kubectl get secret -n monitoring kube-prometheus-stack-grafana \
     -o jsonpath='{.data.admin-password}' | base64 -d
   echo
   ```

3. **Read the username** (defaults to **`admin`** per **`grafana.adminUser`** in the Helm values; the Secret key is **`admin-user`**):

   ```bash
   kubectl get secret -n monitoring kube-prometheus-stack-grafana \
     -o jsonpath='{.data.admin-user}' | base64 -d
   echo
   ```

**Notes:**

- Keys are **base64-encoded** in the API; piping through **`base64 -d`** decodes them for use in the browser.
- If you set **`grafana.admin.existingSecret`** in the **HelmRelease**, credentials live in that Secret instead — use the keys configured there (**`admin-user`** / **`admin-password`** by default).
- To **rotate** the password, update the Secret (or use Grafana’s UI / API) and ensure the deployment still matches your GitOps intent so Flux does not overwrite manual changes on the next reconcile.

## TLS certificates (Let’s Encrypt)

- **cert-manager** backs **`Certificate`** objects created from **Ingress** TLS + **`cert-manager.io/cluster-issuer: letsencrypt-prod`**.
- Check status: `kubectl get certificate -A` and `kubectl describe certificate -n <ns> <name>`.
- If HTTP-01 fails, verify **DNS** points to the workers LB, **port 80** is reachable from the Internet to Traefik, and **`ClusterIssuer/letsencrypt-prod`** is **Ready**.

## OpenBao (public ingress)

- If **`openbao.alissonmachado.com.br`** ingress is enabled, prefer **strong authentication**, **network restrictions**, and **auditing**; in-cluster integrations should continue using the **cluster DNS** service URL on port **8200**.

## Upgrades

- Minor PostgreSQL upgrades performed by updating image tags in Git.
- Flux CD reconciles manifest changes; CNPG orchestrates rolling restarts.
- Pre-checks:
  - recent successful backup,
  - low replication lag,
  - maintenance window active.

## Scaling

- Vertical: adjust resource requests/limits and storage classes.
- Horizontal for DB: add replicas where topology supports.
- App scaling: HPA on CPU/memory or custom metrics.
