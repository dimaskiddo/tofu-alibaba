# ram

Creates one RAM user with one AccessKey and no console login. Used as the principal of OSS bucket policies.

Provider: `aliyun/alicloud ~> 1.293`. OpenTofu `>= 1.10.0, < 1.11.0`. The module holds no backend, provider configuration or credentials; the Terragrunt implementor supplies them.

## Inputs

| Name | Type | Required | Description |
|---|---|---|---|
| `name` | `string` | yes | RAM user name, `<component>-<instance>-c1-<tenant>-<env>`. Must match `^[a-z0-9][a-z0-9.-]{0,62}[a-z0-9]$`: 2-64 chars, lowercase letters, digits, `.` and `-`, starting and ending with a letter or digit. Unique per Alibaba Cloud account. |
| `comments` | `string` | no | Default `null`. User comment. |
| `tags` | `map(string)` | yes | Resource tags. At least one tag is required; keys and values must not be empty. |

## Outputs

| Name | Description |
|---|---|
| `tags` | Tags applied to the user. |
| `user_name` | RAM user name. |
| `user_id` | RAM user ID (UserId); the principal in resource policies. |
| `access_key_id` | AccessKey ID of the user. |
| `generated_passwords` | Sensitive `{ access_key_id, access_key_secret }`. Printed by the Atlantis workflow after apply (owner decision 2026-10-02); the secret sits in state in plaintext. Do not reuse this output name. |

## Notes

- The user has no permissions of its own; a resource policy (for example the OSS bucket policy) grants access.
- Rotate the key with `terragrunt apply -replace='...alicloud_ram_access_key.this'` through Atlantis, then hand out the new secret.
- The deploy credentials need `ram:CreateUser`, `ram:DeleteUser`, `ram:CreateAccessKey`, `ram:DeleteAccessKey` and `ram:TagResources`.

## Instances wrapper

`instances/` calls this module once per map entry (`for_each`), so one state holds many users. Use it from a leaf as `source = ".../modules//ram/instances"`.

| Input | Meaning |
|---|---|
| `instances` | Map (`any`), at least one entry. The map key becomes the user `name`. Each value takes `comments`, `tags`. Entries with any other key fail validation (typo protection). |
| `tags` | Shared tags, at least one; keys and values must not be empty. Merged under each entry's own `tags` (the entry wins on a clash). |

Output `instances` returns every output of this module keyed by entry name, except `generated_passwords`. Output `generated_passwords` (sensitive) returns the AccessKey ID and secret keyed by entry name.

## Tests

```bash
tofu init -backend=false -input=false && tofu test
(cd instances && tofu init -backend=false -input=false && tofu test)
```
