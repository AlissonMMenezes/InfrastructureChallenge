# kube-prometheus-stack (GitOps)

Helm chart (Flux): Prometheus Operator, Prometheus, Alertmanager, Grafana, node-exporter, kube-state-metrics.

**Flux:** **PodMonitor** for controllers in **`gitops/infrastructure/flux-podmonitor.yaml`**. KSM custom resource metrics + Grafana **Flux** dashboards via **`valuesFrom`** **`ConfigMap/kube-prometheus-stack-flux-monitoring`** / **`flux-values-fragment.yaml`**.

**CNPG:** `spec.monitoring.enablePodMonitor: true` on **Cluster** CRs → operator-created **PodMonitors** on **9187**. Prometheus **`podMonitorSelectorNilUsesHelmValues: false`** discovers them.

**OpenBao:** chart **ServiceMonitor** on metrics path when enabled in **`gitops/operators/openbao/helmrelease.yaml`**.

**Grafana:** admin password — **[operations.md — Monitoring](operations.md#monitoring)**. Ingress host in Helm values (see **[gitops.md](gitops.md)**).

**Custom scrape:** add **ServiceMonitor** / **PodMonitor** CRs cluster-wide.

Manifests: **`gitops/operators/kube-prometheus-stack/`**.
