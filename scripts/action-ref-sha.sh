#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF' >&2
Usage:
  scripts/action-ref-sha.sh <owner/repo> [ref]
  scripts/action-ref-sha.sh <owner/repo/path> [ref]

Examples:
  scripts/action-ref-sha.sh actions/checkout v6
  scripts/action-ref-sha.sh docker/build-push-action v6
  scripts/action-ref-sha.sh aws-actions/configure-aws-credentials main
  scripts/action-ref-sha.sh actions/checkout

Notes:
  - If [ref] is omitted, resolves the latest tag in the repository.
  - To guarantee release-style pinning, pass an explicit release tag (for example `v2`).
  - Outputs only the resolved 40-character commit SHA to stdout.
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  usage
  exit 1
fi

action="$1"
ref="${2:-}"

owner_repo="$(printf '%s' "$action" | cut -d/ -f1-2)"
repo_url="https://github.com/${owner_repo}.git"

if [ -z "$ref" ]; then
  ref="$(git ls-remote --tags --refs "$repo_url" | awk '{print $2}' | sed 's#refs/tags/##' | sort -V | tail -n1)"
  if [ -z "$ref" ]; then
    echo "Failed to resolve latest tag for ${owner_repo}" >&2
    exit 2
  fi
fi

if printf '%s' "$ref" | grep -Eq '^[0-9a-f]{40}$'; then
  printf '%s\n' "$ref"
  exit 0
fi

resolve_ref() {
  local refspec="$1"
  git ls-remote "$repo_url" "$refspec" | awk 'NR==1 {print $1}'
}

sha="$(resolve_ref "refs/tags/${ref}")"
if ! printf '%s' "$sha" | grep -Eq '^[0-9a-f]{40}$'; then
  sha="$(resolve_ref "refs/tags/${ref}^{}")"
fi
if ! printf '%s' "$sha" | grep -Eq '^[0-9a-f]{40}$'; then
  sha="$(resolve_ref "refs/heads/${ref}")"
fi

if ! printf '%s' "$sha" | grep -Eq '^[0-9a-f]{40}$'; then
  echo "Failed to resolve ref '${ref}' for ${owner_repo}" >&2
  exit 2
fi

printf '%s\n' "$sha"
