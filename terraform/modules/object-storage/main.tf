# Hetzner Object Storage is S3-compatible; bucket lifecycle is not in the hcloud API.
# Use this module with the MinIO provider + Hetzner S3 keys (see Hetzner docs).
resource "minio_s3_bucket" "backups" {
  provider = minio.os

  bucket         = var.bucket_name
  acl            = var.acl
  object_locking = var.object_locking

  # Must be literal (Terraform does not allow variables in lifecycle). To drop the bucket, remove this block temporarily.
  lifecycle {
    prevent_destroy = true
  }
}
