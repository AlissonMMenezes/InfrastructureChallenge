variable "labels" {
  description = "Common labels for storage resources"
  type        = map(string)
  default     = {}
}

variable "volumes" {
  description = "Volumes to create"
  type = list(object({
    name              = string
    size              = number
    location          = string
    format            = string
    automount         = bool
    delete_protection = bool
    labels            = map(string)
  }))
  default = []
}

variable "attachments" {
  description = "Volume to server attachments"
  type = list(object({
    volume_name = string
    server_id   = number
    automount   = bool
  }))
  default = []
}
