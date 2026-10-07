# one user with one AccessKey and no console login; add policy attachments or groups when a consumer needs them.
resource "alicloud_ram_user" "this" {
  name     = var.name
  comments = var.comments
  tags     = var.tags
}

resource "alicloud_ram_access_key" "this" {
  user_name = alicloud_ram_user.this.name
}
