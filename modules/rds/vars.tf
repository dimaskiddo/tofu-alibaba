variable "name" {
  type        = string
  description = "Instance name, <component>-<instance>-c1-<tenant>-<env>."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,254}[a-z0-9]$", var.name))
    error_message = "name must be 2-256 chars: lowercase letters, digits and '-', starting with a letter and not ending with '-'."
  }
}

variable "engine" {
  type        = string
  description = "Database engine (ForceNew)."

  validation {
    condition     = contains(["MySQL", "PostgreSQL", "MariaDB"], var.engine)
    error_message = "engine must be MySQL, PostgreSQL or MariaDB."
  }
}

variable "engine_version" {
  type        = string
  description = "Engine version such as 8.0 or 15.0. Changing it in place is an engine upgrade."

  validation {
    condition     = can(regex("^[0-9]+(\\.[0-9]+)*$", var.engine_version))
    error_message = "engine_version must look like 8.0 or 15.0."
  }
}

variable "category" {
  type        = string
  description = "Basic (single node) or HighAvailability (primary and standby)."

  validation {
    condition     = contains(["Basic", "HighAvailability"], var.category)
    error_message = "category must be Basic or HighAvailability."
  }
}

variable "instance_type" {
  type        = string
  description = "Instance class such as mysql.n2.medium.1. Classes are region specific; list them with DescribeAvailableClasses."

  validation {
    condition     = length(var.instance_type) > 0
    error_message = "instance_type must not be empty."
  }
}

variable "instance_storage" {
  type        = number
  description = "Storage in GB, at least 5 and a multiple of 5."

  validation {
    condition     = var.instance_storage >= 5 && var.instance_storage % 5 == 0
    error_message = "instance_storage must be a multiple of 5, at least 5."
  }

  # cloud_ssd stays at 5 (minimum unverified); the maximum (64000, MariaDB 32000) is not checked.
  validation {
    condition     = var.instance_storage >= lookup({ cloud_essd = 20, cloud_essd2 = 500, cloud_essd3 = 1500, general_essd = 10 }, var.db_instance_storage_type, 5)
    error_message = "instance_storage is below the minimum of the storage type: cloud_essd 20, cloud_essd2 500, cloud_essd3 1500, general_essd 10 GB."
  }
}

variable "db_instance_storage_type" {
  type        = string
  description = "Storage type."
  default     = "cloud_essd"
  nullable    = false

  validation {
    condition     = contains(["cloud_ssd", "cloud_essd", "cloud_essd2", "cloud_essd3", "general_essd"], var.db_instance_storage_type)
    error_message = "db_instance_storage_type must be cloud_ssd, cloud_essd, cloud_essd2, cloud_essd3 or general_essd."
  }
}

variable "placement" {
  type = list(object({
    zone_id    = string
    vswitch_id = string
  }))
  description = "Zone and vSwitch of the primary, then of the standby for a multi-zone HighAvailability instance (ForceNew)."
  nullable    = false

  validation {
    condition     = length(var.placement) >= 1 && length(var.placement) <= 2
    error_message = "placement needs one entry, or two for a multi-zone instance."
  }

  validation {
    condition     = length(distinct([for p in var.placement : p.zone_id])) == length(var.placement)
    error_message = "placement zones must be distinct."
  }

  validation {
    condition     = var.category != "Basic" || length(var.placement) == 1
    error_message = "A Basic instance has no standby, so it takes exactly one placement."
  }
}

variable "security_ips" {
  type        = list(string)
  description = "IPv4 addresses or CIDRs allowed to connect. 0.0.0.0/0 is rejected."
  nullable    = false

  validation {
    condition     = length(var.security_ips) >= 1 && length(var.security_ips) <= 1000
    error_message = "security_ips needs 1-1000 entries."
  }

  validation {
    condition = alltrue([
      for ip in var.security_ips : can(regex("^((25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])(/(3[0-2]|[12]?[0-9]))?$", ip))
    ])
    error_message = "security_ips entries must be IPv4 addresses or IPv4 CIDRs."
  }

  validation {
    condition     = alltrue([for ip in var.security_ips : ip != "0.0.0.0" && !can(regex("/0$", ip))])
    error_message = "security_ips must not allow the whole internet (0.0.0.0/0)."
  }
}

