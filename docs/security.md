# Security considerations

## Secret management

- Do not commit plaintext credentials.
- Use one of:
  - External Secrets Operator + cloud secret manager, or
  - SOPS-encrypted manifests.
- Demo manifests include placeholder secret references.

## Access control

- Namespace-scoped service accounts for app and operators.
- RBAC roles with least privilege.
- Cluster-admin restricted to platform SRE group.

## Network policies

- Default deny in application namespaces.
- Allow only explicit traffic:
  - app -> postgres service on `5432`
  - monitoring namespace -> metrics endpoints

## Node and runtime hardening

- SSH hardened (key-based auth, optional root login disable).
- Firewall limited to required Kubernetes and SSH ports.
- Fail2ban enabled.
- Container images pinned and scanned in CI.

## Supply chain security

- Signed images (Cosign) and admission verification (Kyverno policy optional).
- SBOM generation for demo app artifacts.
- Dependency updates automated with review gates.
