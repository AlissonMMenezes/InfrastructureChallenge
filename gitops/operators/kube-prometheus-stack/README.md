# kube-prometheus-stack (Flux)

Installs [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack):

| Component | Role |
|-----------|------|
| **Prometheus Operator** | Manages `Prometheus`, `Alertmanager`, `ServiceMonitor`, `PodMonitor`, `PrometheusRule` |
| **Prometheus** | Scrapes metrics (cluster + ServiceMonitors) |
| **kube-state-metrics** | Exposes Kubernetes object state as metrics |
| **prometheus-node-exporter** | DaemonSet — node CPU/mem/disk/network exporters |
| **Grafana** | Dashboards (in-memory storage by default; enable persistence in values if needed) |
| **Alertmanager** | Alert routing (single replica in this profile) |

**Flux CD monitoring:** **`PodMonitor/flux-controllers`** in **`flux-system`** scrapes Flux controller metrics (`gotk_*`, controller-runtime). **`kube-state-metrics`** **custom resource state** exports **`gotk_resource_info`** for GitRepository, Kustomization, HelmRelease, etc. (from [flux2-monitoring-example](https://github.com/fluxcd/flux2-monitoring-example)). **`HelmRelease`** merges **`flux-values-fragment.yaml`** via **`valuesFrom`** **`ConfigMap/kube-prometheus-stack-flux-monitoring`**. Grafana imports the upstream **Flux** / **Flux Control Plane** dashboards into folder **Flux**.

Default chart **ServiceMonitors** include kube-apiserver, kubelet/cAdvisor, coreDNS, kube-state-metrics, node-exporter, operator components, etc. Some control-plane components (etcd, scheduler) may need extra endpoints on non-standard clusters.

## Access

- **Grafana**: port-forward or expose via Ingress — retrieve admin password:  
  `kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d`
- **Prometheus**: port-forward `svc/kube-prometheus-stack-prometheus` in `monitoring` (port 9090).

## Custom metrics

Create **`ServiceMonitor`** / **`PodMonitor`** resources; Prometheus is configured to select them cluster-wide (`*SelectorNilUsesHelmValues: false`).
