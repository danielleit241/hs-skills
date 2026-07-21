#!/usr/bin/env bash
# Fetch a GitHub PR locally, run `codex review` against its base branch, then
# restore the prior branch. Findings written to a markdown file.
#
# Usage:
#   codex-review-pr.sh <pr-number> [out-file]
#
# Requires: gh, codex, git.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <pr-number> [out-file]" >&2
  exit 2
fi

PR="$1"
OUT="${2:-/tmp/codex-pr-${PR}-review.md}"

command -v gh >/dev/null || { echo "gh CLI required" >&2; exit 1; }
command -v codex >/dev/null || { echo "codex CLI required" >&2; exit 1; }

prior_ref=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse HEAD)
base_branch=$(gh pr view "$PR" --json baseRefName -q .baseRefName)
pr_title=$(gh pr view "$PR" --json title -q .title)

cleanup() {
  echo "[codex] restoring $prior_ref"
  git checkout -q "$prior_ref" || true
}
trap cleanup EXIT

echo "[codex] checking out PR #$PR (base: $base_branch)"
gh pr checkout "$PR"

echo "[codex] reviewing vs $base_branch -> $OUT"
codex review \
  --base "$base_branch" \
  --title "$pr_title" \
  -C "$PWD" \
  -o "$OUT" \
  "Audit this PR for:
1. Correctness (off-by-one, null deref, wrong return type, missing await)
2. Security (injection, authz bypass, secret leakage)
3. Concurrency (races, deadlocks, missing locks)
4. Edge cases (empty input, unicode, very large input, partial failure)
5. Test-coverage gaps
6. API/schema drift
Report each finding with file:line + severity (critical/high/medium/low).
Skip style nits."

echo "[codex] review written to $OUT"
echo "----- preview -----"
head -60 "$OUT" || true
