---
name: hs:journal
description: Record concise, evidence-based engineering journal entries after a completed implementation, investigation, or plan milestone.
argument-hint: "[summary-or-path]"
metadata:
  author: hs-skills
  version: "1.0.0"
---

# Engineering Journal

Capture durable project knowledge without duplicating source documentation.

## Workflow

1. Confirm the work and verification evidence.
2. Read root `.hs.json` → `artifacts.journals.directory` and record the decision, changed behavior, tests, and follow-ups there.
3. If that configuration is absent, use the project's established journal location; otherwise return a Markdown entry for the caller to place.

## Entry Format

```markdown
## YYYY-MM-DD — Title

- Decision / outcome:
- Evidence: 
- Follow-up:
```

Never include secrets, credentials, or unverified claims.
