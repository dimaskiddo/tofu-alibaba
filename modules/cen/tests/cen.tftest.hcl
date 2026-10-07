mock_provider "alicloud" {}

override_data {
  target = data.alicloud_regions.current
  values = {
    regions = [{ id = "ap-southeast-5", local_name = "Jakarta", region_id = "ap-southeast-5" }]
  }
}

override_data {
  target = data.alicloud_cen_transit_router_route_tables.system
  values = {
    tables = [{ id = "tr-mock:vtb-mock", transit_router_route_table_id = "vtb-mock" }]
  }
}

variables {
  cen_name = "cen-1-c1-example-stage"
  zones    = ["ap-southeast-5a", "ap-southeast-5b"]
  tags     = { env = "stage" }
  vpc_attachments = {
    tra-1-c1-example-stage = {
      vpc_id = "vpc-aaa"
      zone_mappings = [
        { vswitch_id = "vsw-a", zone_id = "ap-southeast-5a" },
        { vswitch_id = "vsw-b", zone_id = "ap-southeast-5b" },
      ]
    }
  }
}

run "valid" {
  command = plan

  assert {
    condition = (alicloud_cen_instance.this[0].tags["env"] == "stage" && alicloud_cen_transit_router.this.tags["env"] == "stage"
    && alicloud_cen_transit_router_vpc_attachment.this["tra-1-c1-example-stage"].tags["env"] == "stage")
    error_message = "tags must propagate to the CEN, the transit router and the attachments"
  }
}

run "existing_cen_id_skips_instance" {
  command = plan
  variables { cen_id = "cen-existing" }

  assert {
    condition     = length(alicloud_cen_instance.this) == 0 && alicloud_cen_transit_router.this.cen_id == "cen-existing"
    error_message = "a given cen_id must not create a CEN instance"
  }
}

run "association_per_attachment" {
  command = plan
  variables {
    peer_attachments      = { peer-1-c1-example-stage = { peer_transit_router_id = "tr-peer", peer_region_id = "ap-southeast-1", bandwidth = 10 } }
    remote_attachment_ids = { remote-1-c1-example-stage = "tr-attach-remote" }
  }

  assert {
    condition     = length(alicloud_cen_transit_router_route_table_association.this) == 3 && length(alicloud_cen_transit_router_route_table_propagation.this) == 3
    error_message = "every vpc, peer and remote attachment needs one association and one propagation"
  }
}

run "peer_defaults" {
  command = plan
  variables {
    peer_attachments = { peer-1-c1-example-stage = { peer_transit_router_id = "tr-peer", peer_region_id = "ap-southeast-1", bandwidth = 10 } }
  }

  assert {
    condition     = alicloud_cen_transit_router_peer_attachment.this["peer-1-c1-example-stage"].bandwidth_type == "DataTransfer" && alicloud_cen_transit_router_peer_attachment.this["peer-1-c1-example-stage"].default_link_type == "Gold"
    error_message = "peer attachments must be DataTransfer and Gold by default"
  }
}

run "single_zone_region_one_vswitch_ok" {
  command = plan
  variables {
    zones = ["ap-southeast-5a"]
    vpc_attachments = {
      tra-1-c1-example-stage = { vpc_id = "vpc-aaa", zone_mappings = [{ vswitch_id = "vsw-a", zone_id = "ap-southeast-5a" }] }
    }
  }

  assert {
    condition     = length(alicloud_cen_transit_router_vpc_attachment.this) == 1
    error_message = "one zone registered must accept one vSwitch"
  }
}

run "bad_cen_name_rejected" {
  command = plan
  variables { cen_name = "CEN_1" }
  expect_failures = [var.cen_name]
}

run "bad_cen_id_rejected" {
  command = plan
  variables { cen_id = "xyz" }
  expect_failures = [var.cen_id]
}

run "empty_zones_rejected" {
  command = plan
  variables { zones = [] }
  expect_failures = [var.zones]
}

