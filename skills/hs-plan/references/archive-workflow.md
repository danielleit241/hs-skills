# Archive Workflow

## Your mission

Read root `.hs.json` for `artifacts.plans.directory`, `artifacts.plans.archiveDirectory`, and `artifacts.journals.directory`. Analyze the configured plans directory, then write journal entries and archive selected plans.

## Plan Resolution

1. If `$ARGUMENTS` provided → Use that path
2. Else read all plans in `.hs.json` → `artifacts.plans.directory`

## Workflow

### Step 1: Read Plan Files

Read the plan directory:

- `plan.md` - Overview and phases list
- `phase-*.md` - 20 first lines of each phase file to understand the progress and status

### Step 2: Summarize the plans and document them with `/hs:journal` skill invocation

Ask whether the user wants journal entries before creating them.
Skip this step if user selects "No".
If user selects "Yes":

- Analyze the information in previous steps.
- Invoke `hs:journal` for each selected plan; do not depend on a separate `journal-writer` subagent.
- Journal entries should be concise and focused on the most important events, key changes, impacts, and decisions.
- Keep journal entries in `.hs.json` → `artifacts.journals.directory`.

### Step 3: Ask user to confirm the action before archiving these plans

Ask whether to archive selected plans or all completed plans.
Ask whether to delete permanently or move to `.hs.json` → `artifacts.plans.archiveDirectory`; do not delete without explicit confirmation.

### Step 4: Archive the plans

Start archiving the plans based on the user's choice:

- Move the plans to `.hs.json` → `artifacts.plans.archiveDirectory`.
- Delete plans permanently only after explicit confirmation and after resolving each target below `.hs.json` → `artifacts.plans.directory`.

### Step 5: Ask if user wants to commit the changes

Ask whether the user wants a commit. A commit still requires explicit authorization in the current conversation:

- Stage and commit the changes (use the configured Git workflow)
- Commit and push the changes (use the configured Git workflow)
- Nah, I'll do it later

## Output

After archiving the plans, provide summary:

- Number of plans archived
- Number of plans deleted permanently
- Table of plans that are archived or deleted (title, status, created date, LOC)
- Table of journal entries that are created (title, status, created date, LOC)

## Important Notes

- Only ask questions about genuine decision points
- Sacrifice grammar for concision
- List any unresolved questions at the end
- Ensure token efficiency while maintaining high quality
