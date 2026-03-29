# Repository structure

| Path | Purpose |
|------|---------|
| `terraform/` | Hetzner modules + `environments/{dev,prod}` |
| `ansible/` | Playbooks and roles (kubeadm, Flux) |
| `gitops/` | Flux: `clusters/<env>/`, `operators/`, `infrastructure/`, `applications/` |
| `demo-app/` | Sample API (CI → GHCR) |
| `.github/workflows/` | e.g. demo-app image build |
| `docs/` | This documentation set |

GitOps detail: **`gitops/README.md`**.
