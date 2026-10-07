variable "instances" {
  type        = any
  description = "Instances keyed by resource name (the instance `name` value). Each value takes the inputs of ../ except name; its optional tags merge over the shared tags."

  validation {
    condition     = length(var.instances) >= 1
    error_message = "At least one instance is required."
  }

  validation {
    condition = alltrue([
      for n, i in var.instances : can(keys(i)) ? alltrue([for k in keys(i) : contains(["storage_class", "redundancy_type", "visibility", "ram_user_id", "versioning", "sse_algorithm", "kms_master_key_id", "lifecycle_rules", "force_destroy", "tags"], k)]) : false
    ])
    error_message = "Instance entries accept only storage_class, redundancy_type, visibility, ram_user_id, versioning, sse_algorithm, kms_master_key_id, lifecycle_rules, force_destroy and tags."
  }

  validation {
    condition     = alltrue(flatten([for n, i in var.instances : [for x in coalesce(try(i.lifecycle_rules, null), []) : try(length(setsubtract(keys(x), ["id", "prefix", "enabled", "expiration_days", "abort_multipart_upload_days", "noncurrent_version_expiration_days", "transitions"])) == 0, false)]]))
    error_message = "lifecycle_rules entries: accepted keys are id, prefix, enabled, expiration_days, abort_multipart_upload_days, noncurrent_version_expiration_days, transitions."
  }

  validation {
    condition     = alltrue(flatten([for n, i in var.instances : flatten([for x in coalesce(try(i.lifecycle_rules, null), []) : [for y in try(x.transitions, []) : try(length(setsubtract(keys(y), ["days", "storage_class"])) == 0, false)]])]))
    error_message = "lifecycle_rules transitions: accepted keys are days, storage_class."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every instance. At least one tag is required."
  nullable    = false

  validation {
    condition     = length(var.tags) >= 1
    error_message = "At least one tag is required."
  }

  validation {
    condition     = alltrue([for k, v in var.tags : length(k) > 0 && length(v) > 0])
    error_message = "Tag keys and values must not be empty."
  }
}
