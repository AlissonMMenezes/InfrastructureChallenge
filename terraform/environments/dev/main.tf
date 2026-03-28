locals {
  object_storage_bucket_name = trimspace(var.object_storage_bucket_name) != "" ? trimspace(var.object_storage_bucket_name) : "${var.cluster_name}-cnpg-backups"
}

check "object_storage_credentials_when_enabled" {
  assert {
    condition = !var.object_storage_enabled || (
      length(var.object_storage_access_key) > 0 && length(var.object_storage_secret_key) > 0
    )
    error_message = "When object_storage_enabled is true, set object_storage_access_key and object_storage_secret_key (Hetzner Cloud Console → Object Storage → S3 credentials)."
  }
}

module "kubernetes" {
  source = "../../modules/kubernetes"

  cluster_name = var.cluster_name
  location     = "fsn1"
  network_zone = "eu-central"

  network_cidr        = "10.50.0.0/16"
  jump_subnet_cidr    = "10.50.1.0/24"
  cluster_subnet_cidr = "10.50.2.0/24"
  jump_private_ip     = "10.50.1.10"

  ssh_public_key     = var.ssh_public_key
  master_server_type = var.master_server_type
  worker_server_type = var.worker_server_type

  master_private_ip  = "10.50.2.10"
  worker_count       = 1
  worker_private_ips = ["10.50.2.11"]

  # Control-plane and workers: private only; SSH/API via jump + LB
  master_public_ipv4_enabled  = false
  master_public_ipv6_enabled  = false
  workers_public_ipv4_enabled = false
  workers_public_ipv6_enabled = false

  jump_public_ipv4_enabled = true
  jump_public_ipv6_enabled = false

  # Optional: dedicated LB → control-plane:6443 (kubectl from the Internet). Workers LB is always on by default (see module lb_services).
  expose_kubernetes_api_via_load_balancer = false
  kubernetes_api_lb_listen_port           = 443

  lb_type = "lb11"
  # Workers LB: uses module default (TCP 80→30080, 443→30443). Set lb_services = [] to disable.

  labels = {
    environment = "dev"
    cluster     = "test"
  }
}

module "object_storage" {
  source = "../../modules/object-storage"
  count  = var.object_storage_enabled ? 1 : 0

  providers = {
    minio.os = minio.hcloud_os
  }

  bucket_name    = local.object_storage_bucket_name
  acl            = "private"
  object_locking = false
}

output "nodes" {
  value = {
    jump    = module.kubernetes.jump
    master  = module.kubernetes.master
    workers = module.kubernetes.workers
  }
}

output "kube_api_load_balancer_ipv4" {
  description = "Public IPv4 of the optional Kubernetes API load balancer (null if disabled)"
  value       = module.kubernetes.kube_api_load_balancer != null ? module.kubernetes.kube_api_load_balancer.ipv4 : null
}

output "workers_load_balancer_ipv4" {
  description = "Public IPv4 of the workers load balancer (module default unless lb_services = [])"
  value       = module.kubernetes.load_balancer != null ? module.kubernetes.load_balancer.ipv4 : null
}

output "cluster_nat_egress" {
  value = module.kubernetes.cluster_nat_egress
}

output "object_storage_bucket_name" {
  description = "S3 bucket for backups (null if object_storage_enabled is false)"
  value       = try(module.object_storage[0].bucket_name, null)
}

output "object_storage_s3_endpoint" {
  description = "S3 API hostname for backup clients (same region as cluster location recommended)"
  value       = var.object_storage_enabled ? (var.object_storage_endpoint != "" ? var.object_storage_endpoint : "${var.object_storage_region}.your-objectstorage.com") : null
}

output "object_storage_region" {
  description = "Hetzner object storage region passed to the S3 client"
  value       = var.object_storage_enabled ? var.object_storage_region : null
}
