---
name: hs:scout
description: "Fast codebase scouting using internal agents by default. External providers require explicit opt-in and consent."
argument-hint: "[search-target] [--external=gemini|opencode]"
metadata:
  author: hs-skills
  version: "1.0.0"
---

# Scout

Fast, token-efficient codebase scouting using parallel agents to find files needed for tasks.

## Arguments

- Default: Scout using built-in agents in parallel (`./references/internal-scouting.md`).
- `--external=<provider>`: Request Gemini or OpenCode. This does not itself grant consent; follow the external consent gate below.

## When to Use

- Beginning work on feature spanning multiple directories
- User mentions needing to "find", "locate", or "search for" files
- Starting debugging session requiring file relationships understanding
- User asks about project structure or where functionality lives
- Before changes that might affect multiple codebase parts

## Quick Start

1. Analyze user prompt to identify search targets
2. Use a wide range of Grep and Glob patterns to find relevant files and estimate scale of the codebase
3. Spawn parallel agents with divided directories
4. Collect results into concise report

## Configuration

Read from the repository-root `.hs.json`:

- `gemini.model` - Gemini model (default: `gemini-3-flash-preview`)
- `skills.scout.external.enabled` - repository-level opt-in; defaults to `false`.
- `skills.scout.external.approvedProviders` - repository allow-list, defaults to empty.

## Workflow

### 1. Analyze Task

- Parse user prompt for search targets
- Identify key directories, patterns, file types, lines of code
- Determine optimal SCALE value of subagents to spawn

### 2. Divide and Conquer

- Split codebase into logical segments per agent
- Assign each agent specific directories or patterns
- Ensure no overlap, maximize coverage

### 3. Track Scout Work

- **Skip if:** Agent count ≤ 2 (overhead exceeds benefit)
- Record progress only when the current runtime supports it; the scoped scout report remains the source of truth.
- Source-of-truth is the scoped scout report, not a platform task API.

### 4. Spawn Parallel Agents

Load appropriate reference based on decision tree:

- **Internal (Default):** `references/internal-scouting.md`.
- **External (exception):** only after all external consent conditions pass; see below.

**Notes:**

- When progress tracking is available, optionally record delegation as in progress.
- Prompt detailed instructions for each subagent with exact directories or files it should read
- Remember that each subagent has less than 200K tokens of context window
- Amount of subagents to-be-spawned depends on the current system resources available and amount of files to be scanned
- Each subagent must return a detailed summary report to a main agent

### 5. Collect Results

**IMPORTANT:** Invoke "/hs:project-organization" skill to organize the outputs.

- Timeout: 3 minutes per agent (skip non-responders)
- When progress tracking is available, optionally record completion; always log timed-out agents in the report.
- Aggregate findings into single report
- List unresolved questions at end

## Report Format

```markdown
# Scout Report

## Relevant Files

- `path/to/file.ts` - Brief description
- ...

## Unresolved Questions

- Any gaps in findings
```

## External Consent Gate

External scouting is **off by default**. Use it only when the user passes
`--external=<provider>` and one of these is true:

1. `.hs.json` sets `skills.scout.external.enabled` to `true` and includes the provider in `approvedProviders`; or
2. The user explicitly consents in the current session after seeing the provider, exact directories/files in scope, and that repository content may leave the machine.

Before running an external CLI, present: provider, model, command scope, target
directories/files, and the fact that source content may be transmitted to that
provider. Do not use an external provider for a broad repository scan. If consent
is absent or ambiguous, use internal scouting.

## References

- `references/internal-scouting.md` - Using Explore subagents
- `references/external-scouting.md` - Using Gemini/OpenCode CLI
- `references/task-management-scouting.md` - legacy task-tracking examples; use runtime-neutral actions instead
