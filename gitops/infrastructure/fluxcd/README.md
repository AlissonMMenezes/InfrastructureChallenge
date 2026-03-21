# Flux CD installation

Install the Flux controllers on the cluster **outside** this directory:

- **Ansible:** `ansible/playbooks/install-fluxcd.yml` (see `ansible/README.md`).
- **CLI:** `flux bootstrap github ...` (see `gitops/README.md`).

This repo only contains **workload and sync definitions** (`HelmRepository`, `HelmRelease`, Flux `Kustomization`) consumed after Flux is running.

The previous **`infrastructure/argocd/`** placeholder was removed in favor of Flux.
