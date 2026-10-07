variable "instances" {
  type        = any
  description = "Instances keyed by the instance `name` value. Each value takes the inputs of ../; its optional tags merge over the shared tags."

  validation {
    condition     = length(var.instances) >= 1
    error_message = "At least one instance is required."
  }

  validation {
    condition     = alltrue([for n, i in var.instances : can(keys(i)) ? length(setsubtract(keys(i), ["forward_table_id", "entries", "tags"])) == 0 : false])
    error_message = "An instance has an unknown key; allowed keys are the inputs of ../ except the name, i.e. forward_table_id, entries, tags."
  }

  # Entries of different instances may share one forward table, so the module's per-instance overlap check is repeated across them.
  validation {
    condition = (
      !alltrue([for n, i in var.instances : can(i.forward_table_id) && can(i.entries)]) ? true :
      alltrue(flatten([
        for na, a in var.instances : [
          for nb, b in var.instances : [
            for ea in a.entries : [
              for eb in b.entries :
              na == nb || a.forward_table_id != b.forward_table_id || ea.external_ip != eb.external_ip ? true : (
                try(ea.ip_protocol, "tcp") == "any" || try(eb.ip_protocol, "tcp") == "any" ? false : (
                  try(ea.ip_protocol, "tcp") != try(eb.ip_protocol, "tcp") ? true :
                  try(tonumber(split("/", ea.external_port)[length(split("/", ea.external_port)) - 1]) < tonumber(split("/", eb.external_port)[0]) || tonumber(split("/", eb.external_port)[length(split("/", eb.external_port)) - 1]) < tonumber(split("/", ea.external_port)[0]), true)
                )
              )
            ]
          ]
        ]
      ]))
    )
    error_message = "Entries of different instances on one forward_table_id must not overlap on the same external_ip (an any-protocol mapping owns the whole address)."
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
