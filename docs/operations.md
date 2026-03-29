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

## OpenBao

### Public ingress

If **`openbao.alissonmachado.com.br`** ingress is enabled, prefer **strong authentication**, **network restrictions**, and **auditing**; in-cluster integrations should continue using the **cluster DNS** service URL on port **8200** (for example **`http://openbao.openbao-system.svc.cluster.local:8200`**).

### OpenBao initialize and unseal

The Helm chart starts the server, but **does not** run **`bao operator init`** or **`bao operator unseal`**. Until you do, logs show **INFO** lines such as **`security barrier not initialized`** and **`seal configuration missing, not initialized`** — the process is running, but the store is not ready to serve the API.

Do this **once per empty data volume**. If you **delete the PVC** or start on new storage, you must **initialize again** (you get new keys; old secrets are gone).

1. **Confirm the server pod** (name may differ slightly with your release name; default StatefulSet is often **`openbao-0`**):

   ```bash
   kubectl get pods -n openbao-system -l app.kubernetes.io/name=openbao
   ```

2. **Discover the main container name** (use it as **`-c`** below if the pod has more than one container):

   ```bash
   kubectl get pod -n openbao-system openbao-0 -o jsonpath='{.spec.containers[*].name}{"\n"}'
   ```

3. **Initialize** (prints **unseal key(s)** and a **root token** once — store them securely; the example uses a single key for **dev only**):

   ```bash
   kubectl exec -n openbao-system openbao-0 -c openbao -- bao operator init \
     -key-shares=1 -key-threshold=1
   ```

   For non-throwaway environments, use more shares and a higher threshold (for example **5** shares, **3** required).

4. **Unseal** so the server can serve traffic (with one share, run once and paste the key when prompted):

   ```bash
   kubectl exec -it -n openbao-system openbao-0 -c openbao -- bao operator unseal
   ```

5. **Verify**:

   ```bash
   kubectl exec -n openbao-system openbao-0 -c openbao -- bao status
   ```

   You want **`Initialized`** **true** and **`Sealed`** **false**.

**After a pod restart** (same PVC, Shamir seal, no auto-unseal): the server may be **sealed** again. Run **`bao operator unseal`** with the **same** key(s); do **not** run **`init`** again or you will make the storage unusable. For production, plan **auto-unseal** (KMS, etc.) instead of relying on manual unseal.

### OpenBao Kubernetes auth (External Secrets)

So **External Secrets Operator** can **PushSecret** / **ExternalSecret** against OpenBao using **Kubernetes auth** (same as **`ClusterSecretStore/openbao`** in Git), apply the GitOps bootstrap:

1. Create **`Secret/openbao-bootstrap`** in **`openbao-system`** with your **root token** (see **[GitOps → OpenBao Kubernetes auth bootstrap](gitops.md#openbao-kubernetes-auth-bootstrap)**).
2. Ensure Job **`openbao-kubernetes-auth-bootstrap`** runs successfully (delete the Job to retry if it skipped earlier).

Policy and role names are defined in **`gitops/infrastructure/openbao-kubernetes-auth/`**; only the **root token** is supplied out-of-band.

### OpenBao web UI login

The public UI is exposed by **Ingress** in **`gitops/infrastructure/openbao-ingress/`** (in this repo the hostname is **`https://openbao.alissonmachado.com.br`**; TLS is terminated at **Traefik**, and **cert-manager** issues the certificate). Adjust the URL if you change the host in Git.

1. **Prerequisites**
   - **DNS** for that hostname points at your **workers load balancer** (see Terraform outputs).
   - **`Certificate`** in **`openbao-system`** is **Ready** (`kubectl get certificate -n openbao-system`).
   - OpenBao is **initialized**, **unsealed**, and serving (see **[OpenBao initialize and unseal](#openbao-initialize-and-unseal)**).

2. **Open the UI** in a browser: **`https://<your-openbao-host>/`** (for example **`https://openbao.alissonmachado.com.br/`**).

3. **Sign in**
   - Choose the **Token** method (or the option labeled like **Token** on the sign-in screen).
   - Paste the **root token** printed by **`bao operator init`** (or another token you created with a suitable policy).
   - Submit to enter the UI.

**Notes**

- The **root token** is full administrative access; store it like a password. For day-to-day use, prefer **less privileged tokens** or other auth methods configured in OpenBao.
- If the page does not load, check **Ingress**, **Traefik**, and **Let’s Encrypt** (see **[TLS certificates](#tls-certificates-lets-encrypt)**).
- If the UI loads but login fails, confirm the server is still **unsealed** (`bao status` via **`kubectl exec`** as above) and that you are using a valid token.

#### Troubleshooting: UI shows **Permission denied** (often HTTP 403) on token login

OpenBao treats a bad or unknown token as **forbidden**; the UI often surfaces that as **Permission denied**, not “invalid token.”

1. **Use the Initial Root Token, not an unseal key**  
   After **`bao operator init`**, the output includes both **Unseal Key** (long, for **`bao operator unseal`**) and **Initial Root Token** (a separate value). The **Token** field in the UI must be the **root token** line only — never the unseal key.

2. **Paste the full token, exactly once**  
   Copy the whole token string (often with a prefix such as **`s.`** or **`hvs.`**), with **no** leading **`Root token:`** label, **no** line breaks, and **no** spaces before or after. Wrapped or PDF copy-paste is a common failure mode.

3. **Confirm the token is valid for *this* cluster**  
   If you **re-ran** **`bao operator init`** or replaced the PVC, older tokens are invalid. Generate a new root token only via a **new** init (destructive) or **`bao operator generate-root`** if you still have unseal keys (see [OpenBao `operator generate-root`](https://openbao.org/docs/commands/operator/generate-root/)).

4. **Verify outside the browser**

   ```bash
   # Replace TOKEN with your Initial Root Token (same string as UI).
   kubectl exec -n openbao-system openbao-0 -c openbao -- sh -c \
     'BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="TOKEN" bao token lookup'
   ```

   If this fails with **permission denied** or **errors**, the token is wrong for this instance or the server is sealed. If it **succeeds** but the UI still fails, try a **private/incognito** window (stale UI token in browser storage) or confirm you open the UI at the **same host and scheme** as **`api_addr`** in **`gitops/operators/openbao/helmrelease.yaml`** (e.g. **`https://openbao.alissonmachado.com.br`** — not `http://`, not a bare IP, unless **`api_addr`** matches).

5. **Optional: check the API over HTTPS (through the ingress)**

   ```bash
   curl -sS -o /dev/null -w "%{http_code}\n" \
     -H "X-Vault-Token: TOKEN" \
     "https://openbao.alissonmachado.com.br/v1/auth/token/lookup-self"
   ```

   **`200`** means the token is accepted; **`403`** means the server rejected the token (wrong value, revoked, or wrong cluster).

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
