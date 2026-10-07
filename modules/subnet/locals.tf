locals {
  subnets = { for s in var.subnets : s.name => s }
}
