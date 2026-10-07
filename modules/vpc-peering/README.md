# vpc-peering

Creates a VPC peering connection (`alicloud_vpc_peer_connection`), intra- or inter-region, inside one Alibaba Cloud account. Within an account the request is accepted automatically. A cross-account peering needs the accepter side (`alicloud_vpc_peer_connection_accepter`) run with the other account's credentials; this module does not provide it.

The two VPC CIDRs must not overlap (checked from `vpc_cidr_block` / `accepting_vpc_cidr_block`). Cloud Data Transfer must be enabled on first use. A peering carries no traffic by itself. Pass `route_table_id` / `accepting_route_table_id` to add the peer-CIDR routes (`VpcPeer` next hop) in the same state, or add routes separately with `route-table`. Security group rules for the peer CIDR are still needed. The provider is single-region, so for an inter-region peering `accepting_route_table_id` must be null (enforced against the provider region); add that route with a `route-table` stack in the accepter's region. Never declare the same destination again in a `route-table` for a table passed here; the API rejects duplicate destinations.

`bandwidth` and `link_type` are inter-region only; a precondition on the peering rejects them when `accepting_region_id` equals the provider region. `accepting_ali_uid` (cross-account) with either route table is rejected by a precondition on that route entry, because the accepter must accept the peering first. `force_delete` is left off, so routes pointing at the peering must be removed first.

Provider: `aliyun/alicloud ~> 1.293`. OpenTofu `>= 1.10.0, < 1.11.0`. The module holds no backend, provider configuration or credentials; the Terragrunt implementor supplies them.

## Inputs

| Name | Type | Required | Default | Description |
|---|---|---|---|---|
| `peer_name` | `string` | yes | | Peering connection name, `<component>-<instance>-c1-<tenant>-<env>`. Validated: 2-115 chars (the `-to-accepter` / `-to-requester` route names must fit in 128), lowercase letters, digits and `-`, starting with a letter, not ending with `-`. |
| `vpc_id` | `string` | yes | | Requester VPC ID; must start with `vpc-`. |
| `vpc_cidr_block` | `string` | yes | | Requester VPC CIDR; an IPv4 CIDR with no host bits set (IPv6 and `10.0.0.1/16` are rejected). Used to reject overlap with the accepter VPC and as the accepter route destination. |
| `accepting_vpc_id` | `string` | yes | | Accepter VPC ID; must start with `vpc-` and differ from `vpc_id`. |
| `accepting_vpc_cidr_block` | `string` | yes | | Accepter VPC CIDR; an IPv4 CIDR with no host bits set (IPv6 and `10.0.0.1/16` are rejected), not overlapping or containing/contained by `vpc_cidr_block`. Used as the requester route destination. |
| `accepting_region_id` | `string` | yes | | Accepter VPC region, e.g. `ap-southeast-5` (`^[a-z]{2}-[a-z0-9-]+$`); the requester region for intra-region, another region for inter-region. |
| `accepting_ali_uid` | `number` | no | `null` | Account ID owning the accepter VPC; a positive integer. Null keeps the peering inside the current account; set, neither route table may be set. |
| `bandwidth` | `number` | no | `null` | Bandwidth in Mbit/s; a positive integer. Inter-region only; rejected by a precondition for an intra-region peering. |
| `link_type` | `string` | no | `null` | `Gold` or `Platinum`. Inter-region only; rejected by a precondition for an intra-region peering. |
| `route_table_id` | `string` | no | `null` | Requester route table (`vtb-...`) that gets a route to the accepter CIDR via this peering. Null adds none. |
| `accepting_route_table_id` | `string` | no | `null` | Accepter route table (`vtb-...`) that gets a route to the requester CIDR. Null adds none. Must be null for an inter-region peering (the provider is single-region); a plan fails if set and `accepting_region_id` differs from the provider region. |
| `description` | `string` | no | `null` | Optional peering description. |
| `tags` | `map(string)` | yes | | Resource tags. At least one tag is required; keys and values must not be empty. |

## Outputs

| Name | Description |
|---|---|
| `peer_connection_id` | VPC peering connection ID, usable as a VpcPeer route next hop. |
| `route_entry_ids` | `map(string)` of peer route entry IDs by side (`requester`, `accepter`); only the routes requested. Route entries are named `<peer_name>-to-accepter` and `<peer_name>-to-requester`. |
| `tags` | Tags applied to the peering connection. |

## Instances wrapper

`instances/` calls this module once per map entry (`for_each`), so one state holds many instances. Use it from a leaf as `source = ".../modules//vpc-peering/instances"`.

| Input | Type | Meaning |
|---|---|---|
| `instances` | `any` | At least one entry. The map key becomes `peer_name`. Each value takes `vpc_id`, `vpc_cidr_block`, `accepting_vpc_id`, `accepting_vpc_cidr_block`, `accepting_region_id`, `accepting_ali_uid`, `bandwidth`, `link_type`, `route_table_id`, `accepting_route_table_id`, `description`, `tags`. The required fields (`vpc_id`, `vpc_cidr_block`, `accepting_vpc_id`, `accepting_vpc_cidr_block`, `accepting_region_id`) are read directly, so a missing one fails at plan; optional fields are read with `try(..., null)` (`tags` with `try(..., {})`). Keys outside that list fail validation (a typo is an error, not a silent null). |
| `tags` | `map(string)` | Shared tags, at least one, keys and values non-empty; `merge`d under each entry's own `tags` (the entry wins on a clash). |

Output `instances` returns every output of this module (`peer_connection_id`, `route_entry_ids`, `tags`) keyed by entry name.

## Tests

```bash
tofu init -backend=false -input=false && tofu test
(cd instances && tofu init -backend=false -input=false && tofu test)
```
