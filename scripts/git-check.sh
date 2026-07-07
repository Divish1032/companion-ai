#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "git-check: $*" >&2
  exit 1
}

staged_files=$(git diff --cached --name-only --diff-filter=ACMR)

if [ -z "$staged_files" ]; then
  exit 0
fi

conflict_files=$(printf '%s\n' "$staged_files" | xargs grep -nE '^(<<<<<<<|=======|>>>>>>>)' 2>/dev/null || true)
if [ -n "$conflict_files" ]; then
  echo "$conflict_files" >&2
  fail "merge conflict markers found"
fi

secret_hits=$(printf '%s\n' "$staged_files" | xargs grep -nE '(BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|[A-Z0-9_]*(API_KEY|API_SECRET|SECRET|TOKEN|PASSWORD|PRIVATE_KEY)[A-Z0-9_]*[[:space:]]*=[[:space:]]*["'\'']?[A-Za-z0-9_./+=:-]{16,})' 2>/dev/null || true)
if [ -n "$secret_hits" ]; then
  echo "$secret_hits" >&2
  fail "possible secret found in staged files"
fi

large_files=""
while IFS= read -r file; do
  [ -f "$file" ] || continue
  size=$(wc -c < "$file")
  if [ "$size" -gt 5242880 ]; then
    large_files="${large_files}${file} (${size} bytes)
"
  fi
done <<EOF
$staged_files
EOF

if [ -n "$large_files" ]; then
  echo "$large_files" >&2
  fail "staged file exceeds 5MB; use an external artifact store unless intentionally approved"
fi

exit 0
