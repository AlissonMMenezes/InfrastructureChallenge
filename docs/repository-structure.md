# Repository structure

Top-level directories:

| Path | Purpose |
|------|---------|
| **`terraform/`** | Modular Hetzner (and shared) provisioning; **`environments/dev`** and **`environments/prod`** compose modules. Includes **`modules/object-storage`** (S3 bucket on Hetzner Object Storage via MinIO provider) for backups. |
| **`ansible/`** | Idempotent roles and playbooks: host baseline, security, **kubeadm** Kubernetes, optional **Flux** install. |
| **`gitops/`** | Flux manifests: **`clusters/<env>/`** entrypoints, **`operators/`**, **`infrastructure/`**, **`applications/`**. |
| **`demo-app/`** | Sample containerised API (build via CI / local Docker; image referenced from GitOps). |
| **`.github/workflows/`** | CI (e.g. **`demo-app-image.yml`** — build/push to **GHCR** with **lowercase** image path). |
| **`docs/`** | Architecture, runbooks, security, and how-to guides (this folder). |

Deeper GitOps layout: [`../gitops/README.md`](../gitops/README.md).
