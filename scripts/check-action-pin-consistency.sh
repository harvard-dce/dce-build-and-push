#!/usr/bin/env bash
set -euo pipefail

pins_file=".github/action-pins.txt"
inventory_file=".github/workflows/actions-inventory.yml"
workflows_dir=".github/workflows"

errors=0
checked=0

info() {
  printf '[INFO] %s\n' "$1"
}

pass() {
  printf '[PASS] %s\n' "$1"
}

fail() {
  printf '[FAIL] %s\n' "$1" >&2
}

regex_escape() {
  printf '%s' "$1" | sed -E 's/[][(){}.^$*+?|\\]/\\&/g'
}

info "Starting action pin consistency check"
info "Pins file: $pins_file"
info "Inventory workflow: $inventory_file"
info "Workflow search root: $workflows_dir (excluding $(basename "$inventory_file"))"

if [ ! -f "$pins_file" ]; then
  fail "Missing file: $pins_file"
  exit 1
fi
pass "Found pins file"

if [ ! -f "$inventory_file" ]; then
  fail "Missing file: $inventory_file"
  exit 1
fi
pass "Found inventory workflow"

line_no=0
while IFS= read -r line || [ -n "$line" ]; do
  line_no=$((line_no + 1))

  # Skip blank lines and comments
  if [[ "$line" =~ ^[[:space:]]*$ ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
    continue
  fi

  action=""
  tag=""
  sha=""
  extra=""
  read -r action tag sha extra <<<"$line"

  if [ -z "${action:-}" ] || [ -z "${tag:-}" ] || [ -z "${sha:-}" ] || [ -n "${extra:-}" ]; then
    fail "Malformed line in $pins_file:$line_no -> '$line' (expected: action tag sha)"
    errors=$((errors + 1))
    continue
  fi

  checked=$((checked + 1))
  info "Checking [$checked] $action@$tag"

  if ! [[ "$sha" =~ ^[0-9a-f]{40}$ ]]; then
    fail "$action@$tag has invalid SHA in pins file: '$sha' (expected 40 lowercase hex chars)"
    errors=$((errors + 1))
  else
    pass "$action@$tag has valid SHA format"
  fi

  action_re="$(regex_escape "$action")"
  tag_re="$(regex_escape "$tag")"
  sha_re="$(regex_escape "$sha")"

  if grep -Eq "uses:[[:space:]]*${action_re}@${tag_re}([[:space:]]|$)" "$inventory_file"; then
    pass "Inventory contains tag ref: uses: $action@$tag"
  else
    fail "Missing inventory tag ref: uses: $action@$tag in $inventory_file"
    errors=$((errors + 1))
  fi

  if grep -R -E --include='*.yml' --include='*.yaml' \
      "uses:[[:space:]]*${action_re}@${sha_re}([[:space:]]|$)" "$workflows_dir" \
      | grep -Fv "$inventory_file" >/dev/null; then
    pass "Runtime workflows contain pinned SHA: uses: $action@$sha"
  else
    fail "Missing pinned SHA ref in runtime workflows: uses: $action@$sha"
    errors=$((errors + 1))
  fi
done < "$pins_file"

if [ "$errors" -ne 0 ]; then
  fail "Completed with $errors issue(s) across $checked action(s)."
  exit 1
fi

pass "Completed successfully. Checked $checked action(s), found 0 issues."
