# Scout Progress Tracking

Scout reports are the source of truth. Use runtime progress tracking only when
the current runtime offers it, and never treat tracking as completion evidence.

For each delegated scout scope, record when useful: target directories, assigned
role, status, timeout, and report location. Tracking failure must not block a
scout report or make the workflow incomplete. Do not assume task state survives a
session; preserve useful results in the final scout report.
