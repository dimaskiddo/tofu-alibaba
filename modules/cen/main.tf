data "alicloud_regions" "current" {
  current = true
}

resource "alicloud_cen_instance" "this" {
  count = var.cen_id == null ? 1 : 0

  cen_instance_name = var.cen_name
  description       = var.description
  tags              = var.tags
}

locals {
  cen_id = var.cen_id == null ? one(alicloud_cen_instance.this[*].id) : var.cen_id
}

resource "alicloud_cen_transit_router" "this" {
  cen_id                     = local.cen_id
  transit_router_name        = var.cen_name
  transit_router_description = var.description
  tags                       = var.tags
}

# The transit router does not export its system route table.
data "alicloud_cen_transit_router_route_tables" "system" {
  transit_router_id               = alicloud_cen_transit_router.this.transit_router_id
  transit_router_route_table_type = "System"
}

resource "alicloud_cen_transit_router_vpc_attachment" "this" {
  for_each = var.vpc_attachments

  cen_id                                = local.cen_id
  transit_router_id                     = alicloud_cen_transit_router.this.transit_router_id
  vpc_id                                = each.value.vpc_id
  transit_router_vpc_attachment_name    = each.key
  transit_router_attachment_description = each.value.description
  tags                                  = var.tags

  dynamic "zone_mappings" {
    for_each = each.value.zone_mappings

    content {
      vswitch_id = zone_mappings.value.vswitch_id
      zone_id    = zone_mappings.value.zone_id
    }
  }
}

resource "alicloud_cen_transit_router_peer_attachment" "this" {
  for_each = var.peer_attachments

  cen_id                              = local.cen_id
  transit_router_id                   = alicloud_cen_transit_router.this.transit_router_id
  peer_transit_router_id              = each.value.peer_transit_router_id
  peer_transit_router_region_id       = each.value.peer_region_id
  bandwidth_type                      = "DataTransfer"
  bandwidth                           = each.value.bandwidth
  default_link_type                   = each.value.link_type
  transit_router_peer_attachment_name = each.key
  tags                                = var.tags

  lifecycle {
    precondition {
      condition     = each.value.peer_region_id != data.alicloud_regions.current.regions[0].region_id
      error_message = "peer_region_id must differ from the provider region: a CEN holds one transit router per region."
    }
  }
}

locals {
  attachment_ids = merge(
    { for n, a in alicloud_cen_transit_router_vpc_attachment.this : n => a.transit_router_attachment_id },
    { for n, a in alicloud_cen_transit_router_peer_attachment.this : n => a.transit_router_attachment_id },
  )
  routed_ids = merge(local.attachment_ids, var.remote_attachment_ids)
  table_id   = data.alicloud_cen_transit_router_route_tables.system.tables[0].transit_router_route_table_id
}

# The API associates and propagates nothing by default (only the console does).
resource "alicloud_cen_transit_router_route_table_association" "this" {
  for_each = local.routed_ids

  transit_router_attachment_id  = each.value
  transit_router_route_table_id = local.table_id
}

resource "alicloud_cen_transit_router_route_table_propagation" "this" {
  for_each = local.routed_ids

  transit_router_attachment_id  = each.value
  transit_router_route_table_id = local.table_id

  depends_on = [alicloud_cen_transit_router_route_table_association.this]
}
