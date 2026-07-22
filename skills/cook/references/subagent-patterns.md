# Specialist Handoff Patterns

Delegate to the named specialist when the current runtime offers delegation.
Otherwise perform the same bounded scope sequentially and report the fallback.
These patterns define role, bounded scope, and expected report.

| Role | Bounded scope | Expected report |
| --- | --- | --- |
| `researcher` | Research one stated topic | Sources, conclusions, uncertainty; ≤150 lines. |
| `scout` | Find files related to one feature | Paths, relationships, unresolved questions. Internal by default. |
| `planner` | Build a plan from supplied evidence | Plan files, dependencies, risks. |
| `ui-ux-designer` | Implement or assess an explicitly assigned UI scope | Changed files or design findings. |
| `tester` | Run a scoped test suite | Command, output summary, failures. |
| `debugger` | Diagnose supplied failures | Root cause, evidence, proposed fix; do not modify without authorization. |
| `code-reviewer` | Review supplied diff/scope | Evidence-backed findings; read-only unless separately authorized. |
| `project-manager` | Synchronize verified plan state | Updated plan status and unresolved mappings. |
| `docs-manager` | Update affected documentation | Changed documents and rationale. |
| `git-manager` | Prepare one focused commit | Only after explicit current-conversation authorization. |
| `fullstack-developer` | Implement one phase with owned files | Changes, tests, handoff notes. |

Every handoff must include the exact scope, file ownership where applicable,
constraints, and the required report. Do not use a handoff to expand authority.
