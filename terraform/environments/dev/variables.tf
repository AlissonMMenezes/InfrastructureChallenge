variable "cluster_name" {
  description = "Logical cluster name (used for labels and default backup bucket name)"
  type        = string
  default     = "dev-test"
}

variable "ssh_public_key" {
  description = "SSH public key for Hetzner nodes"
  type        = string
}

variable "master_server_type" {
  description = "Hetzner server type for Kubernetes master node"
  type        = string
  default     = "cx23"
}

variable "worker_server_type" {
  description = "Hetzner server type for Kubernetes worker nodes"
  type        = string
  default     = "cx23"
}

# --- Hetzner Object Storage (S3) for backups (CloudNativePG, etc.) ---
# Keys are created in Hetzner Cloud Console → Object Storage → S3 credentials.
# https://docs.hetzner.com/storage/object-storage/getting-started/generating-s3-keys

variable "object_storage_enabled" {
  description = "Create an S3 bucket on Hetzner Object Storage (MinIO provider). Requires S3 keys when true. Default false so plan works without Object Storage credentials."
  type        = bool
  default     = false
}

variable "object_storage_region" {
  description = "Hetzner location code matching object storage (e.g. fsn1, nbg1, hel1)."
  type        = string
  default     = "fsn1"
}

variable "object_storage_endpoint" {
  description = "Optional override for S3 endpoint host (default: {region}.your-objectstorage.com)."
  type        = string
  default     = ""
}

variable "object_storage_access_key" {
  description = "S3 access key (required when object_storage_enabled is true)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "object_storage_secret_key" {
  description = "S3 secret key (required when object_storage_enabled is true)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "object_storage_bucket_name" {
  description = "Globally unique bucket name. Empty = {cluster_name}-cnpg-backups"
  type        = string
  default     = ""
}

