# Codex for Plan & Spec Auditing

Codex reads files **carefully** — slower than Opus, but less likely to skim over a buried assumption or a numbered requirement. This makes it the best second opinion for **plan-stage** documents where missing an edge case is expensive downstream.

## When To Audit A Plan With Codex

- Right after `/hs:plan` finishes, before `/hs:cook` starts
- When the plan has 3+ phases or touches >5 files
- When the plan involves migrations, auth, money, or external APIs
- When user explicitly asks "audit this plan" or "what am I missing"

## One-Shot Plan Audit

```bash
codex exec -s read-only -C "$PWD" \
  "Audit ./plans/260518-1206-foo/plan.md and all phase-*.md files in that directory.
   Report:
   1. Missing edge cases (empty state, error paths, concurrent access, partial failure)
   2. Unstated assumptions (about schemas, APIs, environments)
   3. Phase ordering risks (does phase 3 depend on something phase 4 builds?)
   4. Untestable acceptance criteria
   5. Scope creep vs original goal
   6. Security/privacy gaps
   Cite plan-file:section for every finding. Be brutal. Skip stylistic feedback."
```

Or use `scripts/codex-audit-plan.sh <plan-dir-or-file>` which wraps this.

## Iterative Audit Loop

For high-stakes plans, do **two passes**:

```bash
# Pass 1 — broad
codex exec -s read-only -o /tmp/audit-pass1.md -C "$PWD" \
  "First-pass audit of plans/260518-foo/. List all concerns."

# Pass 2 — adversarial (feed pass 1 back in)
codex exec -s read-only -o /tmp/audit-pass2.md -C "$PWD" \
  "Read /tmp/audit-pass1.md and plans/260518-foo/. Now play devil's advocate:
   what did the first pass MISS? What's worse than it claims?"
```

Surface both passes to user, do not auto-merge.

## Prompt Patterns That Work

### Persona framing

```
Audit as if you were the on-call engineer who will get paged at 3 AM
when this ships broken. What scares you?
```

### Concrete checklist

```
Verify each of these against the plan:
- [ ] Rollback path defined for every destructive op
- [ ] All env vars documented
- [ ] Migration is online-safe (no long locks)
- [ ] Auth/authz changes have explicit test cases
- [ ] No hardcoded secrets, URLs, IDs
Report PASS/FAIL/UNCLEAR per item with evidence.
```

### JSON-schema-constrained output

```bash
cat > /tmp/audit-schema.json <<'EOF'
{
  "type":"object",
  "properties":{
    "findings":{"type":"array","items":{
      "type":"object",
      "properties":{
        "severity":{"enum":["critical","high","medium","low"]},
        "category":{"type":"string"},
        "location":{"type":"string"},
        "issue":{"type":"string"},
        "suggestion":{"type":"string"}
      },"required":["severity","category","location","issue"]
    }}
  },"required":["findings"]
}
EOF
codex exec --output-schema /tmp/audit-schema.json -s read-only -C "$PWD" \
  "Audit plans/foo/ — structured findings only"
```

## Handoff Back To Claude

After Codex audit:

1. **Read the full audit verbatim** — surface ALL findings to user
2. **Apply rule `review-audit-self-decision.md`**: don't silently flip user-confirmed decisions; verified items stay sticky
3. **Categorize**: real bugs → fix; YAGNI-y nits → note for later; user-decision reversals → ask before applying
4. **Update the plan** with addressed findings (mark resolved, defer, or reject-with-reason)

## Avoidances

- **Don't ask Codex to "improve" the plan** — that triggers rewriting, not auditing. Ask for **findings only**.
- **Don't auto-apply audit suggestions to plan files** without user review — Codex will sometimes recommend YAGNI cuts that reverse user intent.
- **Don't audit a plan Codex itself wrote** in the same session — confirmation bias. Get a fresh session: `--ephemeral`.
- **Don't run audit with `workspace-write`** — read-only is sufficient and prevents Codex from "helpfully" editing the plan.
