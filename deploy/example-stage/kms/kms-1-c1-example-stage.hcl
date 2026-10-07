locals {
  name        = "kms-1-c1-example-stage"
  tags        = { product = "example" }
  description = "Example stage ECS disk encryption"

  # dkms_instance_id defaults to <TENANT>_<ENV>_KMS_INSTANCE_ID, the ID of an existing KMS instance (bought in the console, not managed here).
  # Automatic rotation every 365d; set rotation_interval = null to disable it.
}
