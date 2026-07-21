#!/usr/bin/env bash
# Run Codex as an adversarial auditor over a plan file or plan directory.
# Findings written to a markdown file for Claude to triage.
#
# Usage:
#   codex-audit-plan.sh <plan-path> [out-file]
#
# <plan-path> may be a single plan.md or a directory containing plan.md + phase-*.md.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <plan-path> [out-file]" >&2
  exit 2
fi

PLAN="$1"
[[ -e "$PLAN" ]] || { echo "Plan path not found: $PLAN" >&2; exit 1; }

slug=$(basename "$PLAN" | sed 's/\.md$//')
OUT="${2:-/tmp/codex-plan-audit-${slug}.md}"

if [[ -d "$PLAN" ]]; then
  target_desc="plan directory '$PLAN' (read plan.md and all phase-*.md)"
else
  target_desc="plan file '$PLAN'"
fi

echo "[codex] auditing $target_desc -> $OUT"

codex exec \
  -s read-only \
  --ephemeral \
  --skip-git-repo-check \
  -C "$PWD" \
  -o "$OUT" \
  "Adversarial audit of $target_desc.

Report findings in this exact structure:

## Critical
- [location] issue — why it bites in prod
## High
- ...
## Medium
- ...
## Low
- ...
## Unstated Assumptions
- ...
## Untestable Acceptance Criteria
- ...

Look for:
1. Missing edge cases (empty state, error paths, concurrency, partial failure, network loss)
2. Unstated assumptions (schema shape, env vars, external API contracts)
3. Phase ordering risks (later phase needed by earlier phase)
4. Acceptance criteria that can't actually be verified
5. Scope creep vs stated goal
6. Security / privacy / data-loss gaps
7. Rollback gaps for destructive ops

Cite plan-file:section for every finding. Be brutal. Skip stylistic nits.
Do NOT propose rewrites; findings only." </dev/null

echo "[codex] audit complete: $OUT"
echo "----- preview -----"
head -80 "$OUT" || true
