---
description: Prepare and create one focused commit from explicitly approved paths.
---

Create a commit only after the user explicitly requests it in the current conversation.

1. Inspect `git status` and identify paths that belong to the requested task. Do not include unrelated or pre-existing user changes.
2. Show the proposed path list and staged diff for review. Stop if scope is ambiguous.
3. Check that no secret, credential, generated output, or local configuration file is staged.
4. Stage only the approved paths, using separate commits only when the changes are independently reviewable.
5. Create a concise conventional commit message (under 70 characters) without AI attribution.
6. Report the commit hash, message, staged paths, and validation evidence.

This command never pushes. Use the dedicated push workflow only after a separate explicit request.
