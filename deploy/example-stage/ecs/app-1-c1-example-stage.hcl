locals {
  name            = "app-1-c1-example-stage"
  description     = "Example stage application server"
  zone_id         = "ap-southeast-5a"
  subnet          = "subnet-a-1-c1-example-stage"
  instance_type   = "ecs.g7.large"
  private_ip      = "10.0.10.10"
  security_groups = ["sg-1-c1-example-stage"]
  tags            = { product = "example" }

  # No key pair: <TENANT>_<ENV>_ECS_PASSWORD if set, otherwise a random password of password_length (default 8).

  # image_id defaults to <TENANT>_<ENV>_ECS_IMAGE_ID (a public image ID, ECS console DescribeImages) set before plan.
  system_disk_category          = "cloud_essd"
  system_disk_performance_level = "PL0"
  system_disk_size              = 40
  system_disk_encrypted         = true
  system_disk_kms_key           = "kms-1-c1-example-stage"

  # Add or grow an entry in place (online resize, grow only); a new entry attaches a new disk without touching the instance.
  data_disks = [
    { name = "data", size = 100, category = "cloud_essd", performance_level = "PL0", encrypted = true, kms_key = "kms-1-c1-example-stage" },
  ]
}
