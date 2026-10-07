data "alicloud_regions" "current" {
  current = true
}

resource "alicloud_vpc_peer_connection" "this" {
  peer_connection_name = var.peer_name
  vpc_id               = var.vpc_id
  accepting_vpc_id     = var.accepting_vpc_id
  accepting_region_id  = var.accepting_region_id
  accepting_ali_uid    = var.accepting_ali_uid
  bandwidth            = var.bandwidth
  link_type            = var.link_type
  description          = var.description
  tags                 = var.tags

  lifecycle {
    precondition {
      condition     = (var.bandwidth == null && var.link_type == null) || var.accepting_region_id != data.alicloud_regions.current.regions[0].region_id
      error_message = "bandwidth and link_type are only valid for an inter-region peering."
    }
  }
}

# Same state as the peering, so destroy removes the routes before the connection.
resource "alicloud_route_entry" "requester" {
  count = var.route_table_id == null ? 0 : 1

  route_table_id        = var.route_table_id
  destination_cidrblock = var.accepting_vpc_cidr_block
  nexthop_type          = "VpcPeer"
  nexthop_id            = alicloud_vpc_peer_connection.this.id
  name                  = "${var.peer_name}-to-accepter"

  lifecycle {
    precondition {
      condition     = var.accepting_ali_uid == null
      error_message = "route_table_id cannot be used with a cross-account peering (accepting_ali_uid set); the accepter must accept it first."
    }
  }
}

resource "alicloud_route_entry" "accepter" {
  count = var.accepting_route_table_id == null ? 0 : 1

  route_table_id        = var.accepting_route_table_id
  destination_cidrblock = var.vpc_cidr_block
  nexthop_type          = "VpcPeer"
  nexthop_id            = alicloud_vpc_peer_connection.this.id
  name                  = "${var.peer_name}-to-requester"

  lifecycle {
    precondition {
      condition     = var.accepting_ali_uid == null
      error_message = "accepting_route_table_id cannot be used with a cross-account peering (accepting_ali_uid set)."
    }

    precondition {
      condition     = var.accepting_region_id == data.alicloud_regions.current.regions[0].region_id
      error_message = "accepting_route_table_id is only valid for an intra-region peering; add the accepter route with a route-table stack in ${var.accepting_region_id}."
    }
  }
}
