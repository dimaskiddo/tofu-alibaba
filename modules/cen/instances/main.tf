module "this" {
  source   = "../"
  for_each = var.instances

  cen_name              = each.key
  cen_id                = try(each.value.cen_id, null)
  description           = try(each.value.description, null)
  zones                 = var.zones
  vpc_attachments       = try(each.value.vpc_attachments, {})
  peer_attachments      = try(each.value.peer_attachments, {})
  remote_attachment_ids = try(each.value.remote_attachment_ids, {})
  tags                  = merge(var.tags, try(each.value.tags, {}))
}
