locals {
  name        = "kms-2-c1-example-stage"
  tags        = { product = "example" }
  description = "Example stage RDS disk encryption"

  # Separate from kms-1 so disabling one key never locks the other service's disks.
  # dkms_instance_id defaults to <TENANT>_<ENV>_KMS_INSTANCE_ID, the ID of an existing KMS instance (bought in the console, not managed here).
}
