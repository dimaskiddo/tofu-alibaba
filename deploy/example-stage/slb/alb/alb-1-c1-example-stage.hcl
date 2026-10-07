locals {
  name                  = "alb-1-c1-example-stage"
  tags                  = { product = "example" }
  vpc                   = "vpc-1-c1-example-stage"
  address_type          = "Intranet"
  load_balancer_edition = "Basic"

  zone_mappings = [
    { zone_id = "ap-southeast-5a", subnet = "subnet-a-1-c1-example-stage" },
    { zone_id = "ap-southeast-5b", subnet = "subnet-b-1-c1-example-stage" },
  ]

  # `instance` is an ECS instance name from the ecs stack.
  server_groups = {
    "web-1-c1-example-stage" = {
      servers = [{ instance = "app-1-c1-example-stage", port = 80 }]
    }
  }

  listeners = {
    http = { protocol = "HTTP", port = 80, default_server_group = "web-1-c1-example-stage" }
  }
}
