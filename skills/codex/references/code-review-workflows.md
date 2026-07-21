# Codex for Code Review & PR Audit

Codex (GPT-5.5) reads files carefully, which makes it a strong **adversarial second reviewer**. Use it after Claude completes implementation, before merging.

## When To Reach For Codex Review

- Claude (especially Opus 4.x) just finished a non-trivial implementation
- A PR touches security-sensitive code (auth, payments, permissions, migrations)
- You suspect Claude skimmed something (long files, dense refactors, generated code)
- You want a fresh-context review unbiased by the implementation conversation

## Three Review Modes

### 1. Local uncommitted changes

```bash
codex review --uncommitted "Focus on null-safety, error paths, and concurrent writes" -C "$PWD"
```

### 2. Branch vs base

```bash
codex review --base main --title "Add invoice export" \
  "Audit for: SQL injection, race conditions, missing tests, API contract drift"
```

### 3. Specific commit

```bash
codex review --commit abc1234 "Verify migration is reversible and online-safe"
```

### 4. GitHub PR (via gh + checkout)

Use `scripts/codex-review-pr.sh <pr-number>` — it fetches the PR, checks it out, runs `codex review --base <pr-base>`, then restores prior branch.

## Effective Review Prompts

Bad: `"Review this"`. Codex needs **what to look for**.

Good prompt skeleton:

```
Audit the diff for:
1. Correctness — off-by-one, null deref, wrong return type, missing await
2. Security — injection, authz bypass, secret leakage, unsafe deserialization
3. Concurrency — races, deadlocks, missing locks on shared state
4. Edge cases — empty input, unicode, very large input, partial failure
5. Test coverage gaps — branches/paths not exercised
6. API/schema drift — breaking changes vs existing callers
Report each finding with file:line + severity (critical/high/medium/low).
Skip style nits.
```

## Handoff Pattern (Claude → Codex → Claude)

```bash
# 1. Codex audits, writes findings to file
codex review --base main \
  -o /tmp/codex-review.md \
  "List concrete issues with file:line citations" -C "$PWD"

# 2. Claude reads findings and addresses them
# (read /tmp/codex-review.md, triage, fix)
```

This preserves Claude's main context — only the curated findings come back in.

## Avoidances

- **Don't run Codex review on massive diffs (>2000 lines)** — split by directory or commit; otherwise Codex spreads attention thin and quality drops.
- **Don't let Codex auto-apply fixes** during review. Use `read-only` sandbox: `codex review` already defaults to read-only.
- **Don't ignore "DONE_WITH_CONCERNS"-style hedging in Codex output** — when Codex hedges, it usually spotted something real. Re-prompt for specifics.
- **Don't treat Codex findings as gospel** — validate each against the actual code (per the `review-audit-self-decision.md` rule: verified decisions are sticky).

## GitHub-Native Code Review (No Local Checkout)

If the repo has the [Codex GitHub integration](https://developers.openai.com/codex/integrations/github) installed, you can trigger a review without local checkout:

- **Manual**: comment `@codex review` on a PR
- **Automatic**: enable in repo settings — Codex reviews every PR
- **Filter**: only P0/P1 findings are posted as PR comments (lower severity hidden)
- **Steering**: `AGENTS.md` at repo root (or per-package) drives review focus

Use this when you don't have the PR checked out locally and just want a Codex pass posted to the PR thread. Use the local `scripts/codex-review-pr.sh` when you want findings as a markdown file Claude can read.

## CI Integration (`openai/codex-action`)

For headless, secure CI use the [official Action](https://github.com/openai/codex-action) — it proxies API access without exposing tokens in logs. Pattern:

```yaml
- uses: openai/codex-action@v1
  with:
    command: review
    base: ${{ github.base_ref }}
    instructions: "Audit for correctness, security, concurrency, edge cases. P0/P1 only."
  env:
    OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
```

Combine with `--json` + `jq` to fail the job on critical findings:

```bash
codex exec --json --output-schema schema.json "..." \
  | jq -e 'select(.type=="turn.completed") | .findings | map(.severity=="critical") | any | not'
```

## Combining With `/hs:code-review`

`/hs:code-review` is Claude-driven. To get dual-LLM coverage:

1. Run `/hs:code-review` first (Claude perspective)
2. Then `codex review --base main` (Codex perspective)
3. Diff the two finding sets — overlapping items are highest-confidence bugs

## Role-Play Variant

You can ask Codex to review _as_ another role (it role-plays well):

```bash
codex review --base main \
  "Adopt the perspective of a senior security engineer doing pre-deploy gate review. Be paranoid. Reject anything you can't verify safe."
```
