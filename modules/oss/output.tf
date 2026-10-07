output "tags" {
  description = "Tags applied to the bucket."
  value       = alicloud_oss_bucket.this.tags
}

output "bucket" {
  description = "Bucket name."
  value       = alicloud_oss_bucket.this.bucket
}

output "extranet_endpoint" {
  description = "Public (extranet) endpoint of the bucket."
  value       = alicloud_oss_bucket.this.extranet_endpoint
}

output "intranet_endpoint" {
  description = "Internal (intranet) endpoint of the bucket."
  value       = alicloud_oss_bucket.this.intranet_endpoint
}

output "visibility" {
  description = "private or public."
  value       = var.visibility
}
