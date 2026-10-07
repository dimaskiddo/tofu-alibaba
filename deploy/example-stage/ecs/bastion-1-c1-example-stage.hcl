locals {
  name            = "bastion-1-c1-example-stage"
  description     = "Example stage bastion"
  zone_id         = "ap-southeast-5a"
  subnet          = "subnet-a-1-c1-example-stage"
  instance_type   = "ecs.g7.large"
  private_ip      = "10.0.10.11"
  security_groups = ["sg-1-c1-example-stage"]
  tags            = { product = "example" }

  # Alibaba generates the key pair; the private key (bastion-1-c1-example-stage.pem) exists only in the apply that creates it.
  # To bring your own instead, replace this line with: public_key = "ssh-rsa AAAA..." (or key_name = "<existing pair>").
  generate_key_pair = true

  # image_id defaults to <TENANT>_<ENV>_ECS_IMAGE_ID (a public image ID, ECS console DescribeImages) set before plan.
  system_disk_category          = "cloud_essd"
  system_disk_performance_level = "PL0"
  system_disk_size              = 40
}
