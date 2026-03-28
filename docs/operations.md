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

- **kube-prometheus-stack** provides Prometheus, Alertmanager, and **Grafana**. When **Grafana ingress** is enabled in the Helm values, the UI is served at **`https://grafana.alissonmachado.com.br`** (TLS via cert-manager). Admin password: Kubernetes **Secret** in **`monitoring`** created by the chart (commonly named like **`kube-prometheus-stack-grafana`** — confirm with `kubectl get secrets -n monitoring | grep grafana` and read key **`admin-password`**).
- CloudNativePG emits metrics; **ServiceMonitors** are enabled where configured.
- Prometheus alerts cover:
  - replication lag,
  - backup failures,
  - pod restarts,
  - PVC saturation,
  - failover events.

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
