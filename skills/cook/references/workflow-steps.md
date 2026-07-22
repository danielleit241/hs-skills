# Unified Workflow Steps

All modes share core steps with mode-specific variations.

**Runtime behavior:** Ask the user at required approval gates, delegate bounded specialist work when available, and track progress only when supported. Progress tracking is optional; every step remains functional without it.

## Step 0: Intent Detection & Setup

1. Parse input with `intent-detection.md` rules
2. Log detected mode: `✓ Step 0: Mode [X] - [reason]`
3. If mode=code: detect plan path, set active plan
4. Optionally record workflow steps and dependencies when the current runtime supports progress tracking.

**Output:** `✓ Step 0: Mode [interactive|auto|fast|parallel|no-test|code] - [detection reason]`

## Step 1: Research (skip if fast/code mode)

**Interactive/Auto:**

- Spawn multiple `researcher` agents in parallel
- Use internal `scout` for codebase search. External scouting has separate explicit-consent rules.
- Keep reports ≤150 lines

**Parallel:**

- Optional: max 2 researchers if complex

**Output:** `✓ Step 1: Research complete - [N] reports gathered`

### [Review Gate 1] Post-Research (skip if auto mode)

- Present research summary to user
- MUST ask the user: “Proceed to planning?”, “Request more research”, or “Abort”. Do not continue without a response.
- **Auto mode:** Skip this gate

## Step 2: Planning

**Interactive/Auto/No-test:**

- Use `planner` agent with research context
- Create `plan.md` + `phase-XX-*.md` files

**Fast:**

- Use `/hs:plan --fast` with scout results only
- Minimal planning, focus on action

**Parallel:**

- Use `/hs:plan --parallel` for dependency graph + file ownership matrix

**Code:**

- Skip - plan already exists
- Parse existing plan for phases

**Output:** `✓ Step 2: Plan created - [N] phases`

### [Review Gate 2] Post-Plan (skip if auto mode)

- Present plan overview with phases
- MUST ask the user: “Validate the plan or approve plan to start implementation?” — Validate / Approve / Abort / Request revisions. Do not begin implementation without approval.
  - "Validate": run `/hs:plan validate` skill invocation
  - "Approve": continue to implementation
  - "Abort": stop the workflow
  - "Other": revise the plan based on user's feedback
- **Auto mode:** Skip this gate

## Step 3: Implementation

**IMPORTANT:**

1. If runtime tracking exists, inspect existing tracked work hydrated by planning.
2. Otherwise read plan phases directly; plan files remain the source of truth.
3. Optionally record unchecked items with priority and phase metadata when progress tracking is available.
4. Model dependencies explicitly in the plan; tracking dependencies are optional.

**All modes:**

- When progress tracking is available, mark work in progress; never use tracking as completion evidence.
- Before modifying code, read the active Technical Design or plan and identify decisions it leaves unspecified. Use the active plan directory, including when the supplied plan is a phase file.
- Record only material deviations from the approved plan or Technical Design, including assumptions, trade-offs, architecture changes, workarounds, and maintainer-relevant consequences. Prefer the active plan or an existing decision record; do not create a new artifact solely for this purpose.
- Keep the codebase clean, structurally consistent, and maintainable. Add comments only for **WHY** (intent, rationale, or trade-offs), never to restate **WHAT** clear code expresses.
- Execute phase tasks sequentially (Step 3.1, 3.2, etc.)
- Use `ui-ux-designer` for frontend
- For image assets, use the project's approved image-generation workflow when one is available; otherwise request a user-provided asset.
- Run type checking after each file

**Parallel mode:**

- Delegate bounded parallel work when delegation is available; otherwise run the same work sequentially and report the fallback.
- Launch multiple `fullstack-developer` agents
- When delegated agents pick up work, optionally record progress when the runtime supports it.
- Respect file ownership boundaries
- Wait for parallel group before next

**Output:** `✓ Step 3: Implemented [N] files - [X/Y] tasks complete`

### [Review Gate 3] Post-Implementation (skip if auto mode)

- Present implementation summary (files changed, key changes)
- MUST ask the user: “Proceed to testing?”, “Request implementation changes”, or “Abort”. Do not continue without a response.
- **Auto mode:** Skip this gate

## Step 4: Testing (skip if no-test mode)

**All modes (except no-test):**

- Before writing tests, confirm the relevant requirement, acceptance criteria, and design decisions. Ask for clarification when they are ambiguous; do not let an early test lock in an unvalidated design.
- Use TDD when it helps discover the behavior: write one focused failing test, implement the smallest behavior that satisfies it, then refactor. Do not treat this cycle as a requirement to test every change or as evidence the design is correct.
- Test observable business behavior and public APIs first: critical flows, happy paths, edge cases, errors, and regressions. Avoid coupling tests to private implementation details unless that detail is itself a contractual boundary.
- Treat every test as a hypothesis. When it fails, compare the assertion with the specification and business intent before changing either the production code or the test.
- Treat passing tests as evidence, not proof. Supplement them with the appropriate checks for the change, such as review of requirements, type checks, integration checks, manual verification, or production-like validation.
- When testing is applicable, MUST delegate the scoped test suite to the tester specialist when delegation is available. Otherwise run the same scoped suite sequentially and retain its evidence.
- If failures, hand off evidence to `debugger` only when a fix is authorized.
- **Forbidden:** fake mocks, commented-out tests, changing assertions merely to make them pass, or skipping required delegation.

