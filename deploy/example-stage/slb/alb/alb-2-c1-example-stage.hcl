locals {
  name                  = "alb-2-c1-example-stage"
  tags                  = { product = "example" }
  vpc                   = "vpc-1-c1-example-stage"
  address_type          = "Internet"
  load_balancer_edition = "Standard"

  # Internet ALB: Alibaba Cloud allocates one public IP per zone. The example has one vSwitch per zone, shared with the private services; use dedicated public vSwitches in a real tenant.
  zone_mappings = [
    { zone_id = "ap-southeast-5a", subnet = "subnet-a-1-c1-example-stage" },
    { zone_id = "ap-southeast-5b", subnet = "subnet-b-1-c1-example-stage" },
  ]

  # `instance` is an ECS instance name from the ecs stack.
  server_groups = {
    "web-2-c1-example-stage" = {
      servers = [{ instance = "app-1-c1-example-stage", port = 80 }]
    }
  }

  listeners = {
    http = { protocol = "HTTP", port = 80, default_server_group = "web-2-c1-example-stage" }
  }
}
