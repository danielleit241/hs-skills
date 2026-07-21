# Scout Progress Tracking

Scout reports are the source of truth. Use `TRACK_TASK` from
`../../cook/references/runtime-actions.md` only when the current runtime offers
task tracking.

For each delegated scout scope, record when useful: target directories, assigned
role, status, timeout, and report location. Tracking failure must not block a
scout report or make the workflow incomplete. Do not assume task state survives a
session; preserve useful results in the final scout report.
