# Review Progress Tracking

The review pipeline is read-only: scout, review, adversarial analysis, and
evidence verification. Use optional `TRACK_TASK` from
`../../cook/references/runtime-actions.md` to show dependencies when supported.

Findings are the persistent output. A review must never create a remediation task
or modify files by default. If the user explicitly asks to fix findings, hand off
the accepted findings to a separate implementation workflow and re-review its
result as a new request.
