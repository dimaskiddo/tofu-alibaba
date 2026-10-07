#!/usr/bin/env bash
# Offline `terragrunt run --all validate` for tenants under deploy/. Usage: validate-tenant.sh [tenant ...]
# A tenant is a directory name (acme-prod) or a path to a directory under deploy/ that holds tenant.hcl.
# With no argument every such tenant is validated. Exit code is 1 if any tenant fails, so it works as a CI step.
# The remote backend is swapped for `local` in a temp copy, because dependency outputs are read from state and
# need real backend credentials; no tenant or state credentials are needed. Providers still come from the
# registry (or a mirror via TF_CLI_CONFIG_FILE). TG_PARALLELISM limits concurrent units.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"

tenants=()
if [ "$#" -gt 0 ]; then
  for a in "$@"; do
    d="$a"
    [ -d "$d" ] || d="$root/deploy/$a"
    [ -f "$d/tenant.hcl" ] || { echo "FAIL: $a is not a tenant directory (no tenant.hcl)" >&2; exit 2; }
    d="$(cd "$d" && pwd)"
    [ "$(dirname "$d")" = "$root/deploy" ] || { echo "FAIL: $a is not directly under deploy/" >&2; exit 2; }
    tenants+=("$(basename "$d")")
  done
else
  for d in "$root"/deploy/*/; do
    [ -f "$d/tenant.hcl" ] && tenants+=("$(basename "$d")")
  done
fi
[ "${#tenants[@]}" -gt 0 ] || { echo "FAIL: no tenant found under deploy/" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp -r "$root/deploy" "$tmp/deploy"
ln -s "$root/modules" "$tmp/modules"
find "$tmp/deploy" \( -name .terragrunt-cache -o -name .terraform \) -type d -prune -exec rm -rf {} +
python3 - "$tmp/deploy/root.hcl" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
old = "contents  = local.backend_hcl"
assert old in s
s = s.replace(old, 'contents  = "terraform {\\n  backend \\"local\\" {}\\n}\\n"')
# The local backend needs no credentials, so the temp copy skips the tenant env check (dependency lookups run `output`).
s, n = re.subn(r"env_commands = \[[^\]]*\]", "env_commands = []", s)
assert n == 1
open(p, "w").write(s)
PY

failed=()
for t in "${tenants[@]}"; do
  echo "== validate $t"
  (cd "$tmp/deploy/$t" && TG_TF_PATH=tofu terragrunt run --all --non-interactive validate) || failed+=("$t")
done
if [ "${#failed[@]}" -gt 0 ]; then
  echo "FAIL: validation failed for: ${failed[*]}" >&2
  exit 1
fi
echo "validate OK: ${tenants[*]}"
