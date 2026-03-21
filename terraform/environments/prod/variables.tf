variable "nodes" {
  description = "Kubernetes nodes for prod"
  type = list(object({
    name = string
    role = string
    ip   = string
  }))
  default = [
    { name = "prod-cp-1", role = "control-plane", ip = "10.52.10.11" },
    { name = "prod-wk-1", role = "worker", ip = "10.52.10.21" },
    { name = "prod-wk-2", role = "worker", ip = "10.52.10.22" }
  ]
}
