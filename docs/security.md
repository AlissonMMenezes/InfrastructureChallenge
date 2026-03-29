# Security considerations

## Secret management

- Do not commit plaintext credentials.
- This repo uses **OpenBao** (Vault-compatible API) with **External Secrets Operator**: **`PushSecret`** copies CloudNativePG bootstrap credentials into OpenBao KV; **`ExternalSecret`** materializes **`Secret`** objects for workloads (see **`docs/gitops.md`**). **Policy** HCL and the **bootstrap Job** live in **`gitops/infrastructure/openbao-kubernetes-auth/`**; the **root token** used to run **`bao write`** against the API must **not** be committed — create **`Secret/openbao-bootstrap`** manually (see **[GitOps → OpenBao Kubernetes auth bootstrap](gitops.md#openbao-kubernetes-auth-bootstrap)**).
- Alternatives for other workloads: cloud secret managers + ESO, or **SOPS**-encrypted manifests.
- **Public ingress** to OpenBao or Grafana increases attack surface; restrict by IP, SSO, or disable when not needed.

## Access control

- Namespace-scoped service accounts for app and operators.
- RBAC roles with least privilege.
- Cluster-admin restricted to platform SRE group.

## Network policies

- Default deny in application namespaces (e.g. **demo-api** in **`app-dev`**).
- Allow only explicit traffic:
  - app → Postgres (CNPG) on **5432**
  - **Traefik** / **monitoring** → app metrics where **ServiceMonitors** scrape
- **External Secrets** controller reaches OpenBao from the **`external-secrets`** namespace (not through public ingress).

## Node and runtime hardening

- SSH hardened (key-based auth, optional root login disable).
- Firewall limited to required Kubernetes and SSH ports.
- Fail2ban enabled.
- Container images pinned and scanned in CI.

## Supply chain security

- Signed images (Cosign) and admission verification (Kyverno policy optional).
- SBOM generation for demo app artifacts.
- Dependency updates automated with review gates.
