locals {
  name        = "sg-1-c1-example-stage"
  tags        = { product = "example" }
  vpc         = "vpc-1-c1-example-stage"
  description = "Example stage ECS access from inside the VPC"

  # A rule without cidr_ip or source_security_group_id defaults to the VPC CIDR.
  rules = [
    { name = "ssh-vpc", type = "ingress", ip_protocol = "tcp", port_range = "22/22", description = "SSH from VPC" },
    { name = "http-vpc", type = "ingress", ip_protocol = "tcp", port_range = "80/80", description = "HTTP from VPC" },
  ]
}
