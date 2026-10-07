variable "name" {
  type        = string
  description = "Bucket name, <component>-<instance>-c1-<tenant>-<env>. OSS bucket names are global across all customers (ForceNew)."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.name))
    error_message = "name must be 3-63 chars: lowercase letters, digits and '-', starting and ending with a letter or digit."
  }
}

variable "storage_class" {
  type        = string
  description = "Default storage class (ForceNew)."
  default     = "Standard"
  nullable    = false

  validation {
    condition     = contains(["Standard", "IA", "Archive", "ColdArchive", "DeepColdArchive"], var.storage_class)
    error_message = "storage_class must be Standard, IA, Archive, ColdArchive or DeepColdArchive."
  }
}

variable "redundancy_type" {
  type        = string
  description = "Data redundancy: LRS or ZRS (ForceNew)."
  default     = "LRS"
  nullable    = false

  validation {
    condition     = contains(["LRS", "ZRS"], var.redundancy_type)
    error_message = "redundancy_type must be LRS or ZRS."
  }
}

variable "visibility" {
  type        = string
  description = "private = public access blocked, ACL private. public = block off, ACL public-read (anonymous read of every object)."
  default     = "private"
  nullable    = false

  validation {
    condition     = contains(["private", "public"], var.visibility)
    error_message = "visibility must be private or public."
  }
}

variable "ram_user_id" {
  type        = string
  description = "RAM user ID (modules/ram output user_id) granted object read-write by the bucket policy."

  validation {
    condition     = can(regex("^[0-9]+$", var.ram_user_id))
    error_message = "ram_user_id must be a numeric RAM user ID."
  }
}

variable "versioning" {
  type        = string
  description = "Enabled or Suspended. Null leaves versioning off; once enabled it can only be suspended, never removed."
  default     = null

  validation {
    condition     = var.versioning == null ? true : contains(["Enabled", "Suspended"], var.versioning)
    error_message = "versioning must be Enabled, Suspended or null."
  }
}

variable "sse_algorithm" {
  type        = string
  description = "Server-side encryption: AES256 (OSS-managed key) or KMS."
  default     = "AES256"
  nullable    = false

  validation {
    condition     = contains(["AES256", "KMS"], var.sse_algorithm)
    error_message = "sse_algorithm must be AES256 or KMS."
  }
}

variable "kms_master_key_id" {
  type        = string
  description = "KMS key ID for sse_algorithm = KMS. Null uses the OSS service key."
  default     = null
}

variable "lifecycle_rules" {
  type = list(object({
    id                                 = string
    prefix                             = optional(string, "")
    enabled                            = optional(bool, true)
    expiration_days                    = optional(number)
    abort_multipart_upload_days        = optional(number)
    noncurrent_version_expiration_days = optional(number)
    transitions = optional(list(object({
      days          = number
      storage_class = string
    })), [])
  }))
  description = "Lifecycle rules. Each rule needs a unique id and at least one action."
  default     = []
  nullable    = false

  validation {
    condition     = length(distinct([for r in var.lifecycle_rules : r.id])) == length(var.lifecycle_rules)
    error_message = "lifecycle_rules ids must be unique."
  }

  validation {
    condition = alltrue([
      for r in var.lifecycle_rules : r.expiration_days != null || r.abort_multipart_upload_days != null || r.noncurrent_version_expiration_days != null || length(r.transitions) > 0
    ])
    error_message = "Every lifecycle rule needs at least one action (expiration_days, transitions, abort_multipart_upload_days or noncurrent_version_expiration_days)."
  }

  validation {
    condition = alltrue(flatten([
      for r in var.lifecycle_rules : concat(
        [for d in [r.expiration_days, r.abort_multipart_upload_days, r.noncurrent_version_expiration_days] : d >= 1 && floor(d) == d if d != null],
        [for t in r.transitions : t.days >= 1 && floor(t.days) == t.days],
      )
    ]))
    error_message = "Lifecycle day counts must be whole numbers of at least 1."
  }

  validation {
    condition     = alltrue(flatten([for r in var.lifecycle_rules : [for t in r.transitions : contains(["IA", "Archive", "ColdArchive", "DeepColdArchive"], t.storage_class)]]))
    error_message = "Transition storage_class must be IA, Archive, ColdArchive or DeepColdArchive."
  }

  validation {
    condition     = alltrue(flatten([for r in var.lifecycle_rules : [for t in r.transitions : r.expiration_days == null || t.days < r.expiration_days]]))
    error_message = "A transition days value must be smaller than the rule's expiration_days."
  }
}

variable "force_destroy" {
  type        = bool
  description = "Delete the bucket even when it holds objects. Keep false outside throwaway stacks."
  default     = false
  nullable    = false
}

variable "tags" {
  type        = map(string)
  description = "Resource tags. At least one tag is required."
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
