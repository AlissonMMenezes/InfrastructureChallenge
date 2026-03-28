terraform {
  required_providers {
    minio = {
      source                = "aminueza/minio"
      version               = ">= 3.3.0"
      configuration_aliases = [minio.os]
    }
  }
}
