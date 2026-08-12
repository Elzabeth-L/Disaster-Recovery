#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/dr-drill.sh"

test_dir="$(mktemp -d)"
trap 'rm -rf "${test_dir}"' EXIT

printf '%s\n' \
  '[{"id":9,"title":"DR note","content":"new","created_at":"later"},{"id":1,"title":"shared","content":"same","created_at":"x"}]' \
  > "${test_dir}/dr.json"
printf '%s\n' \
  '[{"id":4,"title":"shared","content":"same","created_at":"y"}]' \
  > "${test_dir}/primary.json"

existing_keys="$(jq -c '[.[] | [.title,.content] | @json]' "${test_dir}/primary.json")"
key="$(jq -r '[.title,.content] | @json' <<< '{"title":"shared","content":"same"}')"
jq -e --arg key "${key}" 'index($key) != null' <<< "${existing_keys}" >/dev/null

key="$(jq -r '[.title,.content] | @json' <<< '{"title":"DR note","content":"new"}')"
jq -e --arg key "${key}" 'index($key) == null' <<< "${existing_keys}" >/dev/null

printf '%s\n' \
  '[{"id":4,"title":"shared","content":"same"},{"id":5,"title":"DR note","content":"new"}]' \
  > "${test_dir}/merged.json"
jq -e --slurpfile dr "${test_dir}/dr.json" '
  ([.[] | [.title,.content] | @json]) as $primary |
  all($dr[0][]; ([.title,.content] | @json) as $key | $primary | index($key) != null)
' "${test_dir}/merged.json" >/dev/null

[[ "$(canonical_notes "${test_dir}/dr.json")" == \
   "$(canonical_notes "${test_dir}/merged.json")" ]]

echo "DR drill reverse-sync tests passed."
