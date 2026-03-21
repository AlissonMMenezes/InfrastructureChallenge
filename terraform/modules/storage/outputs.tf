output "volumes" {
  value = {
    for k, v in hcloud_volume.this : k => {
      id       = v.id
      linux_id = v.linux_device
      size     = v.size
      status   = v.status
    }
  }
}
