# route-table

Two modes, selected by `route_table_id`:

- **Create** (`route_table_id = null`): creates a custom route table in `vpc_id`, binds `vswitch_ids` to it and adds `routes`. Binding a vSwitch changes how its traffic is routed, so list only the vSwitches that should use the table.
- **Existing** (`route_table_id` set, e.g. the `vpc` module's `route_table_id` output for the system table): adds `routes` only. `vpc_id`, `route_table_name` and `vswitch_ids` must be unset.

Each route is an `alicloud_route_entry`; the key is the route name. A destination must be unique per table and must not equal or sit inside a vSwitch CIDR of the VPC (the API rejects it; the module cannot see vSwitch CIDRs). `nexthop_id` comes from the next-hop resource, e.g. `vpc-peering`'s `peer_connection_id` for `VpcPeer`.

Provider: `aliyun/alicloud ~> 1.293` (the only `required_providers` entry). OpenTofu `>= 1.10.0, < 1.11.0`. The module holds no backend, provider configuration or credentials; the Terragrunt implementor supplies them.

## Inputs

| Name | Type | Required | Description |
|---|---|---|---|
| `route_table_id` | `string` | no | Existing route table to add routes to. Default `null` creates a custom route table. Must start with `vtb-`. |
| `vpc_id` | `string` | create mode | VPC of the custom route table. Default `null`. Create mode: required, must start with `vpc-`. Existing mode: must be unset. |
| `route_table_name` | `string` | create mode | Custom route table name, `<component>-<instance>-c1-<tenant>-<env>`. Default `null`. Create mode: required, 2-128 chars: lowercase letters, digits and `-`, starting with a letter and not ending with `-`. Existing mode: must be unset. |
| `description` | `string` | no | Optional custom route table description. Default `null`; must be unset in existing mode. |
| `vswitch_ids` | `map(string)` | no | vSwitches bound to the custom route table, keyed by name. Default `{}`. Values must start with `vsw-`. Create mode only; must be empty in existing mode. |
| `routes` | `map(object({ destination_cidrblock = string, nexthop_type = string, nexthop_id = string, description = optional(string) }))` | no | Routes keyed by route name (used as the route entry name; 2-128 chars: lowercase letters, digits and `-`, starting with a letter and not ending with `-`). Default `{}`. `destination_cidrblock`: IPv4 CIDR with no host bits set, unique within the map. `nexthop_type`: one of `Instance`, `HaVip`, `RouterInterface`, `NetworkInterface`, `VpnGateway`, `IPv6Gateway`, `NatGateway`, `Attachment`, `VpcPeer`, `Ipv4Gateway`, `GatewayEndpoint`, `Ecr`. `nexthop_id`: non-empty. At least one route is required for an existing table. |
| `tags` | `map(string)` | yes | Resource tags. At least one tag is required; keys and values must not be empty. Applied to the custom route table only (nothing is tagged in existing mode). |

## Outputs

| Name | Description |
|---|---|
| `route_table_id` | Route table ID, created or supplied. |
| `route_entry_ids` | Route entry IDs keyed by route name. |
| `tags` | Tags of the custom route table; null in existing mode, where nothing is tagged. |

## Instances wrapper

`instances/` calls this module once per map entry (`for_each`), so one state holds many instances. Use it from a leaf as `source = ".../modules//route-table/instances"`.

| Input | Meaning |
|---|---|
| `instances` | Map (`any`), at least one entry. The map key only identifies the instance in the output; it is not passed as `route_table_name`. Each value takes `route_table_id` or `vpc_id` + `route_table_name`, plus `description`, `vswitch_ids`, `routes`, `tags`. A missing field is passed as null, so the module default applies; the wrapper adds no defaults of its own. Keys outside that list fail validation (a typo is an error, not a silent null). |
| `tags` | `map(string)`. Shared tags, at least one, keys and values not empty; merged under each entry's own `tags` (the entry wins on a clash). |

Output `instances` returns every output of this module keyed by entry name.

## Tests

```bash
tofu init -backend=false -input=false && tofu test
(cd instances && tofu init -backend=false -input=false && tofu test)
```
