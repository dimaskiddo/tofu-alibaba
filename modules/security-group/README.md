# security-group

Creates one security group and its rules. `alicloud_security_group_rule` has no tags argument; tags apply to the group only.

Provider: `aliyun/alicloud ~> 1.293`. OpenTofu `>= 1.10.0, < 1.11.0`. The module holds no backend, provider configuration or credentials; the Terragrunt implementor supplies them.

## Inputs

| Name | Type | Required | Description |
|---|---|---|---|
| `name` | `string` | yes | Security group name, `<component>-<instance>-c1-<tenant>-<env>`. Must match `^[a-z][a-z0-9-]{0,126}[a-z0-9]$`: 2-128 chars, lowercase letters, digits and `-`, starting with a letter and not ending with `-`. |
| `vpc_id` | `string` | yes | VPC the security group belongs to; must start with `vpc-`. |
| `description` | `string` | no | Default `null`. Security group description. |
| `inner_access_policy` | `string` | no | Default `Accept`. Intra-group traffic policy: `Accept` or `Drop`. |
| `rules` | `list(object)` | no | Default `[]`. Rules keyed by unique `name`; see the object below. |
| `tags` | `map(string)` | yes | Resource tags. At least one tag is required; keys and values must not be empty. Applied to the group only. |

`rules` element:

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | `string` | yes | Rule key; unique within the list; same regex as the group `name`. |
| `type` | `string` | yes | `ingress` or `egress`. |
| `ip_protocol` | `string` | yes | `tcp`, `udp`, `icmp`, `gre` or `all`. `icmpv6` is rejected: the rule has no IPv6 source (`ipv6_cidr_ip`). |
| `port_range` | `string` | no | Default `-1/-1`. `tcp`/`udp` need `first/last` within 1-65535 with first <= last; every other protocol must be `-1/-1`. |
| `cidr_ip` | `string` | no | Default `null`. IPv4 CIDR with no host bits set (IPv6 is rejected). |
| `source_security_group_id` | `string` | no | Default `null`. Must start with `sg-`. |
| `policy` | `string` | no | Default `accept` (optional by design). `accept` or `drop` (lowercase); anything else is rejected. |
| `priority` | `number` | no | Default `1`. Whole number 1-100. |
| `description` | `string` | no | Default `null`. |

Each rule needs exactly one of `cidr_ip` or `source_security_group_id`. `nic_type` is fixed to `intranet` (VPC security groups accept only intranet rules).

## Outputs

| Name | Description |
|---|---|
| `security_group_id` | Security group ID. |
| `security_group_name` | Security group name, read back from the resource. |
| `tags` | Tags applied to the security group. |
| `rule_ids` | Security group rule IDs keyed by rule name. |

## Instances wrapper

`instances/` calls this module once per map entry (`for_each`), so one state holds many security groups. Use it from a leaf as `source = ".../modules//security-group/instances"`.

| Input | Meaning |
|---|---|
| `instances` | Map (`any`), at least one entry. The map key becomes `name`. Each value takes `vpc_id`, `description`, `inner_access_policy`, `rules`, `tags`. Unset fields are passed as `null`, so the module defaults above apply; `vpc_id` has no default and is read directly, so it must be set. Keys outside that list fail validation (a typo is an error, not a silent null). |
| `tags` | Shared tags, at least one; keys and values must not be empty. Merged under each entry's own `tags` (the entry wins on a clash). |

Output `instances` returns every output of this module, keyed by entry name.

## Tests

```bash
tofu init -backend=false -input=false && tofu test
(cd instances && tofu init -backend=false -input=false && tofu test)
```