run "bad_vpc_id_rejected" {
  command = plan
  variables {
    vpc_attachments = {
      tra-1-c1-example-stage = { vpc_id = "abc", zone_mappings = [{ vswitch_id = "vsw-a", zone_id = "ap-southeast-5a" }, { vswitch_id = "vsw-b", zone_id = "ap-southeast-5b" }] }
    }
  }
  expect_failures = [var.vpc_attachments]
}

run "bad_vswitch_id_rejected" {
  command = plan
  variables {
    vpc_attachments = {
      tra-1-c1-example-stage = { vpc_id = "vpc-aaa", zone_mappings = [{ vswitch_id = "abc", zone_id = "ap-southeast-5a" }, { vswitch_id = "vsw-b", zone_id = "ap-southeast-5b" }] }
    }
  }
  expect_failures = [var.vpc_attachments]
}

run "zone_not_registered_rejected" {
  command = plan
  variables {
    vpc_attachments = {
      tra-1-c1-example-stage = { vpc_id = "vpc-aaa", zone_mappings = [{ vswitch_id = "vsw-a", zone_id = "ap-southeast-5a" }, { vswitch_id = "vsw-c", zone_id = "ap-southeast-5c" }] }
    }
  }
  expect_failures = [var.vpc_attachments]
}

run "single_zone_in_two_zone_region_rejected" {
  command = plan
  variables {
    vpc_attachments = {
      tra-1-c1-example-stage = { vpc_id = "vpc-aaa", zone_mappings = [{ vswitch_id = "vsw-a", zone_id = "ap-southeast-5a" }, { vswitch_id = "vsw-b", zone_id = "ap-southeast-5a" }] }
    }
  }
  expect_failures = [var.vpc_attachments]
}

run "no_zone_mappings_rejected" {
  command = plan
  variables {
    vpc_attachments = { tra-1-c1-example-stage = { vpc_id = "vpc-aaa", zone_mappings = [] } }
  }
  expect_failures = [var.vpc_attachments]
}

run "peer_same_region_rejected" {
  command = plan
  variables {
    peer_attachments = { peer-1-c1-example-stage = { peer_transit_router_id = "tr-peer", peer_region_id = "ap-southeast-5", bandwidth = 10 } }
  }
  expect_failures = [alicloud_cen_transit_router_peer_attachment.this["peer-1-c1-example-stage"]]
}

run "bad_peer_tr_id_rejected" {
  command = plan
  variables {
    peer_attachments = { peer-1-c1-example-stage = { peer_transit_router_id = "abc", peer_region_id = "ap-southeast-1", bandwidth = 10 } }
  }
  expect_failures = [var.peer_attachments]
}

run "zero_bandwidth_rejected" {
  command = plan
  variables {
    peer_attachments = { peer-1-c1-example-stage = { peer_transit_router_id = "tr-peer", peer_region_id = "ap-southeast-1", bandwidth = 0 } }
  }
  expect_failures = [var.peer_attachments]
}

run "bad_link_type_rejected" {
  command = plan
  variables {
    peer_attachments = { peer-1-c1-example-stage = { peer_transit_router_id = "tr-peer", peer_region_id = "ap-southeast-1", bandwidth = 10, link_type = "Silver" } }
  }
  expect_failures = [var.peer_attachments]
}

run "name_collision_rejected" {
  command = plan
  variables {
    remote_attachment_ids = { tra-1-c1-example-stage = "tr-attach-remote" }
  }
  expect_failures = [var.remote_attachment_ids]
}

run "empty_remote_id_rejected" {
  command = plan
  variables {
    remote_attachment_ids = { remote-1-c1-example-stage = "" }
  }
  expect_failures = [var.remote_attachment_ids]
}

run "empty_tags_rejected" {
  command = plan
  variables { tags = {} }
  expect_failures = [var.tags]
}
