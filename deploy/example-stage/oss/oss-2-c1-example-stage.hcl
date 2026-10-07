locals {
  name            = "oss-2-c1-example-stage"
  tags            = { product = "example" }
  storage_class   = "Standard"
  redundancy_type = "LRS"

  # public: anyone can read every object anonymously; writes need the AccessKey of ram_user.
  # Fails if the account-level Block Public Access is on.
  visibility        = "public"
  ram_user          = "ram-oss-2-c1-example-stage"
  versioning        = null
  sse_algorithm     = "AES256"
  kms_master_key_id = null
  force_destroy     = false

  lifecycle_rules = [
    { id = "abort-multipart", abort_multipart_upload_days = 7 },
  ]
}
