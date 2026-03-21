# Leadership component answers

## 1) Team organization (3 DevOps engineers)

- **Platform Engineer A**: Terraform modules, networking, environment provisioning.
- **Platform Engineer B**: Kubernetes bootstrap (Ansible), node hardening, OS lifecycle.
- **Platform Engineer C**: GitOps, operators, observability, app onboarding.
- **Review process**:
  - mandatory PR review by at least one peer,
  - CODEOWNERS by domain,
  - infra changes require plan output attached.
- **Release management**:
  - weekly release train for non-urgent changes,
  - hotfix lane with post-incident review,
  - dev first, prod promotion after validation gates.

## 2) Multi-environment deployments

- **Customer-specific configuration**:
  - keep shared baseline modules,
  - overlay customer values in `clusters/<customer>-<env>`.
- **Infrastructure variations**:
  - use Terraform module composition and variable sets,
  - provider-specific wrappers with common interfaces.
- **Upgrades across customers**:
  - canary customer ring first,
  - progressive rollout waves,
  - rollback playbooks pre-approved.

## 3) Reliability

- **Repeatable deployments**:
  - immutable, versioned manifests,
  - idempotent provisioning/configuration,
  - no manual kubectl edits in production.
- **Automated testing**:
  - Terraform validate/plan checks,
  - Ansible lint + molecule smoke,
  - Kubernetes schema/policy tests + smoke deploy.
- **Safe infra changes**:
  - policy checks in CI,
  - protected branches and change windows,
  - backup verification before stateful updates.

## 4) Security

- **Network security**: segmented networks, deny-by-default policies, controlled ingress.
- **Data security**: encryption at rest/in transit, backup encryption, key rotation.
- **Runtime security**: minimal base images, runtime policies, audit logging.
- **Secrets management**: external secret stores and short-lived credentials.
- **Access management**: SSO + RBAC, just-in-time elevated access.
- **Supply chain security**: signed artifacts, SBOM, provenance and vulnerability gating.
