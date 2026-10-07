locals {
  instance_tags = { for k, i in var.instances : k => merge(var.tags, i.tags) }

  # Key <instance>/<disk name>: stable, independent of list order.
  data_disks = merge([
    for k, i in var.instances : {
      for d in i.data_disks : "${k}/${d.name}" => merge(d, { instance = k, zone_id = alicloud_instance.this[k].availability_zone })
    }
  ]...)

  key_pairs = { for k, i in var.instances : k => i if i.public_key != null || i.generate_key_pair }
  key_names = {
    for k, i in var.instances : k => i.key_name != null ? i.key_name : (contains(keys(local.key_pairs), k) ? alicloud_ecs_key_pair.this[k].key_pair_name : null)
  }

  # Sensitive var.password must not reach for_each keys.
  env_password = nonsensitive(var.password != null)
  random_login = local.env_password ? {} : { for k, i in var.instances : k => i if local.key_names_given[k] == false }
  # Known at plan time, unlike key_names, so for_each can use it.
  key_names_given = { for k, i in var.instances : k => i.key_name != null || i.public_key != null || i.generate_key_pair }

  login_passwords = {
    for k, i in var.instances : k => local.key_names_given[k] ? null : (local.env_password ? var.password : random_password.login[k].result)
  }
}
