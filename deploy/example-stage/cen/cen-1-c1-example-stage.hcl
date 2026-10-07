locals {
  name        = "cen-1-c1-example-stage"
  tags        = { product = "example" }
  description = "Example stage CEN: hub vpc-2 and spoke vpc-3 over one transit router"

  # vpc-1 stays on peer-1 with the hub: a CEN route for the same CIDRs would duplicate the peering routes.
  attachments = {
    tra-2-c1-example-stage = {
      vpc       = "vpc-2-c1-example-stage"
      vswitches = ["shared-a-2-c1-example-stage", "shared-b-2-c1-example-stage"]
    }
    tra-3-c1-example-stage = {
      vpc       = "vpc-3-c1-example-stage"
      vswitches = ["subnet-a-3-c1-example-stage", "subnet-b-3-c1-example-stage"]
    }
  }

  # cen_id joins an existing CEN from another region's leaf. peer_attachments (literal peer transit router ID and region) and
  # remote_attachment_ids (the peer region's attachment IDs, to associate and propagate here) wire the inter-region link.
}
