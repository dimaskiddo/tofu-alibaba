locals {
  name         = "nat-2-c1-example-stage"
  tags         = { product = "example" }
  network_type = "intranet"
  vpc          = "vpc-1-c1-example-stage"
  subnet       = "subnet-a-1-c1-example-stage"
  # Transit range from the hub VPC address plan: outside every hub vSwitch and the spoke CIDR.
  transit_cidr = "10.100.250.0/24"
  transit_ips = {
    snat-2-c1-example-stage = { ip = "10.100.250.10" }
    dnat-2-c1-example-stage = { ip = "10.100.250.20" }
  }
  description = "Example stage private NAT gateway"
}
