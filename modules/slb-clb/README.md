# slb-clb

Creates a Classic Load Balancer, an optional vServer group with backend attachments, and listeners. Listeners without `backend_servers` need `backend_port`.

Provider: `aliyun/alicloud ~> 1.293`. OpenTofu `>= 1.10.0, < 1.11.0`. The module holds no backend, provider configuration or credentials; the Terragrunt implementor supplies them.

## Inputs

| Name | Type | Required | Default | Description |
|---|---|---|---|---|
| `name` | `string` | yes | | CLB name, `<component>-<instance>-c1-<tenant>-<env>`. Validated: 2-80 chars, lowercase letters, digits and `-`, starting with a letter, not ending with `-`. Also the vServer group name. |
| `zones` | `list(string)` | yes | | Registered availability zones, at least one; `master_zone_id` and `slave_zone_id` must be among them (checked in a resource precondition). |
| `address_type` | `string` | no | `"intranet"` | `intranet` = private CLB (needs `vswitch_id`), `internet` = public CLB. Not nullable: null falls back to the default. |
| `vswitch_id` | `string` | no | `null` | vSwitch for the CLB; must start with `vsw-` (checked for `intranet` only). Required for `intranet`; ignored (sent as null) for `internet`. |
| `master_zone_id` | `string` | no | `null` | Primary zone. Null lets Alibaba Cloud choose; when set it must be a registered zone. ForceNew in the provider. |
| `slave_zone_id` | `string` | no | `null` | Standby zone. Must differ from `master_zone_id` and be a registered zone. ForceNew in the provider. Whether it needs a `master_zone_id` is not documented, so it is not validated. |
| `load_balancer_spec` | `string` | no | `null` | Performance-guaranteed spec: `slb.s1.small`, `slb.s2.small`, `slb.s2.medium`, `slb.s3.small`, `slb.s3.medium`, `slb.s3.large` or `slb.s4.large`. Null keeps the shared-performance instance. Pay-by-spec has not been sold since 2025-06-01, and the provider ignores the spec on a pay-by-LCU CLB. |
| `internet_charge_type` | `string` | no | `"PayByTraffic"` | Only `PayByTraffic`: international accounts cannot create `PayByBandwidth` CLBs and pay-by-LCU accepts only paybytraffic. Not nullable. |
| `bandwidth` | `number` | no | `null` | Kept for contract parity; must be null. `PayByTraffic` CLBs have no bandwidth and the provider ignores it. |
| `backend_servers` | `map(object)` | no | `{}` | Backend servers keyed by name (2-128 chars, lowercase letters, digits and `-`, starting with a letter, not ending with `-`); all attached to one vServer group. Not nullable. Fields: `server_id` (`string`, required, non-empty), `port` (`number`, required, 1-65535), `weight` (`number`, default `100`, 0-100), `type` (`string`, default `"ecs"`; `ecs`, `eni` or `eci`). |
| `listeners` | `map(object)` | yes | | Listeners keyed by name (same key rule as `backend_servers`), at least one. Fields: `protocol` (`string`, required; `http`, `https`, `tcp` or `udp`), `frontend_port` (`number`, required, 1-65535), `backend_port` (`number`, default `null`, 1-65535; required when no `backend_servers`, dropped when they exist), `scheduler` (`string`, default `"wrr"`; `wrr` or `rr` for http/https, plus `sch` and `tch` for tcp, plus `sch`, `tch` and `qch` for udp; `sch`, `tch` and `qch` need a high-performance instance, not validated), `bandwidth` (`number`, default `null`; `-1` or 1-1000; listener bandwidth is documented for domestic-site accounts only, use `-1` (unlimited); the listener bandwidths may not sum above the CLB bandwidth), `server_certificate_id` (`string`, default `null`; required and non-empty for `https`). Frontend ports are unique per transport: http/https/tcp share one namespace, udp is separate. |
| `tags` | `map(string)` | yes | | Resource tags. At least one tag is required; keys and values must not be empty. The CLB and the vServer group are tagged; listeners and attachments are not taggable in the provider. |

Hardcoded: `payment_type = "PayAsYouGo"`. The vServer group is created only when `backend_servers` is non-empty, with the CLB `name` as its name. Listeners attach to it, otherwise they use `backend_port`.

## Outputs

| Name | Description |
|---|---|
| `tags` | Tags applied to the load balancer. |
| `load_balancer_id` | CLB ID. |
| `address` | CLB IP address. |
| `server_group_id` | vServer group ID (null when no `backend_servers`). |
| `frontend_ports` | `map(number)`: frontend port keyed by listener name. |

## Instances wrapper

`instances/` calls this module once per map entry (`for_each`), so one state holds many instances. Use it from a leaf as `source = ".../modules//slb-clb/instances"`.

| Input | Type | Meaning |
|---|---|---|
| `instances` | `any` | At least one entry. The map key becomes `name`. Each value takes `address_type`, `vswitch_id`, `master_zone_id`, `slave_zone_id`, `load_balancer_spec`, `internet_charge_type`, `bandwidth`, `backend_servers`, `listeners`, `tags`. `listeners` is required and read directly. An omitted `address_type`, `internet_charge_type` or `backend_servers` takes the module default. Entries with any other key fail validation (typo protection). Nested objects are checked too: an unknown key inside `listeners` or `backend_servers` fails validation. |
| `zones` | `list(string)` | Required, at least one; shared by every entry and passed as the module `zones`. |
| `tags` | `map(string)` | Shared tags, at least one, keys and values non-empty; `merge`d under each entry's own `tags` (the entry wins on a clash). |

Output `instances` returns every output of this module (`load_balancer_id`, `address`, `server_group_id`, `frontend_ports`, `tags`) keyed by entry name.

## Tests

```bash
tofu init -backend=false -input=false && tofu test
(cd instances && tofu init -backend=false -input=false && tofu test)
```