variable "deletion_protection" {
  type        = bool
  description = "Block deletion of the instance. A ForceNew change then fails at the delete step instead of dropping the data."
  default     = true
  nullable    = false
}

variable "maintain_time" {
  type        = string
  description = "Maintenance window HH:MMZ-HH:MMZ (UTC). Null lets Alibaba Cloud choose."
  default     = null

  validation {
    condition     = var.maintain_time == null ? true : can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]Z-([01][0-9]|2[0-3]):[0-5][0-9]Z$", var.maintain_time))
    error_message = "maintain_time must be a UTC window HH:MMZ-HH:MMZ such as 02:00Z-03:00Z."
  }
}

variable "parameters" {
  type = list(object({
    name  = string
    value = string
  }))
  description = "Engine parameters. Names must be unique."
  default     = []
  nullable    = false

  validation {
    condition     = length(distinct([for p in var.parameters : p.name])) == length(var.parameters)
    error_message = "parameters names must be unique."
  }
}

variable "storage_auto_scale" {
  type = object({
    threshold   = number
    upper_bound = number
  })
  description = "Grow storage automatically when free space falls below threshold percent, up to upper_bound GB. Null disables it."
  default     = null

  validation {
    condition     = var.storage_auto_scale == null ? true : contains([10, 20, 30, 40, 50], var.storage_auto_scale.threshold)
    error_message = "storage_auto_scale.threshold must be 10, 20, 30, 40 or 50."
  }

  validation {
    condition     = var.storage_auto_scale == null ? true : var.storage_auto_scale.upper_bound > var.instance_storage
    error_message = "storage_auto_scale.upper_bound must be larger than instance_storage."
  }
}

variable "backup" {
  type = object({
    preferred_backup_period     = optional(list(string), ["Monday", "Wednesday", "Friday"])
    preferred_backup_time       = optional(string, "02:00Z-03:00Z")
    backup_retention_period     = optional(number, 7)
    log_backup_retention_period = optional(number, 7)
  })
  description = "Backup policy. Log backup is not available on Basic instances and is switched off there."
  default     = {}
  nullable    = false

  validation {
    condition     = length(var.backup.preferred_backup_period) >= 2 && length(distinct(var.backup.preferred_backup_period)) == length(var.backup.preferred_backup_period)
    error_message = "preferred_backup_period needs at least 2 distinct weekdays."
  }

  validation {
    condition     = alltrue([for d in var.backup.preferred_backup_period : contains(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], d)])
    error_message = "preferred_backup_period entries must be English weekday names (Monday...Sunday)."
  }

  validation {
    condition     = contains([for h in range(24) : format("%02d:00Z-%02d:00Z", h, h + 1)], var.backup.preferred_backup_time)
    error_message = "preferred_backup_time must be a one-hour window such as 02:00Z-03:00Z (the last is 23:00Z-24:00Z)."
  }

  validation {
    condition     = var.backup.backup_retention_period >= 7 && var.backup.backup_retention_period <= 730
    error_message = "backup_retention_period must be 7-730 days."
  }

  validation {
    condition     = var.backup.log_backup_retention_period >= 7 && var.backup.log_backup_retention_period <= var.backup.backup_retention_period
    error_message = "log_backup_retention_period must be 7 days or more and not exceed backup_retention_period; the provider would otherwise rewrite it and the plan would never converge."
  }
}

variable "databases" {
  type = list(object({
    name          = string
    character_set = optional(string)
    description   = optional(string)
  }))
  description = "Databases (ForceNew per entry). character_set is engine specific, for example utf8mb4 or UTF8,C,en_US.utf8."
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for d in var.databases : can(regex("^[a-z][a-z0-9_-]{0,62}[a-z0-9]$", d.name))])
    error_message = "Database names must be 2-64 chars of lowercase letters, digits, '_' and '-', starting with a letter and ending with a letter or digit."
  }

  validation {
    condition     = length(distinct([for d in var.databases : d.name])) == length(var.databases)
    error_message = "Database names must be unique."
  }
}

