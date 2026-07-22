# Plan Progress Tracking

Plan files (`plan.md` and phase Markdown files) are the persistent source of
truth. Use runtime progress tracking only as optional, session-local operational
metadata; it is never completion evidence.

## Hydration

1. Read unchecked plan items and their dependencies.
2. Optionally create corresponding runtime tracking entries.
3. When work finishes, update the plan files from verified evidence first.
4. Optionally mark tracking entries complete after the plan update.

Do not require a particular task API, a session-local task identifier, or a tool
call count for plan correctness. A new session always rehydrates from plan files.
