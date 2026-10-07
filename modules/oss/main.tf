locals {
  public = var.visibility == "public"
}

resource "alicloud_oss_bucket" "this" {
  bucket          = var.name
  storage_class   = var.storage_class
  redundancy_type = var.redundancy_type
  force_destroy   = var.force_destroy
  tags            = var.tags

  server_side_encryption_rule {
    sse_algorithm     = var.sse_algorithm
    kms_master_key_id = var.sse_algorithm == "KMS" ? var.kms_master_key_id : null
  }

  dynamic "versioning" {
    for_each = var.versioning == null ? [] : [var.versioning]
    content {
      status = versioning.value
    }
  }

  dynamic "lifecycle_rule" {
    for_each = var.lifecycle_rules
    content {
      id      = lifecycle_rule.value.id
      prefix  = lifecycle_rule.value.prefix
      enabled = lifecycle_rule.value.enabled

      dynamic "expiration" {
        for_each = lifecycle_rule.value.expiration_days == null ? [] : [lifecycle_rule.value.expiration_days]
        content {
          days = expiration.value
        }
      }

      dynamic "transitions" {
        for_each = lifecycle_rule.value.transitions
        content {
          days          = transitions.value.days
          storage_class = transitions.value.storage_class
        }
      }

      dynamic "abort_multipart_upload" {
        for_each = lifecycle_rule.value.abort_multipart_upload_days == null ? [] : [lifecycle_rule.value.abort_multipart_upload_days]
        content {
          days = abort_multipart_upload.value
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = lifecycle_rule.value.noncurrent_version_expiration_days == null ? [] : [lifecycle_rule.value.noncurrent_version_expiration_days]
        content {
          days = noncurrent_version_expiration.value
        }
      }
    }
  }

  lifecycle {
    # policy is owned by the separate resource below; acl is computed and never set here, so it needs no entry.
    ignore_changes = [policy]

    precondition {
      condition     = var.sse_algorithm == "KMS" || var.kms_master_key_id == null
      error_message = "kms_master_key_id requires sse_algorithm = KMS."
    }
  }
}

# OSS rejects ACL, public-access-block and policy calls made right after the bucket is created.
# fixed 30s; make it an input if a region needs longer.
resource "time_sleep" "bucket_ready" {
  create_duration = "30s"
  triggers        = { bucket = alicloud_oss_bucket.this.bucket }
}

resource "alicloud_oss_bucket_public_access_block" "this" {
  bucket              = time_sleep.bucket_ready.triggers.bucket
  block_public_access = !local.public
}

# A public ACL is rejected while the block is on, so the block is set first.
resource "alicloud_oss_bucket_acl" "this" {
  bucket = time_sleep.bucket_ready.triggers.bucket
  acl    = local.public ? "public-read" : "private"

  depends_on = [alicloud_oss_bucket_public_access_block.this]
}

data "alicloud_account" "current" {}

# Object read-write only: bucket admin actions stay out so the key cannot undo this module.
resource "alicloud_oss_bucket_policy" "this" {
  bucket = time_sleep.bucket_ready.triggers.bucket
  policy = jsonencode({
    Version = "1"
    Statement = [{
      Effect    = "Allow"
      Principal = [var.ram_user_id]
      Action = [
        "oss:GetObject",
        "oss:PutObject",
        "oss:DeleteObject",
        "oss:ListObjects",
        "oss:AbortMultipartUpload",
        "oss:ListParts",
        "oss:ListMultipartUploads",
        "oss:GetBucketInfo",
      ]
      Resource = [
        "acs:oss:*:${data.alicloud_account.current.id}:${var.name}",
        "acs:oss:*:${data.alicloud_account.current.id}:${var.name}/*",
      ]
    }]
  })

  depends_on = [alicloud_oss_bucket_acl.this]
}