variable "accounts" {
  type = list(object({
    name        = string
    type        = optional(string, "Normal")
    description = optional(string)
    privilege   = optional(string)
    databases   = optional(list(string), [])
  }))
  description = "Accounts. Passwords come from account_passwords. privilege applies to every database listed in databases."
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for a in var.accounts : can(regex("^[a-z][a-z0-9_]{0,61}[a-z0-9]$", a.name))])
    error_message = "Account names must be 2-63 chars of lowercase letters, digits and '_', starting with a letter and ending with a letter or digit."
  }

  validation {
    condition     = length(distinct([for a in var.accounts : a.name])) == length(var.accounts)
    error_message = "Account names must be unique."
  }

  validation {
    condition     = alltrue([for a in var.accounts : contains(["Normal", "Super"], a.type)])
    error_message = "Account type must be Normal or Super."
  }

  validation {
    condition     = var.engine == "PostgreSQL" || length([for a in var.accounts : a if a.type == "Super"]) <= 1
    error_message = "MySQL and MariaDB allow at most one Super account per instance."
  }

  validation {
    condition     = var.engine == "PostgreSQL" || alltrue([for a in var.accounts : a.type != "Super" || (a.privilege == null && length(a.databases) == 0)])
    error_message = "A Super account on MySQL or MariaDB has all privileges already: leave privilege and databases unset."
  }

  validation {
    condition     = alltrue([for a in var.accounts : alltrue([for d in a.databases : contains([for db in var.databases : db.name], d)])])
    error_message = "Every database granted to an account must be listed in databases."
  }

  validation {
    condition     = alltrue([for a in var.accounts : length(a.databases) == 0 || a.privilege != null])
    error_message = "An account with databases needs a privilege."
  }

  validation {
    condition = alltrue([
      for a in var.accounts : a.privilege == null ? true : contains(
        var.engine == "PostgreSQL" ? ["DBOwner"] : ["ReadOnly", "ReadWrite", "DDLOnly", "DMLOnly"],
        a.privilege
      )
    ])
    error_message = "privilege must be ReadOnly, ReadWrite, DDLOnly or DMLOnly for MySQL and MariaDB, and DBOwner for PostgreSQL."
  }
}

variable "account_passwords" {
  type        = map(string)
  description = "Account passwords keyed by account name, supplied by the implementor (through the instances wrapper); never commit them. An account without an entry gets a random password (output generated_passwords)."
  default     = {}
  nullable    = false
  sensitive   = true

  validation {
    condition     = alltrue([for k in nonsensitive(keys(var.account_passwords)) : contains([for a in var.accounts : a.name], k)])
    error_message = "account_passwords has an entry for an account that is not in accounts."
  }

  validation {
    condition = nonsensitive(alltrue([
      for k, p in var.account_passwords :
      can(regex("^[A-Za-z0-9!@#$%^&*()_+=-]{8,32}$", p)) &&
      length([for r in ["[a-z]", "[A-Z]", "[0-9]", "[!@#$%^&*()_+=-]"] : r if can(regex(r, p))]) >= 3
    ]))
    error_message = "Each password must be 8-32 characters from letters, digits and !@#$%^&*()_+=-, using at least 3 of: lower case, upper case, digit, special character."
  }
}

variable "password_length" {
  type        = number
  description = "Length of generated account passwords (letters and digits)."
  default     = 8
  nullable    = false

  validation {
    condition     = var.password_length == floor(var.password_length) && var.password_length >= 8 && var.password_length <= 32
    error_message = "password_length must be a whole number from 8 to 32."
  }
}

variable "encryption_key" {
  type        = string
  description = "KMS key ID for cloud-disk encryption. Not supported for MariaDB. Disabling or deleting the key locks the instance."
  default     = null

  validation {
    condition     = var.encryption_key == null || var.engine != "MariaDB"
    error_message = "Disk encryption cannot be set for MariaDB from Terraform; leave encryption_key null."
  }
}

variable "role_arn" {
  type        = string
  description = "RAM role used by RDS to call KMS. Null derives the account's AliyunRDSInstanceEncryptionDefaultRole, which must already exist."
  default     = null
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
