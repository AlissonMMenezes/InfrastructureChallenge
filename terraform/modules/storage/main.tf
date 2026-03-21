terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.50.0"
    }
  }
}

locals {
  volumes_by_name = { for v in var.volumes : v.name => v }
  attachments = {
    for a in var.attachments : "${a.volume_name}:${a.server_id}" => a
  }
}

resource "hcloud_volume" "this" {
  for_each = local.volumes_by_name

  name              = each.value.name
  size              = each.value.size
  location          = each.value.location
  format            = each.value.format
  automount         = each.value.automount
  delete_protection = each.value.delete_protection
  labels            = merge(var.labels, each.value.labels)
}

resource "hcloud_volume_attachment" "this" {
  for_each = local.attachments

  volume_id = hcloud_volume.this[each.value.volume_name].id
  server_id = each.value.server_id
  automount = each.value.automount
}
