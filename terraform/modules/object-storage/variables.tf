variable "bucket_name" {
  description = "Globally unique bucket name (S3 naming rules: lowercase, hyphens, 3–63 chars)."
  type        = string
}

variable "acl" {
  description = "S3 canned ACL for the bucket"
  type        = string
  default     = "private"
}

variable "object_locking" {
  description = "Enable S3 object locking (immutable objects) if supported by the endpoint"
  type        = bool
  default     = false
}
