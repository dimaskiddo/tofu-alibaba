locals {
  tenant      = "example"
  environment = "stage"

  # Tags on every resource of this tenant; instance files add their own (e.g. product).
  base_tags = { env = local.environment }

  # Credentials are never stored here. Export these on the machine or Atlantis server that runs Terragrunt;
  # root.hcl maps them to the names the provider and backend read. Required for init/plan/apply:
  #   EXAMPLE_STAGE_ALIBABA_CLOUD_ACCESS_KEY_ID
  #   EXAMPLE_STAGE_ALIBABA_CLOUD_ACCESS_KEY_SECRET
  # and for the state backend below:
  #   s3, oss:             EXAMPLE_STAGE_STATE_ACCESS_KEY_ID, EXAMPLE_STAGE_STATE_SECRET_ACCESS_KEY
  #   gitlab, gitea, http: EXAMPLE_STAGE_STATE_USERNAME, EXAMPLE_STAGE_STATE_PASSWORD
  # Optional: EXAMPLE_STAGE_ECS_PASSWORD, EXAMPLE_STAGE_RDS_ACCOUNT_PASSWORDS, EXAMPLE_STAGE_REDIS_PASSWORDS, EXAMPLE_STAGE_KAFKA_SASL_PASSWORDS, EXAMPLE_STAGE_ELASTICSEARCH_PASSWORDS (a missing password is generated).
  # Fallbacks for ecs image_id and kms dkms_instance_id when an instance file omits them: EXAMPLE_STAGE_ECS_IMAGE_ID, EXAMPLE_STAGE_KMS_INSTANCE_ID.
  # A copied tenant replaces the EXAMPLE_STAGE_ prefix with its own tenant and environment in upper case.
  state = {
    type                = "oss"
    bucket              = "example-tfstate"
    region              = "ap-southeast-5"
    endpoint            = "https://oss-ap-southeast-5.aliyuncs.com"
    tablestore_endpoint = "https://example-tflock.ap-southeast-5.ots.aliyuncs.com"
    tablestore_table    = "tflock"
  }
}
