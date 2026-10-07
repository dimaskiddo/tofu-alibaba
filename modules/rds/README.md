# rds

Creates one Postpaid RDS instance (MySQL, PostgreSQL or MariaDB) with backup policy, databases, accounts and privileges. Tags propagate to `alicloud_db_instance`.

Provider: `aliyun/alicloud ~> 1.293`, `hashicorp/random ~> 3.7`. OpenTofu `>= 1.10.0, < 1.11.0`. The module holds no backend, provider configuration or credentials; the Terragrunt implementor supplies them.

## Inputs

| Name | Type | Required | Description |
|---|---|---|---|
| `name` | `string` | yes | Instance name, `<component>-<instance>-c1-<tenant>-<env>`. 2-256 chars: lowercase letters, digits and `-`, starting with a letter and not ending with `-`. |
| `engine` | `string` | yes | `MySQL`, `PostgreSQL` or `MariaDB` (SQLServer rejected). ForceNew. |
| `engine_version` | `string` | yes | Dotted number such as `8.0` or `15.0`. Changing it in place is an engine upgrade. |
| `category` | `string` | yes | `Basic` (single node, exactly one placement) or `HighAvailability`. |
| `instance_type` | `string` | yes | Instance class such as `mysql.n2.medium.1`; not empty. Region specific. |
| `instance_storage` | `number` | yes | GB, a multiple of 5. Minimum by `db_instance_storage_type`: `cloud_essd` 20, `cloud_essd2` 500, `cloud_essd3` 1500, `general_essd` 10, `cloud_ssd` 5 (unverified). The maximum (64000, MariaDB 32000) is not checked. |
| `db_instance_storage_type` | `string` | no | Default `cloud_essd`. One of `cloud_ssd`, `cloud_essd`, `cloud_essd2`, `cloud_essd3`, `general_essd`. |
| `placement` | `list(object)` | yes | One or two `{ zone_id = string, vswitch_id = string }` (both required) in distinct zones; primary first. ForceNew. Basic takes exactly one. A single entry on `HighAvailability` leaves the standby zone to Alibaba Cloud. |
| `security_ips` | `list(string)` | yes | 1-1000 IPv4 addresses or IPv4 CIDRs; any `/0` and the bare `0.0.0.0` are rejected. |
| `deletion_protection` | `bool` | no | Default `true`. |
| `maintain_time` | `string` | no | Default `null` (Alibaba Cloud chooses). UTC window `HH:MMZ-HH:MMZ`, for example `02:00Z-03:00Z`; any such window is accepted, its length is not checked. |
| `parameters` | `list(object)` | no | Default `[]`. `{ name = string, value = string }` (both required); names unique. |
| `storage_auto_scale` | `object` | no | Default `null` (sends `storage_auto_scale = "Disable"`). `{ threshold = number, upper_bound = number }` (both required); `threshold` 10, 20, 30, 40 or 50 (percent free space); `upper_bound` (GB) must exceed `instance_storage`. |
| `backup` | `object` | no | Default `{}`. Fields below. |
| `databases` | `list(object)` | no | Default `[]`. `{ name = string (required), character_set = string, description = string }`. Name 2-64 chars of lowercase letters, digits, `_` and `-`, starting with a letter and ending with a letter or digit; unique. `character_set` is engine specific (for example `utf8mb4`, `UTF8`). |
| `accounts` | `list(object)` | no | Default `[]`. `{ name = string (required), type = string, description = string, privilege = string, databases = list(string) }`. Fields below. |
| `account_passwords` | `map(string)` | no | Default `{}`, sensitive. Keyed by account name; 8-32 chars from letters, digits and `!@#$%^&*()_+=-`, using at least 3 of: lower case, upper case, digit, special. An account without an entry gets a random password; an entry for an account not in `accounts` is rejected. |
| `password_length` | `number` | no | Default `8`. Whole number 8-32; length of generated passwords (letters and digits). |
| `encryption_key` | `string` | no | Default `null`. KMS key ID for disk encryption; rejected for MariaDB. |
| `role_arn` | `string` | no | Default `null`. RAM role RDS uses to call KMS. Null derives the account's `AliyunRDSInstanceEncryptionDefaultRole` when `encryption_key` is set, otherwise stays null. |
| `tags` | `map(string)` | yes | Resource tags. At least one tag is required; keys and values must not be empty. |

