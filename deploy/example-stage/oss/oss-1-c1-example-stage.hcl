locals {
  # Bucket names are global across Alibaba Cloud: if this one is taken, pick another before the first apply.
  # The name is ForceNew, like storage_class and redundancy_type.
  name            = "oss-1-c1-example-stage"
  tags            = { product = "example" }
  storage_class   = "Standard"
  redundancy_type = "LRS"

  # private: public access blocked, ACL private; only ram_user (leaf ram) can read and write objects.
  visibility        = "private"
  ram_user          = "ram-oss-1-c1-example-stage"
  versioning        = "Enabled"
  sse_algorithm     = "AES256"
  kms_master_key_id = null
  force_destroy     = false

  lifecycle_rules = [
    { id = "abort-multipart", abort_multipart_upload_days = 7 },
    { id = "expire-old-versions", noncurrent_version_expiration_days = 30 },
    { id = "archive-logs", prefix = "logs/", transitions = [{ days = 30, storage_class = "IA" }] },
  ]
}
