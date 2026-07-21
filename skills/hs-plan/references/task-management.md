# Plan Progress Tracking

Plan files (`plan.md` and phase Markdown files) are the persistent source of
truth. Use `TRACK_TASK` from `../../cook/references/runtime-actions.md` only as
optional, session-local operational metadata.

## Hydration

1. Read unchecked plan items and their dependencies.
2. Optionally create corresponding runtime tracking entries.
3. When work finishes, update the plan files from verified evidence first.
4. Optionally mark tracking entries complete after the plan update.

Do not require a particular task API, a session-local task identifier, or a tool
call count for plan correctness. A new session always rehydrates from plan files.
