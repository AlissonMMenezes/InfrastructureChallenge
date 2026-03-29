# Operations

Provisioning order: **[getting-started](getting-started.md)**.

## Backups (CNPG)

Clusters **`dev-postgres`** (`postgres`) and **`demo-app-db`** (`app-dev`) → bucket **`dev-test-cnpg-backups`**, prefixes **`dev-postgres/`**, **`demo-app-db/`**. Endpoint in Git must match your Hetzner region (e.g. `fsn1`).

Create **`Secret/cnpg-s3-credentials`** (keys **`ACCESS_KEY_ID`**, **`ACCESS_SECRET_KEY`**) in **`postgres`** and **`app-dev`**: **[cnpg-backup-secrets](cnpg-backup-secrets.md)**, **`gitops/infrastructure/postgres/BACKUP.md`**.

**Backup management (policy):** align retention, RPO/RTO, and restore testing with **[Barman](https://docs.pgbarman.org/)** concepts — see **[postgres-backup-strategy](postgres-backup-strategy.md)**.

## Restore (outline)

Stop writers → new `Cluster` with `bootstrap.recovery` from backup → verify → point apps → resume.

## Postgres upgrades

**[postgres-upgrade-strategy](postgres-upgrade-strategy.md)** (operator chart, operand image, parameters). Follow [CNPG upgrading](https://cloudnative-pg.io/documentation/current/upgrading/) for your operator version.

## Monitoring

**kube-prometheus-stack**: Prometheus, Alertmanager, Grafana. Flux dashboards in Grafana **Flux** folder if enabled in Helm values. CNPG metrics where **`enablePodMonitor`** is set.

**Grafana admin password** (default release name, namespace `monitoring`):

```bash
kubectl get secrets -n monitoring -l app.kubernetes.io/name=grafana
kubectl get secret -n monitoring kube-prometheus-stack-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

## TLS

`kubectl get certificate -A`. If ACME fails: DNS → LB, port **80** reachable, issuer **Ready**.

## OpenBao

- **Ingress** is sensitive; in-cluster clients should use **`http://openbao.openbao-system.svc.cluster.local:8200`** where possible.
- **Init / unseal:** GitOps Job **`openbao-init-store-keys`** or manual `bao operator init` / `bao operator unseal` on pod **`openbao-0`** (see [OpenBao docs](https://openbao.org/docs/)). Same PVC: unseal after restart; do not re-init.
- **ESO:** After **`Secret/openbao-bootstrap`** exists, Job **`openbao-kubernetes-auth-bootstrap`** configures **`auth/kubernetes`**. Retry: delete the Job; Flux recreates it.
- **UI login:** HTTPS ingress host → sign in with **Token** (root token from init — not the unseal key). If **403**: wrong token, sealed server, or `api_addr` mismatch vs browser URL.

## Upgrades / scaling

Postgres: Git + Flux; watch backups and lag before changes. Apps: HPA / replica counts in Git. Nodes: Terraform + Ansible alignment.
