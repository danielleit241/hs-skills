---
name: hs:code-review
description: "Review code quality with adversarial rigor. Supports input modes: pending changes, PR number, commit hash, codebase scan. Always-on red-team analysis finds security holes, false assumptions, and failure modes."
argument-hint: "[#PR | COMMIT | --pending | codebase [parallel] | --fix]"
metadata:
  author: hs-skills
  version: "2.0.0"
---

# Code Review

Adversarial code review with technical rigor, evidence-based claims, and verification over performative responses. Reviews are read-only by default. `--fix` is an explicit handoff to a separately authorized remediation workflow.

## Input Modes

Auto-detect from arguments. If ambiguous or no arguments, `ASK_USER` as defined in `../cook/references/runtime-actions.md`.

| Input                       | Mode          | What Gets Reviewed                       |
| --------------------------- | ------------- | ---------------------------------------- |
| `#123` or PR URL            | **PR**        | Full PR diff fetched via `gh pr diff`    |
| `abc1234` (7+ hex chars)    | **Commit**    | Single commit diff via `git show`        |
| `--pending`                 | **Pending**   | Staged + unstaged changes via `git diff` |
| _(no args, recent changes)_ | **Default**   | Recent changes in context                |
| `codebase`                  | **Codebase**  | Full codebase scan                       |
| `codebase parallel`         | **Codebase+** | Parallel multi-reviewer audit            |

**Resolution details:** `references/input-mode-resolution.md`

### No Arguments

If invoked WITHOUT arguments and no recent changes in context, `ASK_USER`: “What would you like to review?”

| Option                  | Description                     |
| ----------------------- | ------------------------------- |
| Pending changes         | Review staged/unstaged git diff |
| Enter PR number         | Fetch and review a specific PR  |
| Enter commit hash       | Review a specific commit        |
| Full codebase scan      | Deep codebase analysis          |
| Parallel codebase audit | Multi-reviewer codebase scan    |

## Core Principle

**YAGNI**, **KISS**, **DRY** always. Technical correctness over social comfort.
**Be honest, be brutal, straight to the point, and be concise.**

Verify before claiming. Ask before assuming. Evidence before claims.

## Practices

| Practice                 | When                                                           | Reference                                      |
| ------------------------ | -------------------------------------------------------------- | ---------------------------------------------- |
| **Spec compliance**      | After implementing from plan/spec, BEFORE quality review       | `references/spec-compliance-review.md`         |
| **Adversarial review**   | Always-on Stage 3 — actively tries to break the code           | `references/adversarial-review.md`             |
| Receiving feedback       | Unclear feedback, external reviewers, needs prioritization     | `references/code-review-reception.md`          |
| Requesting review        | After tasks, before merge, stuck on problem                    | `references/requesting-code-review.md`         |
| Verification gates       | Before any completion claim, commit, PR                        | `references/verification-before-completion.md` |
| Edge case scouting       | After implementation, before review                            | `references/edge-case-scouting.md`             |
| **Checklist review**     | Pre-landing, `/hs:ship` pipeline, security audit               | `references/checklist-workflow.md`             |
| **Task-managed reviews** | Multi-file features (3+ files), parallel reviewers, fix cycles | `references/task-management-reviews.md`        |

## Quick Decision Tree

```
SITUATION?
│
├─ Input mode? → Resolve diff (references/input-mode-resolution.md)
│   ├─ #PR / URL → fetch PR diff
│   ├─ commit hash → git show
│   ├─ --pending → git diff (staged + unstaged)
│   ├─ codebase → full scan (references/codebase-scan-workflow.md)
│   ├─ codebase parallel → parallel audit (references/parallel-review-workflow.md)
│   └─ default → recent changes in context
│
├─ Received feedback → STOP if unclear, verify if external, report/adjudicate findings
├─ Completed work from plan/spec:
│   ├─ Stage 1: Spec compliance review (references/spec-compliance-review.md)
│   │   └─ PASS? → Stage 2 │ FAIL? → report findings; hand off only if a fix is authorized
│   ├─ Stage 2: Code quality review (code-reviewer subagent)
│   │   └─ Scout edge cases → Review standards, performance
│   └─ Stage 3: Adversarial review (references/adversarial-review.md) [ALWAYS-ON]
│       └─ Red-team the code → Adjudicate → Accept/Reject findings
├─ Completed work (no plan) → Scout → Code quality → Adversarial review
├─ Pre-landing / ship → Load checklists → Two-pass review → Adversarial review
├─ Multi-file feature (3+ files) → Create a read-only review pipeline (scout→review→adversarial→verify)
└─ About to claim status → RUN verification command FIRST
```

### Three-Stage Review Protocol

**Stage 1 — Spec Compliance** (load `references/spec-compliance-review.md`)

