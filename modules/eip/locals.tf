locals {
  eips         = { for e in var.eips : e.name => e }
  associations = { for k, e in local.eips : k => e.instance_id if e.instance_id != null }
}
