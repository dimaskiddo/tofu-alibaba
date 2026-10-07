locals {
  name         = "clb-2-c1-example-stage"
  tags         = { product = "example" }
  address_type = "internet"

  # PayByTraffic bills outbound traffic; listener bandwidth must then be -1.
  internet_charge_type = "PayByTraffic"

  # `instance` is an ECS instance name from the ecs stack.
  backend_servers = {
    main = { instance = "app-1-c1-example-stage", port = 80 }
  }

  listeners = {
    http = { protocol = "http", frontend_port = 80, bandwidth = -1 }
  }
}