### `backup` fields

| Field | Type | Default | Rule |
|---|---|---|---|
| `preferred_backup_period` | `list(string)` | `["Monday", "Wednesday", "Friday"]` | At least 2 distinct English weekday names. |
| `preferred_backup_time` | `string` | `"02:00Z-03:00Z"` | One of the 24 one-hour UTC windows `HH:00Z-HH+1:00Z`, from `00:00Z-01:00Z` to `23:00Z-24:00Z`. |
| `backup_retention_period` | `number` | `7` | 7-730 days. |
| `log_backup_retention_period` | `number` | `7` | At least 7 and not above `backup_retention_period`. Ignored on `Basic`, where log backup is off. |

### `accounts` fields

| Field | Type | Default | Rule |
|---|---|---|---|
| `name` | `string` | required | 2-63 chars of lowercase letters, digits and `_`, starting with a letter and ending with a letter or digit; unique. |
| `type` | `string` | `"Normal"` | `Normal` or `Super`. ForceNew. On MySQL and MariaDB at most one `Super` account, and it must leave `privilege` and `databases` unset. PostgreSQL is not restricted (the docs conflict on the Super count). |
| `description` | `string` | `null` | |
| `privilege` | `string` | `null` | Required when `databases` is not empty. `ReadOnly`, `ReadWrite`, `DDLOnly`, `DMLOnly` for MySQL and MariaDB; `DBOwner` for PostgreSQL. Applies to every listed database. |
| `databases` | `list(string)` | `[]` | Each must be a name in `databases`. An account with none gets no privileges. |

## Outputs

| Name | Description |
|---|---|
| `tags` | Tags applied to the instance. |
| `instance_id` | RDS instance ID. |
| `connection_string` | Internal connection address of the instance. |
| `port` | Connection port. |
| `database_names` | List of database names. |
| `account_names` | List of account names. |
| `generated_passwords` | Sensitive. Random account passwords keyed by account name; accounts with a supplied password are absent. Supplied passwords are never output. |

## Notes

- ForceNew: `engine`, `placement`, a database's name or character set, an account's name or type. `deletion_protection` makes a replacement fail at the delete step instead of dropping data.
- Log backup is off on Basic.
- Passwords are stored in state as sensitive values; protect the state backend.
- Encryption prerequisite: an account admin creates `AliyunRDSInstanceEncryptionDefaultRole` once (console: authorize RDS to access KMS). Disabling or deleting the key locks the instance. MariaDB disk encryption cannot be set from Terraform.
- Not verifiable offline: whether the chosen class accepts a customer key in the region, and whether the account's role policy restricts which keys RDS may use. Check both on the first plan in a test account.

## Instances wrapper

`instances/` calls this module once per map entry (`for_each`), so one state holds many instances. Use it from a leaf as `source = ".../modules//rds/instances"`.

| Input | Meaning |
|---|---|
| `instances` | Map (`any`), at least one entry. The map key becomes `name`. Each value takes `engine`, `engine_version`, `category`, `instance_type`, `instance_storage`, `db_instance_storage_type`, `placement`, `security_ips`, `deletion_protection`, `maintain_time`, `parameters`, `storage_auto_scale`, `backup`, `databases`, `accounts`, `password_length`, `encryption_key`, `role_arn`, `tags`. `engine`, `engine_version`, `category`, `instance_type`, `instance_storage`, `placement` and `security_ips` are required and read directly. Other omitted fields take the module default. Entries with any other key fail validation (typo protection). Nested objects are checked too: an unknown key inside `placement`, `databases`, `accounts`, `parameters`, `backup` or `storage_auto_scale` fails validation. |
| `tags` | Shared tags, at least one, keys and values not empty; merged under each entry's own `tags`. |
| `account_passwords` | `map(map(string))`, default `{}`, sensitive. Instance name, then account name; each inner map follows the module `account_passwords` rules. An instance key that is not in `instances` fails validation, so a typo cannot silently swap a supplied password for a generated one. |

Output `instances` returns every module output per instance name except `generated_passwords`. Output `generated_passwords` is a separate sensitive map: instance name, then account name.

## Tests

```bash
tofu init -backend=false -input=false && tofu test
(cd instances && tofu init -backend=false -input=false && tofu test)
```
