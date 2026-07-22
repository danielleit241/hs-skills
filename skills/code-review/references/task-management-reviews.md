# Review Progress Tracking

The review pipeline is read-only: scout, review, adversarial analysis, and
evidence verification. Progress tracking may show dependencies when supported,
but it is optional and never completion evidence.

Findings are the persistent output. A review must never create a remediation task
or modify files by default. If the user explicitly asks to fix findings, hand off
the accepted findings to a separate implementation workflow and re-review its
result as a new request.