**Output:** `✓ Step 4: Test evidence - [scopes run, results, requirement/design checks, and any justified exceptions]`

### [Review Gate 4] Post-Testing (skip if auto mode)

- Present test results summary
- MUST ask the user: “Proceed to code review?”, “Request test fixes”, or “Abort”. Do not continue without a response.
- **Auto mode:** Skip this gate

## Step 5: Code Review

**All modes - MANDATORY subagent:**

- MUST delegate code review to the code-reviewer specialist when delegation is available. Otherwise perform the same evidence-backed review sequentially.
- **DO NOT** review code yourself - delegate to subagent
- Verify that material deviations from the approved plan or Technical Design are documented where maintainers can find them.
- Verify the implementation remains clean, consistent, and maintainable; flag unnecessary duplication and recommend reuse when it improves clarity without over-abstraction. Also flag comments that restate code instead of documenting intent, rationale, or trade-offs.

**Interactive/Parallel/Code/No-test:**

- Interactive cycle (max 3): see `review-cycle.md`
- Requires user approval

**Auto:**

- Auto-approve if score≥9.5 AND 0 critical
- Report critical findings and hand off for an explicit fix decision.

**Fast:**

- Simplified review, no fix loop
- User approves or aborts

**Output:** `✓ Step 5: Review [score]/10 - [Approved|Auto-approved] - code-reviewer subagent invoked`

## Step 6: Finalize

**All modes — required finalization handoffs:**

1. Run applicable handoffs in parallel:
   - MUST delegate verified plan-status synchronization for `[plan-path]` to the project-manager specialist when available; otherwise perform the same synchronization sequentially.
   - MUST delegate documentation updates affected by verified changes to the docs-manager specialist when available; otherwise perform them sequentially.
2. Project-manager sync-back MUST include:

### Status Sync (Finalize)

Use CLI commands for deterministic status updates:

```bash
# Mark completed phases
ck plan check <phase-id>

# Mark in-progress phases
ck plan check <phase-id> --start

# Revert if needed
ck plan uncheck <phase-id>
```

**Fallback:** If `ck` is not available, edit plan.md directly —
only change the Status column cell, preserve table structure.

- Sweep all `phase-XX-*.md` files in the plan directory.
- Mark every completed item `[ ] → [x]` based on completed tasks (including earlier phases finished before current phase).
- Update `plan.md` status/progress (`pending`/`in-progress`/`completed`) from actual checkbox state.
- Return unresolved mappings if any completed task cannot be matched to a phase file.

3. After sync-back confirmation, optionally record completion when progress tracking is available. The verification evidence remains authoritative.
4. Onboarding check (API keys, env vars)
5. Do not stage, commit, or push by default. Invoke `git-manager` only after explicit user authorization for a focused commit in the current conversation.

**CRITICAL:** Step 6 is complete after applicable sync/documentation handoffs and evidence are recorded. A commit is never a completion condition.

**Auto mode:** Continue to next phase automatically, start from **Step 3**.
**Others:** Ask user before next phase

**Output:** `✓ Step 6: Finalized - applicable handoffs complete - Full-plan sync-back completed`

## Mode-Specific Flow Summary

Legend: `[R]` = Review Gate (human approval required)

```
interactive: 0 → 1 → [R] → 2 → [R] → 3 → [R] → 4 → [R] → 5(user) → 6
auto:        0 → 1 → 2 → 3 → 4 → 5(auto) → 6 → next phase (NO stops)
fast:        0 → skip → 2(fast) → [R] → 3 → [R] → 4 → [R] → 5(simple) → 6
parallel:    0 → 1? → [R] → 2(parallel) → [R] → 3(multi-agent) → [R] → 4 → [R] → 5(user) → 6
no-test:     0 → 1 → [R] → 2 → [R] → 3 → [R] → skip → 5(user) → 6
code:        0 → skip → skip → 3 → [R] → 4 → [R] → 5(user) → 6
```

**Key difference:** `auto` may continue implementation gates, but never authorizes commits, pushes, external providers, destructive actions, or disclosure of repository data.

## Critical Rules

- Never skip steps without mode justification
- **MANDATORY HANDOFF INTENT:** Delegate applicable specialist work when delegation is available; otherwise perform the same bounded work sequentially and report that fallback.
  - Step 4: `tester` (and `debugger` if failures)
  - Step 5: `code-reviewer`
  - Step 6: `project-manager`, `docs-manager`; `git-manager` only with explicit authorization.
- Use progress tracking only as optional operational metadata.
- All step outputs follow format: `✓ Step [N]: [status] - [metrics]`
- **VALIDATION:** Completion requires fresh evidence, not a count of platform tool calls.
