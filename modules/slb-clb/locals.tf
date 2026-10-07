locals {
  server_groups = length(var.backend_servers) > 0 ? { this = var.name } : {}
}
