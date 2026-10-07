locals {
  name         = "clb-1-c1-example-stage"
  tags         = { product = "example" }
  address_type = "intranet"
  subnet       = "subnet-a-1-c1-example-stage"

  # `instance` is an ECS instance name from the ecs stack.
  backend_servers = {
    main = { instance = "app-1-c1-example-stage", port = 80 }
  }

  listeners = {
    http = { protocol = "http", frontend_port = 80, bandwidth = -1 }
  }
}