- Does code match what was requested?
- Any missing requirements? Any unjustified extras?
- MUST pass before Stage 2

**Stage 2 — Code Quality** (code-reviewer subagent)

- Only runs AFTER spec compliance passes
- Standards, security, performance, edge cases

**Stage 3 — Adversarial Review** (load `references/adversarial-review.md`)

- Runs AFTER Stage 2 passes, subject to scope gate (skip if <=2 files, <=30 lines, no security files)
- Spawn adversarial reviewer with context anchoring (runtime, framework, context files)
- Find: security holes, false assumptions, resource exhaustion, race conditions, supply chain, observability gaps
- Output: Accept (must fix) / Reject (false positive) / Defer (GitHub issue) verdicts per finding
- Critical findings block a positive recommendation; re-review occurs only after an explicitly authorized fix handoff.

## Receiving Feedback

**Pattern:** READ → UNDERSTAND → VERIFY → EVALUATE → RESPOND → HAND_OFF
No performative agreement. Verify before recommending a change. Push back if wrong.

**Full protocol:** `references/code-review-reception.md`

## Requesting Review

**When:** After each task, major features, before merge

**Process:**

1. **Scout edge cases first** (see below)
2. Get SHAs: `BASE_SHA=$(git rev-parse HEAD~1)` and `HEAD_SHA=$(git rev-parse HEAD)`
3. Dispatch code-reviewer subagent with: WHAT, PLAN, BASE_SHA, HEAD_SHA, DESCRIPTION
4. Report Critical and Important findings with evidence. Do not edit files unless `--fix` or a separate user request explicitly authorizes remediation.

**Full protocol:** `references/requesting-code-review.md`

## Edge Case Scouting

**When:** After implementation, before requesting code-reviewer

**Process:**

1. Invoke `/hs:scout` with edge-case-focused prompt
2. Scout analyzes: affected files, data flows, error paths, boundary conditions
3. Review scout findings for potential issues
4. Address critical gaps before code review

**Full protocol:** `references/edge-case-scouting.md`

## Task-Managed Review Pipeline

**When:** Multi-file features (3+ changed files) or parallel code-reviewer scopes.

Use `SPAWN_AGENT` and optional `TRACK_TASK` from `../cook/references/runtime-actions.md`; concrete platform tools are adapter details.

**Pipeline:** scout → review → adversarial → verify. It produces findings and evidence only.

```
TRACK_TASK: “Scout edge cases”       → pending
TRACK_TASK: “Review implementation”  → pending, depends on scout
TRACK_TASK: “Adversarial review”     → pending, depends on review
TRACK_TASK: “Verify evidence”        → pending, depends on adversarial
```

**Parallel reviews:** `SPAWN_AGENT(code-reviewer, scope)` for independent file groups. Aggregate findings before reporting.

**Re-review cycles:** A later, explicitly authorized fix may be followed by a fresh review. The review skill does not create a fix task itself.

**Full protocol:** `references/task-management-reviews.md`

## Verification Gates

**Iron Law:** NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE

**Gate:** IDENTIFY command → RUN full → READ output → VERIFY confirms → THEN claim

**Requirements:**

- Tests pass: Output shows 0 failures
- Build succeeds: Exit 0
- Bug fixed: Original symptom passes
- Requirements met: Checklist verified

**Red Flags:** "should"/"probably"/"seems to", satisfaction before verification, trusting agent reports

**Full protocol:** `references/verification-before-completion.md`

## Integration with Workflows

- **Subagent-Driven:** Scout → Review → Adversarial → Verify before next task
- **Pull Requests:** Scout → Code quality → Adversarial → Merge
- **Task Pipeline:** Optional tracking for the read-only review stages.
- **Cook Handoff:** Cook completes phase → review reports findings/evidence → user or authorized implementation workflow decides whether to fix.
- **PR Review:** `/code-review #123` → fetch diff → full 3-stage review on PR changes
- **Commit Review:** `/code-review abc1234` → review specific commit with full pipeline

## Codebase Analysis Subcommands

| Subcommand                          | Reference                                | Purpose                                     |
| ----------------------------------- | ---------------------------------------- | ------------------------------------------- |
| `/hs:code-review codebase`          | `references/codebase-scan-workflow.md`   | Scan & analyze the codebase                 |
| `/hs:code-review codebase parallel` | `references/parallel-review-workflow.md` | Ultrathink edge cases, then parallel verify |

## Bottom Line

1. Resolve input mode first — know WHAT you're reviewing
2. Technical rigor over social performance
3. Scout edge cases before review
4. Adversarial review on EVERY review — no exceptions
5. Evidence before claims

Verify. Scout. Red-team. Question. Report evidence. Then hand off.
