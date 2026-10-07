#!/usr/bin/env bash
# Fails if atlantis.yaml enables autodiscovery, references deploy/example-*, or has a project without
# dir + workflow terragrunt + terraform_distribution opentofu. ATLANTIS_FILE overrides the file under test.
set -euo pipefail
set -f
cd "$(dirname "$0")/.."
f="${ATLANTIS_FILE:-atlantis.yaml}"
fail=0
code="$(grep -v '^[[:space:]]*#' "$f")"
proj="$(awk '/^projects:/{p=1;next} p&&/^[^ #]/{p=0} p' <<<"$code")"

awk '/^autodiscover:/{a=1;next} a&&/^[^ ]/{a=0} a&&/mode:/{gsub(/["\047]/,"",$2);print $2}' <<<"$code" | grep -qx disabled \
  || { echo "FAIL: autodiscover.mode must be disabled" >&2; fail=1; }

if grep -Eq 'example-' <<<"$code"; then
  echo "FAIL: atlantis.yaml references an example-* tenant" >&2; fail=1
fi

# The checks below read block-style projects only; a flow-style list would pass them unseen.
if grep -Eq '^projects:[[:space:]]*[^[:space:]#]' <<<"$code" && ! grep -Eq '^projects:[[:space:]]*\[\][[:space:]]*(#.*)?$' <<<"$code"; then
  echo "FAIL: projects must be a block list (or [])" >&2; fail=1
fi

# YAML values may be quoted and may carry a trailing comment.
count() { { grep -Ec "^[[:space:]]*(- )?$1:[[:space:]]*[\"']?$2[\"']?[[:space:]]*(#.*)?$" <<<"$proj" || true; }; }
n_proj="$(count name '[^[:space:]#]+')"
for pair in "workflow terragrunt" "terraform_distribution opentofu" "dir [^[:space:]#]+"; do
  read -r key val <<<"$pair"
  n="$(count "$key" "$val")"
  [ "$n" -eq "$n_proj" ] || { echo "FAIL: $n_proj projects but $n with $key: $val" >&2; fail=1; }
done

if [ "$(awk '/^workflows:/{w=1;next} w&&/^[^ #]/{w=0} w&&/^  [^ #]/{n++} END{print n+0}' <<<"$code")" -ne 1 ]; then
  echo "FAIL: atlantis.yaml must define exactly one workflow" >&2; fail=1
fi

for key in name dir; do
  dup="$(sed -nE "s/^[[:space:]]*(- )?$key:[[:space:]]*[\"']?([^[:space:]#\"']+).*/\\2/p" <<<"$proj" | sort | uniq -d)"
  [ -z "$dup" ] || { echo "FAIL: duplicate project $key: $dup" >&2; fail=1; }
done

while IFS= read -r d; do
  d="${d%%#*}"; d="${d//\"/}"; d="${d//\'/}"; d="$(xargs <<<"$d")"
  [ -f "$d/terragrunt.hcl" ] || { echo "FAIL: project dir $d has no terragrunt.hcl" >&2; fail=1; }
done < <(sed -nE 's/^[[:space:]]*(- )?dir:[[:space:]]*(.*)$/\2/p' <<<"$proj")

[ "$fail" -eq 0 ] && echo "atlantis guard OK"
exit "$fail"
