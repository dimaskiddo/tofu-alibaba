resource "alicloud_vpc" "this" {
  vpc_name    = var.vpc_name
  cidr_block  = var.cidr_block
  description = var.description
  tags        = var.tags
}
