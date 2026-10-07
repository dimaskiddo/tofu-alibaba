# subnet

Creates vSwitches (one resource per entry, keyed by name). Every registered zone must host at least one subnet; subnets must sit inside the VPC CIDR and must not overlap.

Provider: `aliyun/alicloud ~> 1.293` (the only `required_providers` entry). OpenTofu `>= 1.10.0, < 1.11.0`. The module holds no backend, provider configuration or credentials; the Terragrunt implementor supplies them.

## Inputs

| Name | Type | Required | Description |
|---|---|---|---|
| `vpc_id` | `string` | yes | Parent VPC ID. Must start with `vpc-`. |
| `vpc_cidr_block` | `string` | yes | Parent VPC CIDR (an IPv4 CIDR with no host bits set (IPv6 and `10.0.0.1/16` are rejected)); every subnet must fall inside it. |
| `zones` | `list(string)` | yes | Registered availability zones, at least one. Every subnet `zone_id` must be one of them, and every zone must host at least one subnet. |
| `subnets` | `list(object({ name = string, cidr_block = string, zone_id = string, tags = optional(map(string), {}) }))` | yes | vSwitches to create, at least one. `name`: unique, 2-128 chars: lowercase letters, digits and `-`, starting with a letter and not ending with `-`. `cidr_block`: an IPv4 CIDR with no host bits set (IPv6 and `10.0.0.1/16` are rejected), mask /16 to /29 (CreateVSwitch), inside `vpc_cidr_block`, not overlapping another subnet. `zone_id`: non-empty (a missing zone is rejected), in `zones`. `tags`: default `{}`, keys and values not empty, merged over the shared tags for that vSwitch only. |
| `tags` | `map(string)` | yes | Resource tags. At least one tag is required; keys and values must not be empty. |

## Outputs

| Name | Description |
|---|---|
| `subnet_ids` | vSwitch IDs keyed by subnet name. |
| `subnet_cidr_blocks` | vSwitch CIDR blocks keyed by subnet name. |
| `subnet_zones` | vSwitch zone IDs keyed by subnet name. |
| `subnet_id_list` | vSwitch IDs ordered by subnet name. |
| `subnet_ids_by_zone` | vSwitch IDs grouped by zone. |

## Instances wrapper

`instances/` calls this module once per VPC, so one state holds the subnets of several VPCs. Use it as `source = ".../modules//subnet/instances"`.

| Input | Meaning |
|---|---|
| `groups` | `any`. Keyed by VPC name (the group folder); each value takes `vpc_id`, `vpc_cidr_block` and `subnets` (`name`, `cidr_block`, `zone_id`, optional `tags`). At least one group; subnet names must be unique across groups. An unknown key at either level fails validation. Each group is validated by this module. |
| `zones` | `list(string)`. At least one. Shared by every group, so each VPC group needs a subnet in every registered zone. |
| `tags` | `map(string)`. Applied to every vSwitch; at least one, keys and values not empty. The wrapper has no per-group tags; per-subnet `tags` still merge over it. |

Outputs: `subnet_ids`, `subnet_cidr_blocks` and `subnet_zones` (merged across groups, keyed by subnet name) and `groups` (all outputs of this module per VPC group, keyed by VPC name). `subnet_id_list` and `subnet_ids_by_zone` are available only under `groups`.

## Tests

```bash
tofu init -backend=false -input=false && tofu test
(cd instances && tofu init -backend=false -input=false && tofu test)
```
