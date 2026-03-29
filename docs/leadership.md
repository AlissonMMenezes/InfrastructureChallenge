# Leadership / delivery notes

- **Team split (example):** infra/Terraform; K8s/Ansible; GitOps/observability/onboarding. PRs require peer review; attach Terraform plan for infra changes.
- **Multi-env:** shared modules + per-env `gitops/clusters/<env>` and Terraform workspaces; promote dev → prod after checks.
- **Reliability:** declarative Git state, idempotent Ansible, validate/plan in CI; no ad-hoc prod `kubectl edit`.
- **Security:** segmented network, default-deny policies where defined, external secrets, short-lived creds where possible, signed/supply-chain practices as you mature.
