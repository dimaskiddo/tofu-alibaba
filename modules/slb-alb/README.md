# slb-alb

Creates an Application Load Balancer, server groups, listeners and rules. Alibaba Cloud requires at least two zones for an ALB; single-zone input fails validation. `alicloud_alb_rule` has no tags argument; tags apply to the LB, server groups and listeners. `load_balancer_edition` has no default and must be set explicitly.

Provider: `aliyun/alicloud ~> 1.293`. OpenTofu `>= 1.10.0, < 1.11.0`. The module holds no backend, provider configuration or credentials; the Terragrunt implementor supplies them.

## Inputs

| Name | Type | Required | Default | Description |
|---|---|---|---|---|
| `name` | `string` | yes | | ALB name, `<component>-<instance>-c1-<tenant>-<env>`. Validated: 2-128 chars, lowercase letters, digits and `-`, starting with a letter, not ending with `-`. |
| `zones` | `list(string)` | yes | | Registered availability zones, at least one; every `zone_mappings` `zone_id` must be among them (checked in a resource precondition). |
| `vpc_id` | `string` | yes | | VPC the ALB and its server groups belong to; must start with `vpc-`. |
| `address_type` | `string` | no | `"Intranet"` | `Intranet` = private ALB, `Internet` = public ALB (Alibaba Cloud allocates the EIPs). Not nullable: null falls back to the default. |
| `load_balancer_edition` | `string` | yes | | ALB edition: `Basic`, `Standard` or `StandardWithWaf`. No default so the billing tier is an explicit choice. |
| `zone_mappings` | `list(object)` | yes | | Each `{ zone_id = string, vswitch_id = string }`, both required. At least two entries in different zones (Alibaba Cloud requires two); each `zone_id` non-empty and unique, each `vswitch_id` starts with `vsw-`. |
| `server_groups` | `map(object)` | yes | | At least one (the declared default `{}` fails validation). Server groups keyed by name (2-128 chars, lowercase letters, digits and `-`, starting with a letter, not ending with `-`). Not nullable. Fields, all optional: `protocol` (default `"HTTP"`; `HTTP`, `HTTPS` or `GRPC`), `scheduler` (default `"Wrr"`; `Wrr`, `Wlc` or `Sch`), `sticky` (`bool`, default `false`; true enables Insert-cookie stickiness), `health_check` (object, default `{}`) and `servers` (list, default `[]`). `health_check` fields: `enabled` (`bool`, default `true`), `protocol` (default `"HTTP"`; `HTTP`, `HTTPS`, `TCP` or `GRPC`; the provider validator accepts the upper-case form although its docs write `gRPC`), `path` (default `"/"`), `codes` (`list(string)`, default `["http_2xx"]`), `port` (`number`, default `0` = backend server port; 0-65535). `path` and `codes` apply only when the protocol is `HTTP` or `HTTPS`, otherwise they are not sent. Each `servers` item: `server_id` (required, non-empty), `port` (required, 1-65535), `server_type` (default `"Ecs"`; `Ecs`, `Eni` or `Eci`), `weight` (default `100`, 0-100). |
| `listeners` | `map(object)` | yes | | Listeners keyed by name (same key rule as `server_groups`), at least one. Fields: `protocol` (required; `HTTP` or `HTTPS`), `port` (required, 1-65535, unique across listeners), `default_server_group` (required; must be a key of `server_groups`, checked in a precondition), `certificate_id` (default `null`; required and non-empty for `HTTPS`, rejected on `HTTP`), `description` (default `null`). |
| `rules` | `map(object)` | no | `{}` | Forwarding rules keyed by name (same key rule). Not nullable. Fields: `listener` (required; key of `listeners`), `priority` (required; whole number 1-10000, unique per listener), `hosts` (`list(string)`, default `[]`), `paths` (`list(string)`, default `[]`, each starting with `/`), `server_group` (default `null`; key of `server_groups`), `fixed_response` (default `null`; `content` required, `content_type` default `"text/plain"`, `http_code` default `"503"`, must match 2xx, 4xx or 5xx). At least one host or path; exactly one of `server_group` or `fixed_response`. |
| `tags` | `map(string)` | yes | | Resource tags. At least one tag is required; keys and values must not be empty. The ALB, server groups and listeners are tagged; rules are not taggable in the provider. |

Hardcoded: billing `pay_type = "PayAsYouGo"`; server groups are `server_group_type = "Instance"`; server group name is the map key; listener default action is `ForwardGroup` to `default_server_group`; rules use `direction = "Request"` with a single action of `order = 1`. A rule with hosts and paths gets both conditions (Host and Path).

## Outputs

| Name | Description |
|---|---|
| `tags` | Tags applied to the load balancer. |
| `load_balancer_id` | ALB ID. |
| `dns_name` | ALB DNS name. |
| `zone_ids` | `list(string)` of zones the ALB is deployed in, in `zone_mappings` order. |
| `server_group_ids` | Server group IDs keyed by name. |
| `listener_ids` | Listener IDs keyed by name. |
| `rule_ids` | Rule IDs keyed by name. |

## Notes

- `bandwidth_package_id` on the load balancer is ignored: `modules/cbwp` attaches a shared bandwidth package with its own resource, and the inline argument is ForceNew.

## Instances wrapper

`instances/` calls this module once per map entry (`for_each`), so one state holds many instances. Use it from a leaf as `source = ".../modules//slb-alb/instances"`.

| Input | Type | Meaning |
|---|---|---|
| `instances` | `any` | At least one entry. The map key becomes `name`. Each value takes `vpc_id`, `address_type`, `load_balancer_edition`, `zone_mappings`, `server_groups`, `listeners`, `rules`, `tags`. `vpc_id`, `load_balancer_edition`, `zone_mappings`, `server_groups` and `listeners` are required and read directly. `server_groups` is required too (at least one). `address_type` and `rules` take the module default when omitted (`null` counts as omitted). Entries with any other key fail validation (typo protection). Nested objects are checked too: an unknown key inside `zone_mappings`, `server_groups` (and its `health_check` and `servers`), `listeners` or `rules` (and its `fixed_response`) fails validation. |
| `zones` | `list(string)` | Required, at least one; shared by every entry and passed as the module `zones`. |
| `tags` | `map(string)` | Shared tags, at least one, keys and values non-empty; `merge`d under each entry's own `tags` (the entry wins on a clash). |

Output `instances` returns every output of this module (`load_balancer_id`, `dns_name`, `zone_ids`, `server_group_ids`, `listener_ids`, `rule_ids`, `tags`) keyed by entry name.

## Tests

```bash
tofu init -backend=false -input=false && tofu test
(cd instances && tofu init -backend=false -input=false && tofu test)
```
