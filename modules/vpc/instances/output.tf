output "instances" {
  description = "Per-VPC outputs (vpc_id, vpc_name, cidr_block, route_table_id, tags) keyed by VPC name."
  value = { for k, m in module.this : k => {
    vpc_id         = m.vpc_id
    vpc_name       = m.vpc_name
    cidr_block     = m.cidr_block
    route_table_id = m.route_table_id
    tags           = m.tags
  } }
}
