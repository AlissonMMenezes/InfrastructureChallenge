output "bucket_name" {
  description = "S3 bucket name (use as CloudNativePG backup destination bucket)"
  value       = minio_s3_bucket.backups.bucket
}

output "bucket_id" {
  description = "Provider-specific bucket id"
  value       = minio_s3_bucket.backups.id
}
