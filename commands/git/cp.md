---
description: Push an explicitly named, already-created commit after confirmation.
---

Push only after the user explicitly requests a remote push in the current conversation.

1. Confirm the target remote, branch, and commit hash with the user or the immediate task context.
2. Verify the commit contains only approved paths and does not contain credentials, local configuration, generated artifacts, or unrelated work.
3. Push only the confirmed branch/commit to the confirmed remote.
4. Report the remote, branch, commit hash, and push result.

Do not stage or create commits in this command. Use `/git:cm` first when a commit is needed.
