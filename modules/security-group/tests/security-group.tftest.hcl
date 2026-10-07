mock_provider "alicloud" {}

variables {
  name   = "bastion-1-c1-example-stage"
  vpc_id = "vpc-abc"
  tags   = { env = "stage" }
  rules = [
    { name = "ssh-in", type = "ingress", ip_protocol = "tcp", port_range = "22/22", cidr_ip = "10.0.0.0/16" },
    { name = "all-out", type = "egress", ip_protocol = "all", cidr_ip = "0.0.0.0/0" },
  ]
}

run "valid" {
  command = plan

  assert {
    condition     = length(alicloud_security_group_rule.this) == 2 && alicloud_security_group.this.tags["env"] == "stage"
    error_message = "rules and tags must be created"
  }

  assert {
    condition     = alicloud_security_group_rule.this["ssh-in"].nic_type == "intranet" && alicloud_security_group_rule.this["all-out"].port_range == "-1/-1"
    error_message = "VPC rules must be intranet; non-port protocols use -1/-1"
  }
}

run "no_rules_valid" {
  command = plan
  variables { rules = [] }

  assert {
    condition     = length(alicloud_security_group_rule.this) == 0
    error_message = "a group without rules is allowed"
  }
}

run "port_zero_rejected" {
  command = plan
  variables { rules = [{ name = "bad", type = "ingress", ip_protocol = "tcp", port_range = "0/22", cidr_ip = "10.0.0.0/16" }] }
  expect_failures = [var.rules]
}

run "port_65536_rejected" {
  command = plan
  variables { rules = [{ name = "bad", type = "ingress", ip_protocol = "tcp", port_range = "1/65536", cidr_ip = "10.0.0.0/16" }] }
  expect_failures = [var.rules]
}

run "reversed_range_rejected" {
  command = plan
  variables { rules = [{ name = "bad", type = "ingress", ip_protocol = "udp", port_range = "100/50", cidr_ip = "10.0.0.0/16" }] }
  expect_failures = [var.rules]
}

run "tcp_without_ports_rejected" {
  command = plan
  variables { rules = [{ name = "bad", type = "ingress", ip_protocol = "tcp", cidr_ip = "10.0.0.0/16" }] }
  expect_failures = [var.rules]
}

run "icmp_with_ports_rejected" {
  command = plan
  variables { rules = [{ name = "bad", type = "ingress", ip_protocol = "icmp", port_range = "1/10", cidr_ip = "10.0.0.0/16" }] }
  expect_failures = [var.rules]
}

run "invalid_cidr_rejected" {
  command = plan
  variables { rules = [{ name = "bad", type = "ingress", ip_protocol = "all", cidr_ip = "10.0.0.0/40" }] }
  expect_failures = [var.rules]
}

run "missing_source_rejected" {
  command = plan
  variables { rules = [{ name = "bad", type = "ingress", ip_protocol = "all" }] }
  expect_failures = [var.rules]
}

run "both_sources_rejected" {
  command = plan
  variables { rules = [{ name = "bad", type = "ingress", ip_protocol = "all", cidr_ip = "10.0.0.0/16", source_security_group_id = "sg-abc" }] }
  expect_failures = [var.rules]
}

run "bad_direction_rejected" {
  command = plan
  variables { rules = [{ name = "bad", type = "inbound", ip_protocol = "all", cidr_ip = "10.0.0.0/16" }] }
  expect_failures = [var.rules]
}

run "duplicate_rule_rejected" {
  command = plan
  variables {
    rules = [
      { name = "dup", type = "ingress", ip_protocol = "all", cidr_ip = "10.0.0.0/16" },
      { name = "dup", type = "egress", ip_protocol = "all", cidr_ip = "10.0.0.0/16" },
    ]
  }
  expect_failures = [var.rules]
}

run "priority_101_rejected" {
  command = plan
  variables { rules = [{ name = "bad", type = "ingress", ip_protocol = "all", cidr_ip = "10.0.0.0/16", priority = 101 }] }
  expect_failures = [var.rules]
}

run "empty_tags_rejected" {
  command = plan
  variables { tags = {} }
  expect_failures = [var.tags]
}

run "icmpv6_rejected" {
  command = plan
  variables { rules = [{ name = "bad", type = "ingress", ip_protocol = "icmpv6", cidr_ip = "10.0.0.0/16" }] }
  expect_failures = [var.rules]
}

run "bad_policy_rejected" {
  command = plan
  variables { rules = [{ name = "bad", type = "ingress", ip_protocol = "all", cidr_ip = "10.0.0.0/16", policy = "deny" }] }
  expect_failures = [var.rules]
}

run "default_policy_is_accept" {
  command = plan

  assert {
    condition     = alicloud_security_group_rule.this["ssh-in"].policy == "accept"
    error_message = "policy defaults to accept"
  }
}

run "ipv6_cidr_rejected" {
  command = plan
  variables { rules = [{ name = "bad", type = "ingress", ip_protocol = "all", cidr_ip = "::/0" }] }
  expect_failures = [var.rules]
}

run "host_bits_cidr_rejected" {
  command = plan
  variables { rules = [{ name = "bad", type = "ingress", ip_protocol = "all", cidr_ip = "10.0.0.5/16" }] }
  expect_failures = [var.rules]
}

run "bad_inner_access_policy_rejected" {
  command = plan
  variables { inner_access_policy = "Deny" }
  expect_failures = [var.inner_access_policy]
}
