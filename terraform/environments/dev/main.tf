

module "kubernetes" {
  source = "../../modules/kubernetes"

  cluster_name = "dev-test"
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

  lb_type = "lb11"
  lb_services = [
    {
      protocol              = "tcp"
      listen_port           = 443
      destination_port      = 6443
      proxyprotocol         = false
      health_check_protocol = "tcp"
      health_check_port     = 6443
      health_check_interval = 10
      health_check_timeout  = 5
      health_check_retries  = 3
    }
  ]

  labels = {
    environment = "dev"
    cluster     = "test"
  }
}

output "nodes" {
  value = {
    jump    = module.kubernetes.jump
    master  = module.kubernetes.master
    workers = module.kubernetes.workers
  }
}

output "kube_api_load_balancer_ipv4" {
  value = module.kubernetes.load_balancer.ipv4
}

output "cluster_nat_egress" {
  value = module.kubernetes.cluster_nat_egress
}
