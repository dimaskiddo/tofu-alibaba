locals {
  accounts = { for a in var.accounts : a.name => a }
  # Privileges are granted per account, so accounts without databases get none.
  grants    = { for k, a in local.accounts : k => a if length(a.databases) > 0 }
  databases = { for d in var.databases : d.name => d }
  role_arn  = var.role_arn != null ? var.role_arn : (var.encryption_key != null ? "acs:ram::${data.alicloud_account.this.id}:role/aliyunrdsinstanceencryptiondefaultrole" : null)
}
