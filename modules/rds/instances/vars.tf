variable "instances" {
  type        = any
  description = "Instances keyed by resource name (the instance `name` value). Each value takes the inputs of ../ except name; its optional tags merge over the shared tags."

  validation {
    condition     = length(var.instances) >= 1
    error_message = "At least one instance is required."
  }

  validation {
    condition = alltrue([
      for n, i in var.instances : can(keys(i)) ? alltrue([for k in keys(i) : contains(["engine", "engine_version", "category", "instance_type", "instance_storage", "db_instance_storage_type", "placement", "security_ips", "deletion_protection", "maintain_time", "parameters", "storage_auto_scale", "backup", "databases", "accounts", "password_length", "encryption_key", "role_arn", "tags"], k)]) : false
    ])
    error_message = "Instance entries accept only engine, engine_version, category, instance_type, instance_storage, db_instance_storage_type, placement, security_ips, deletion_protection, maintain_time, parameters, storage_auto_scale, backup, databases, accounts, password_length, encryption_key, role_arn and tags."
  }

  validation {
    condition     = alltrue(flatten([for n, i in var.instances : [for x in try(i.placement, []) : try(length(setsubtract(keys(x), ["zone_id", "vswitch_id"])) == 0, false)]]))
    error_message = "placement entries: accepted keys are zone_id, vswitch_id."
  }

  validation {
    condition     = alltrue(flatten([for n, i in var.instances : [for x in coalesce(try(i.databases, null), []) : try(length(setsubtract(keys(x), ["name", "character_set", "description"])) == 0, false)]]))
    error_message = "databases entries: accepted keys are name, character_set, description."
  }

  validation {
    condition     = alltrue(flatten([for n, i in var.instances : [for x in coalesce(try(i.accounts, null), []) : try(length(setsubtract(keys(x), ["name", "type", "description", "privilege", "databases"])) == 0, false)]]))
    error_message = "accounts entries: accepted keys are name, type, description, privilege, databases."
  }

  validation {
    condition     = alltrue(flatten([for n, i in var.instances : [for x in coalesce(try(i.parameters, null), []) : try(length(setsubtract(keys(x), ["name", "value"])) == 0, false)]]))
    error_message = "parameters entries: accepted keys are name, value."
  }

  validation {
    condition     = alltrue(flatten([for n, i in var.instances : [try(i.backup, null) == null ? true : try(length(setsubtract(keys(i.backup), ["preferred_backup_period", "preferred_backup_time", "backup_retention_period", "log_backup_retention_period"])) == 0, false)]]))
    error_message = "backup: accepted keys are preferred_backup_period, preferred_backup_time, backup_retention_period, log_backup_retention_period."
  }

  validation {
    condition     = alltrue(flatten([for n, i in var.instances : [try(i.storage_auto_scale, null) == null ? true : try(length(setsubtract(keys(i.storage_auto_scale), ["threshold", "upper_bound"])) == 0, false)]]))
    error_message = "storage_auto_scale: accepted keys are threshold, upper_bound."
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

variable "account_passwords" {
  type        = map(map(string))
  description = "Account passwords keyed by instance name, then account name. Supplied by the implementor; never commit them. An account without an entry gets a random password."
  default     = {}
  nullable    = false
  sensitive   = true

  validation {
    condition     = alltrue([for n in nonsensitive(keys(var.account_passwords)) : contains(keys(var.instances), n)])
    error_message = "account_passwords has a key that is not an instance name; the password would be ignored and a random one generated instead."
  }
}
