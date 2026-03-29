# Security

### Secret management

#### OpenBao and External Secrets Operator

The operators are already available on via [GitOps](gitops/operators/), however not being used by any application yet, i would need a bit more time to configure everything in a proper and automated way.

Howver it is available on [https://openbao.alissonmachado.com.br](https://openbao.alissonmachado.com.br) after the cluster provisioning.

Becareful when you install it, becaue it will request to unseal and generate the root token. As it is an ephemeral cluster, i let it avaiable, but we can disable it via GitOps and unseal only via command line.

The idea would be to have it syncing the secrets on internal times from the OpenBao Server to the Cluster using the ESO.

**In order to sync the secrets from the OpenBao server to the ESO, you can use the following example.**

```yaml
# Illustrative — SecretStore (e.g. app-dev). Adjust apiVersion to your ESO CRD version.
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: openbao
  namespace: app-dev
spec:
  provider:
    vault:
      # In-cluster example; use https and CA if you terminate TLS on OpenBao
      server: "http://openbao.openbao-system.svc.cluster.local:8200"
      path: secret
      version: v2
      auth:
        # Preferred: Kubernetes auth — create a named role in OpenBao bound to ESO’s SA
        kubernetes:
          mountPath: kubernetes
          role: external-secrets
          serviceAccountRef:
            name: external-secrets
            namespace: external-secrets
```

For **cluster-wide** reuse, the same pattern exists as `**ClusterSecretStore`**.

**2 — Sync OpenBao data into a Kubernetes `Secret`** with an `**ExternalSecret**`. ESO periodically reconciles and updates the target `**Secret**` (e.g. for `**cnpg-s3-credentials**` or app env vars).

```yaml
# Illustrative — ExternalSecret → Secret/cnpg-s3-credentials in app-dev
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: cnpg-s3-from-openbao
  namespace: app-dev
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: openbao
    kind: SecretStore
  target:
    name: cnpg-s3-credentials
    creationPolicy: Owner
  data:
    - secretKey: ACCESS_KEY_ID
      remoteRef:
        key: secret/data/cnpg/s3
        property: ACCESS_KEY_ID
    - secretKey: ACCESS_SECRET_KEY
      remoteRef:
        key: secret/data/cnpg/s3
        property: ACCESS_SECRET_KEY
```

Paths like `**secret/data/...**` follow **KV v2** conventions (`secret` is the default mount; OpenBao/HashiCorp KV v2 stores versioned JSON at `…/data/…`). Populate values once in OpenBao (CLI/UI/API), for example:

```bash
# Illustrative — run against a configured OpenBao CLI (namespace / policy as appropriate)
bao kv put secret/cnpg/s3 ACCESS_KEY_ID='REPLACE_ME' ACCESS_SECRET_KEY='REPLACE_ME'
```

### Access control

- **Kubernetes RBAC:** least privilege — namespace-scoped roles for app teams and automation service accounts.
- **SSH and cloud API:** protect **bastion** access and `**HCLOUD_TOKEN`** / cloud credentials.
- **Flux / GitOps:** deploy keys or tokens with **read-only** to the cluster repo unless image automation truly needs write access; scope repository access narrowly. **( On this case, it is allowed because of the Image Automation )**
- **Ingress exposure:** **Grafana** and **OpenBao** would be better to be exposed only via VPN.

**Example — namespace-scoped access** (illustrative; bind a user or group to a `Role` instead of `cluster-admin`):

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-developer
  namespace: app-dev
rules:
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["pods", "pods/log"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-developer-binding
  namespace: app-dev
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: app-developer
subjects:
  - kind: User
    name: developer@example.com
    apiGroup: rbac.authorization.k8s.io
```

**Example — dedicated `ServiceAccount` for the workload** (demo app):

```yaml
# gitops/applications/base/demo-app/serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: demo-api
  namespace: app-dev
```

### Network policies

- Prefer **default-deny** baselines in application namespaces and **allow only** what workloads need (DNS, Postgres, ingress controller, Prometheus scrapes).
- This repo includes example policies (e.g. `**network-policy-demo-api-allow.yaml`** in the demo app) — extend the same pattern to new workloads rather than wide `**allow all`** egress.
- **Nodes:** firewall and SSH hardening via Ansible (**base** / **security** roles) complement in-cluster policy; they are not a substitute for `**NetworkPolicy`** for pod-to-pod traffic.

**Example — default deny for selected pods** (`Ingress` + `Egress` enforced once a CNI supports `NetworkPolicy`):

```yaml
# gitops/applications/base/demo-app/network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-demo-api
  namespace: app-dev
spec:
  podSelector:
    matchLabels:
      app: demo-api
  policyTypes:
    - Ingress
    - Egress
```

**Example — explicit allows** (DNS in `kube-system`, Postgres by CNPG label, HTTP from Traefik, scrape from monitoring):

```yaml
# gitops/applications/base/demo-app/network-policy-demo-api-allow.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-demo-api-traffic
  namespace: app-dev
spec:
  podSelector:
    matchLabels:
      app: demo-api
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: monitoring
      ports:
        - port: 8080
          protocol: TCP
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: traefik-system
      ports:
        - port: 8080
          protocol: TCP
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - port: 53
          protocol: UDP
        - port: 53
          protocol: TCP
    - to:
        - podSelector:
            matchLabels:
              cnpg.io/cluster: demo-app-db
      ports:
        - port: 5432
          protocol: TCP
```

#### CNI: Calico and enforceable `NetworkPolicy`

Firstly the cluster was bootstraped with Flannel, because it is simpler to install and configure, however as the goal here is to follow best security best practices, i had to update the ansible role and deploy it using calico.

This way we can enforce Network policies.

**Example — Ansible pins Calico and `pod_network_cidr`** (must match kubeadm):

```yaml
# ansible/roles/kubernetes/defaults/main.yml (excerpt)
pod_network_cidr: "10.244.0.0/16"

# Calico (Tigera operator) — replaces Flannel
kubernetes_calico_version: "v3.28.2"
kubernetes_calico_tigera_operator_manifest_url: "https://raw.githubusercontent.com/projectcalico/calico/{{ kubernetes_calico_version }}/manifests/tigera-operator.yaml"
```

---

**Related:** **[gitops](gitops.md)** (Flux, secrets bootstrap), **[architecture](architecture.md)** (components), **[demo-app](demo-app.md)** (app + CNPG + network policy pointers).