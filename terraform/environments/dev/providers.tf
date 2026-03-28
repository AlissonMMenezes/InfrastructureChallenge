terraform {
  required_version = ">= 1.6.0"
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.50.0"
    }
    minio = {
      source  = "aminueza/minio"
      version = ">= 3.3.0"
    }
  }
}

provider "hcloud" {}

# Hetzner Object Storage (S3-compatible). Buckets are not managed by the hcloud provider; see module.object-storage.
# Generate keys: https://docs.hetzner.com/storage/object-storage/getting-started/generating-s3-keys
provider "minio" {
  alias = "hcloud_os"

  minio_server   = var.object_storage_endpoint != "" ? var.object_storage_endpoint : "${var.object_storage_region}.your-objectstorage.com"
  minio_user     = var.object_storage_enabled ? var.object_storage_access_key : "disabled-placeholder"
  minio_password = var.object_storage_enabled ? var.object_storage_secret_key : "disabled-placeholder"
  minio_region   = var.object_storage_region
  minio_ssl      = true
}
