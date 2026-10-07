locals {
  users  = { for u in var.sasl_users : u.name => u }
  topics = { for t in var.topics : t.name => t }
  groups = { for g in var.consumer_groups : g.name => g }

  acls = merge([
    for u in var.sasl_users : {
      for a in u.acls : "${u.name}/${a.resource_type}/${a.resource_name}/${a.pattern}/${a.operation}" => merge(a, { user = u.name })
    }
  ]...)

  # 9092 is the plaintext VPC endpoint, 9094 the VPC SASL one.
  ports = length(var.sasl_users) > 0 ? ["9092/9092", "9094/9094"] : ["9092/9092"]
  allowed = {
    for pair in setproduct(local.ports, var.allowed_ips) : "${pair[0]}/${pair[1]}" => { port_range = pair[0], ip = pair[1] }
  }
}
