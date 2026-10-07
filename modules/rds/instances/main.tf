module "this" {
  source   = "../"
  for_each = var.instances

  name                     = each.key
  engine                   = each.value.engine
  engine_version           = each.value.engine_version
  category                 = each.value.category
  instance_type            = each.value.instance_type
  instance_storage         = each.value.instance_storage
  db_instance_storage_type = try(each.value.db_instance_storage_type, null)
  placement                = each.value.placement
  security_ips             = each.value.security_ips
  deletion_protection      = try(each.value.deletion_protection, null)
  maintain_time            = try(each.value.maintain_time, null)
  parameters               = try(each.value.parameters, null)
  storage_auto_scale       = try(each.value.storage_auto_scale, null)
  backup                   = try(each.value.backup, null)
  databases                = try(each.value.databases, null)
  accounts                 = try(each.value.accounts, null)
  account_passwords        = try(var.account_passwords[each.key], {})
  password_length          = try(each.value.password_length, null)
  encryption_key           = try(each.value.encryption_key, null)
  role_arn                 = try(each.value.role_arn, null)
  tags                     = merge(var.tags, try(each.value.tags, {}))
}
