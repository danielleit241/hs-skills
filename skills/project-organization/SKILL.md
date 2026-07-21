---
name: hs:project-organization
description: Organize task outputs, reports, and plans into the current project's established structure without moving unrelated files.
argument-hint: "[artifacts-or-task]"
metadata:
  author: hs-skills
  version: "1.0.0"
---

# Project Organization

Keep engineering artifacts discoverable while respecting the repository's existing conventions.

## Workflow

1. Inspect root `.hs.json`, the repository layout, and any local instructions. Treat `artifacts` paths as the default homes for plans, reports, journals, images, and Repomix output.
2. Classify outputs as source, tests, documentation, plans, reports, or temporary artifacts.
3. Place or recommend locations consistent with existing conventions; retain the current location when no move is necessary.
4. Report changed paths and any unresolved ownership decision.

Do not delete, rename, or relocate unrelated files. Do not create an organization hierarchy solely for a one-off artifact.
