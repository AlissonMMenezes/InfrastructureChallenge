# Security

- **Secrets:** not in Git. Use CNPG/EKS-style secrets, **ESO**, **SOPS**, or cloud backends. **`openbao-bootstrap`** is highly sensitive; prefer auto-unseal and tight RBAC in production.
- **RBAC:** least privilege; cluster-admin limited to platform roles.
- **Network:** default-deny-oriented policies in app namespaces; explicit egress to Postgres, DNS, and scrapers as in manifests.
- **Nodes:** SSH hardening, firewall, fail2ban (Ansible **base** / **security**).
- **Supply chain:** pin images/charts; CI scanning as you adopt it.

OpenBao/Grafana **public ingress** increases risk — restrict in production (IP allowlist, SSO, or disable).
