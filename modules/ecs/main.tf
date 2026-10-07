resource "random_password" "login" {
  for_each = local.random_login

  length      = each.value.password_length
  special     = false
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
}

# Without public_key Alibaba generates the pair; the private key is returned once and written only to key_file.
resource "alicloud_ecs_key_pair" "this" {
  for_each = local.key_pairs

  key_pair_name = each.key
  public_key    = each.value.public_key
  key_file      = each.value.generate_key_pair ? "${var.private_key_dir}/${each.key}.pem" : null
  tags          = local.instance_tags[each.key]

  lifecycle {
    # key_file is ForceNew and its directory differs per run; the key exists only in the creating apply.
    ignore_changes = [key_file]

    precondition {
      condition     = !each.value.generate_key_pair || var.private_key_dir != null
      error_message = "Instance ${each.key}: generate_key_pair needs private_key_dir to receive the private key."
    }
  }
}

resource "alicloud_instance" "this" {
  for_each = var.instances

  instance_name        = each.key
  host_name            = each.value.host_name
  description          = each.value.description
  instance_type        = each.value.instance_type
  image_id             = each.value.image_id
  vswitch_id           = each.value.vswitch_id
  security_groups      = each.value.security_group_ids
  private_ip           = each.value.private_ip
  key_name             = local.key_names[each.key]
  password             = local.login_passwords[each.key]
  user_data            = each.value.user_data
  system_disk_category = each.value.system_disk_category
  system_disk_size     = each.value.system_disk_size
  # Null keeps the provider default; category is ForceNew, size and level are in place.
  system_disk_performance_level = each.value.system_disk_performance_level
  system_disk_encrypted         = each.value.system_disk_encrypted
  system_disk_kms_key_id        = each.value.system_disk_kms_key_id
  # Public IP is only allocated when bandwidth is set; 0 keeps the instance private.
  internet_max_bandwidth_out = each.value.internet_max_bw_out
  instance_charge_type       = "PostPaid"
  deletion_protection        = each.value.deletion_protection
  tags                       = local.instance_tags[each.key]
  volume_tags                = local.instance_tags[each.key]

  lifecycle {
    precondition {
      condition     = contains(var.zones, each.value.zone_id)
      error_message = "Instance ${each.key}: zone_id ${each.value.zone_id} is not one of the registered zones."
    }

    # The zone follows the vSwitch, so a wrong declared zone_id would otherwise surface as a disk attach failure.
    postcondition {
      condition     = self.availability_zone == each.value.zone_id
      error_message = "Instance ${each.key}: vswitch ${each.value.vswitch_id} is in ${self.availability_zone}, not the declared zone_id ${each.value.zone_id}."
    }
  }
}

# Data disks are separate resources so adding, growing or retuning one never recreates the instance.
resource "alicloud_ecs_disk" "data" {
  for_each = local.data_disks

  zone_id           = each.value.zone_id
  disk_name         = "${each.value.instance}-${each.value.name}"
  size              = each.value.size
  category          = each.value.category
  performance_level = each.value.performance_level
  encrypted         = each.value.encrypted
  kms_key_id        = each.value.kms_key_id
  type              = each.value.resize_type
  payment_type      = "PayAsYouGo"
  tags              = local.instance_tags[each.value.instance]
}

resource "alicloud_ecs_disk_attachment" "data" {
  for_each = local.data_disks

  disk_id     = alicloud_ecs_disk.data[each.key].id
  instance_id = alicloud_instance.this[each.value.instance].id
}
