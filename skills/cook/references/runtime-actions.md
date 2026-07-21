# Runtime-Neutral Workflow Actions

Shared workflows describe intent, not a platform-specific tool call. Use these
actions in skill and reference Markdown:

| Action | Meaning |
| --- | --- |
| `ASK_USER` | Request a decision or missing information; do not proceed past a required gate without it. |
| `SPAWN_AGENT(role, scope)` | Delegate a bounded task to the named specialist and collect its report. |
| `TRACK_TASK(state)` | Record progress when the runtime supports task tracking; it is optional operational metadata. |
| `RUN_CHECK(command)` | Execute a scoped verification command and retain the result as evidence. |
| `HAND_OFF(role, context)` | Return findings or verified context to a later, explicitly authorized workflow. |

## Platform adapters

| Action | Claude adapter | Codex adapter |
| --- | --- | --- |
| `ASK_USER` | The platform's question/interaction facility | Ask in the active conversation; use the available structured input facility only when present. |
| `SPAWN_AGENT` | Claude subagent facility | Codex collaboration/subagent facility available in the current runtime. |
| `TRACK_TASK` | Claude task tracking when available | Runtime plan/task tracking when available; otherwise keep a concise in-memory progress summary. |
| `RUN_CHECK` | Shell/tool execution allowed by policy | Shell/tool execution allowed by policy. |

Adapters may name concrete tools in generated platform output. Source workflow
documents must not require a concrete tool name, assume a particular UI, or make
correctness depend on task tracking.

## Authority rules

- `--auto` may continue implementation gates only; it never authorizes a commit,
  push, external provider, destructive action, or disclosure of repository data.
- A commit requires an explicit user request in the current conversation.
- External providers require explicit user consent for the current session, unless
  the repository has an explicit allow-list in `.hs.json`.
