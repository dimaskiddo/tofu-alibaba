# nat

Creates one Enhanced NAT gateway (`nat_type = "Enhanced"` and `payment_type = "PayAsYouGo"` are hardcoded, not inputs), `internet` or `intranet`. Internet NAT associates the supplied EIPs (`alicloud_eip_association`, `instance_type = "Nat"`). Intranet NAT requires `nat_ip_cidr` (inside 10.0.0.0/8, 172.16.0.0/12 or 192.168.0.0/16, mask /16-/32, not overlapping `vpc_cidr_block`), creates it as `alicloud_vpc_nat_ip_cidr`, creates the named NAT IPs (transit IPs) from it, and adds a route in `route_table_id` sending the CIDR to the gateway. Peer-side routes (peer CIDR to the gateway, NAT vSwitch to the transit router) are not created. Tags propagate to `alicloud_nat_gateway` only; the other resources are not taggable.

Provider: `aliyun/alicloud ~> 1.293` (the only `required_providers` entry). OpenTofu `>= 1.10.0, < 1.11.0`. The module holds no backend, provider configuration or credentials; the Terragrunt implementor supplies them.

## Inputs

| Name | Type | Required | Description |
|---|---|---|---|
| `nat_name` | `string` | yes | NAT gateway name, `<component>-<instance>-c1-<tenant>-<env>`. 2-128 chars: lowercase letters, digits and `-`, starting with a letter and not ending with `-`. |
| `network_type` | `string` | no | `internet` (default) = public NAT gateway, `intranet` = private (VPC) NAT gateway. Null is treated as the default. |
| `vpc_id` | `string` | yes | VPC the NAT gateway belongs to. Must start with `vpc-`. |
| `vpc_cidr_block` | `string` | intranet | VPC CIDR (an IPv4 CIDR with no host bits set (IPv6 and `10.0.0.1/16` are rejected)); used to reject a `nat_ip_cidr` that overlaps it. Default `null`. Required for intranet. |
| `vswitch_id` | `string` | yes | vSwitch hosting the enhanced NAT gateway. Must start with `vsw-`. |
| `description` | `string` | no | Optional NAT gateway description. Default `null`. |
| `eip_allocation_ids` | `map(string)` | internet | EIP allocation IDs keyed by EIP name, associated to the gateway. Default `{}`. Internet: at least one. Intranet: must be empty. Every value must start with `eip-`. |
| `nat_ip_cidr` | `string` | intranet | Private NAT IP CIDR. Default `null`. Intranet: required. Internet: must be unset. Must be an IPv4 CIDR with no host bits set, inside 10.0.0.0/8, 172.16.0.0/12 or 192.168.0.0/16 with mask length 16-32, and must not overlap `vpc_cidr_block` when both are set. |
| `nat_ips` | `map(object({ ip = optional(string) }))` | intranet | Private NAT IPs (transit IPs) keyed by name, taken from `nat_ip_cidr`. Default `{}`. Intranet: at least one. Internet: must be empty. Keys follow the `nat_name` character rule (2-128 chars, lowercase letters, digits, `-`, starts with a letter, no trailing `-`). `ip` pins the address (ForceNew), must be a valid IPv4 address inside `nat_ip_cidr` and distinct from the other pinned IPs; null lets Alibaba Cloud pick. Reserved addresses inside a custom `nat_ip_cidr` are undocumented and not validated; avoid the first address and the last three, as for vSwitches. |
| `route_table_id` | `string` | intranet | System route table of the NAT gateway VPC; gets `nat_ip_cidr` routed to the gateway. Default `null`. Intranet: required. Internet: must be unset. Must start with `vtb-`. |
| `tags` | `map(string)` | yes | Resource tags. At least one tag is required; keys and values must not be empty. |

## Outputs

| Name | Description |
|---|---|
| `nat_gateway_id` | NAT gateway ID. |
| `network_type` | internet or intranet. |
| `snat_table_ids` | SNAT table ID auto-created with the gateway. |
| `forward_table_ids` | DNAT (forward) table ID auto-created with the gateway. |
| `nat_ips` | Private NAT IP addresses keyed by name (empty for internet). |
| `tags` | Tags applied to the NAT gateway. |

## Instances wrapper

`instances/` calls this module once per map entry (`for_each`), so one state holds many instances. Use it from a leaf as `source = ".../modules//nat/instances"`.

| Input | Meaning |
|---|---|
| `instances` | Map (`any`), at least one entry. The map key becomes `nat_name`. Each value takes `network_type`, `vpc_id`, `vpc_cidr_block`, `vswitch_id`, `description`, `eip_allocation_ids`, `nat_ip_cidr`, `nat_ips`, `route_table_id`, `tags`. A missing field is passed as null, so the module default applies (`network_type` = `internet`, `eip_allocation_ids` and `nat_ips` = `{}`); the wrapper adds no defaults of its own. `vpc_id` and `vswitch_id` are required and read directly. Keys outside that list fail validation (a typo is an error, not a silent null). |
| `tags` | `map(string)`. Shared tags, at least one, keys and values not empty; merged under each entry's own `tags` (the entry wins on a clash). |

Output `instances` returns every output of this module keyed by entry name.

## Tests

```bash
tofu init -backend=false -input=false && tofu test
(cd instances && tofu init -backend=false -input=false && tofu test)
```
