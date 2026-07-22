# External Scouting with Gemini/OpenCode

Use external agentic tools only after the `External Consent Gate` in `../SKILL.md`
passes. These tools may transmit repository content to a third-party provider.

## Consent Record (required)

Before selecting a tool, record in the scout report: provider, model, exact paths,
whether repository configuration approved it, or the user's current-session consent.
If this record cannot be made, stop and use internal scouting.

## Tool Selection

```
SCALE <= 3  → gemini CLI
SCALE 4-5   → opencode CLI
SCALE >= 6  → Use internal scouting instead
```

## Configuration

Read from the repository-root `.hs.json`:

```json
{
  "gemini": {
    "model": "gemini-3-flash-preview"
  }
}
```

Default model: `gemini-3-flash-preview`

## Gemini CLI (SCALE <= 3)

### Command

```bash
timeout 120 gemini -y -m <model> --prompt "[prompt]" 2>&1
```

### Example

```bash
timeout 120 gemini -y -m gemini-3-flash-preview --prompt "Search src/ for authentication files. List paths with brief descriptions." 2>&1
```

## OpenCode CLI (SCALE 4-5)

### Command

```bash
opencode run "[prompt]" --model opencode/grok-code
```

### Example

```bash
opencode run "Find all payment-related files in lib/ and api/" --model opencode/grok-code
```

## Installation Check

Before using, verify tools installed:

```bash
which gemini
which opencode
```

If not installed, ask user:

1. **Yes** - Provide installation instructions (may need manual auth steps)
2. **No** - Fall back to Explore subagents (`internal-scouting.md`)

## Runtime Adapter

After the consent gate passes, delegate bounded external commands when delegation is available. Otherwise run only the same approved, bounded command sequentially:

```
Delegate a consented Gemini query limited to `[approved paths]`.
```

Do not fan out beyond the consented directories/files.

## Prompt Guidelines

- Be specific about directories to search
- Request file paths with descriptions
- Set clear scope boundaries
- Ask for patterns/relationships if relevant

## Example Workflow

User: "Find database migration files"

After the consent gate passes, run bounded external scopes through the platform adapter:

```
Delegate a search of approved `db/` and `migrations/` paths for migration files.
Delegate a search of approved `lib/` and `src/` paths for database schema files.
Delegate a search of approved `config/` paths for database configuration.
```

## Reading File Content

When needing to read file content, use chunking to stay within context limits (<150K tokens safe zone).

### Step 1: Get Line Counts

```bash
wc -l path/to/file1.ts path/to/file2.ts path/to/file3.ts
```

### Step 2: Calculate Chunks

- **Target:** ~500 lines per chunk (safe for most files)
- **Max files per agent:** 3-5 small files OR 1 large file chunked

**Chunking formula:**

```
chunks = ceil(total_lines / 500)
lines_per_chunk = ceil(total_lines / chunks)
```

### Step 3: Read Locally Through the Runtime Adapter

**Small files (<500 lines each):**

```
Delegate reading of the approved small files and require a relevant-context report.
```

**Large file (>500 lines) - use sed for ranges:**

```
Delegate reading of the approved line range and require a relevant-context report.
```

### Chunking Decision Tree

```
File < 500 lines     → Read entire file
File 500-1500 lines  → Split into 2-3 chunks
File > 1500 lines    → Split into ceil(lines/500) chunks
```

Spawn all in single message for parallel execution.

## Timeout and Error Handling

- Wrap all gemini calls: `timeout 120 gemini -y -m <model> --prompt "[prompt]" 2>&1`
- Check exit code: non-zero means failure
- Check output for error markers: `GaxiosError`, `RESOURCE_EXHAUSTED`, `MODEL_CAPACITY_EXHAUSTED`, `PERMISSION_DENIED`, `UNAUTHENTICATED`
- On failure: skip that agent's result, do NOT retry
- On persistent failures (2+ agents fail): fall back to internal scouting
- **Model fallback**: If `gemini-3-flash-preview` fails with 429, try `gemini-2.5-flash` before giving up
