locals {
  rules = { for r in var.rules : r.name => r }
}
