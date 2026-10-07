locals {
  entries = { for e in var.entries : e.name => e }
}
