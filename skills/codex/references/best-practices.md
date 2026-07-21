# Codex Best Practices & Avoidances

Distilled field experience using `codex` (GPT-5.5) alongside Claude.

## Best Practices

### 1. Use Codex as a *second opinion*, not a primary worker
Claude (especially Sonnet/Opus 4.x) is faster, has better tool ergonomics inside this harness, and shares conversation state. Codex's value is **independence + careful reading**. Reach for it when those properties matter, not by default.

### 2. Always pass `-C "$PWD"` from scripts
Without it, Codex roots in `~` or the parent process's CWD and reads the wrong files.

### 3. Use `read-only` sandbox for any audit/review
Prevents Codex from "helpfully" rewriting files mid-audit. Switch to `workspace-write` only when you want Codex to produce artifacts (images, generated code).

### 4. Capture last message with `-o <file>`
Then `Read` it from Claude. Keeps Codex output out of stdout noise and gives you a clean artifact to cite.

### 5. Use `--ephemeral` for one-off probes
Especially when role-playing or sending sensitive prompts you don't want logged in `~/.codex/sessions/`.

### 6. Prefer `codex review` over `codex exec` for diff-style audits
`codex review` is purpose-built — it auto-discovers the diff, base, and untracked files. Don't reinvent it with `git diff | codex exec`.

### 7. Constrain output with `--output-schema` when parsing programmatically
Free-form prose is hard to script against. JSON-schema gives you reliable structure.

### 8. Move generated images immediately
`~/.codex/generated_images/` is not a permanent home. See `references/image-generation.md`.

## Role-Play & Persona Prompting

Codex follows persona prompts well for **style / tone / verbosity / commit-message conventions** — this is the documented use case ([AGENTS.md guide](https://developers.openai.com/codex/guides/agents-md)).

For **cross-model mimicry** (asking Codex to "behave like Gemini / Qwen / o3"): field reports say fidelity is surprisingly high on many tasks, but there is **no published study or official docs** corroborating it ([research finding](../../plans/reports/researcher-260518-1213-codex-cli-deep-dive.md#7-persona-prompting--model-mimicry)). Treat as plausible-but-unproven; use for prompt iteration, not production routing.

If you actually need another model's behavior, **orchestrate** instead of mimic:
- [`PAL MCP server`](https://github.com/BeehiveInnovations/pal-mcp-server) lets Codex *call* Gemini, o3, Qwen, and 50+ models as tools

Example persona prompt (style-only, supported):
```bash
codex exec --ephemeral "Adopt the voice of a senior Rust systems engineer: terse,
type-first, no marketing language. Answer: <prompt>"
```

## Platform Gotchas (Sandbox)

- **Windows**: `codex-command-runner.exe` fails with **error 1385** during sandbox setup even for read-only commands ([#16780](https://github.com/openai/codex/issues/16780)). Mapped-drive workspaces error on `CreateProcessWithLogonW` ([#19599](https://github.com/openai/codex/issues/19599)) — use local drive.
- **macOS**: MCP server shell execution is **blocked in `workspace-write`** and `read-only` modes ([#18243](https://github.com/openai/codex/issues/18243)). Workaround is `danger-full-access` (undermines sandbox; track issue).
- **Linux**: Symlinked `.codex/` directories inside writable workspace cause panics ([#20716](https://github.com/openai/codex/issues/20716)). Use direct paths.
- **Approval-policy bug**: `workspace-write` + config override silently reverts to `on-failure` ([#11885](https://github.com/openai/codex/issues/11885)). Pass `--sandbox workspace-write --approval-policy on-failure` directly on CLI as the safe workaround.

## AGENTS.md (Open Standard)

[AGENTS.md is an open standard](https://agents.md/) — Codex, Cursor, Aider, GitHub Copilot, and Gemini CLI all read it. If your repo has `AGENTS.md` at root, Codex picks it up automatically (no `--config` needed).

Cascading: project root → current dir; closest file wins. Priority: `AGENTS.override.md` (non-additive replace) > `AGENTS.md` > `config.toml` fallback. Default size cap: 32 KiB (configurable via `project_doc_max_bytes`).

High-leverage sections per [community guides](https://thepromptshelf.dev/blog/agents-md-codex-setup-guide-2026/):
- **Overview** — domain, stack, team norms
- **Test commands** — exact commands Codex runs to validate "done" (e.g. `npm test`, `pytest`)
- **Review guidelines** — what to flag
- **Restrictions** — frameworks to avoid, paths to exclude
- **Persona** — style, verbosity, commit conventions

If your project already has `CLAUDE.md`, consider also writing `AGENTS.md` (one file → all non-Anthropic tools).

## Comparison Snapshot (Codex vs Claude Code)

| | Codex | Claude Code |
|--|-------|-------------|
| SWE-bench Verified | mid | 80.9% (best) |
| Terminal-Bench 2.0 | 77.3% | — |
| Tokens for equivalent task | **~4× fewer** | baseline |
| Sandbox | Aggressive read-only/ws-write | Trust-based |
| Open source | Yes (Rust) | No |
| Config inheritance | AGENTS.md (multi-tool) | CLAUDE.md (Anthropic only) |

([sources](../../plans/reports/researcher-260518-1213-codex-cli-deep-dive.md#10-competitive-positioning-vs-claude-code-aider-cursor))

**Practical rule**: Claude (Opus) for complex multi-component logic. Codex for contained features, careful audits, image gen.

## Avoidances

### Don't call bare `codex` in scripts
That opens the TUI and hangs the script. Always use `codex exec` or `codex review`.

### Don't use `--dangerously-bypass-approvals-and-sandbox`
…unless the parent process is already externally sandboxed (CI container, ephemeral VM) AND user authorized it. Otherwise sandbox-write is sufficient.

### Don't pipe massive diffs via stdin
For diffs >2000 lines, use `codex review --base <branch>` and let Codex stream it. Stdin pipes >100KB get slow and sometimes truncated.

### Don't ignore Codex hedging
When Codex says "this *might* fail if…" — that's usually a real edge case it spotted but isn't 100% sure on. Re-prompt: "Trace exactly when X would fail. Show the code path."

### Don't double-load AGENTS.md instructions
Codex auto-loads `~/.codex/AGENTS.md`. Don't paste those rules into the prompt.

### Don't run Codex on directories outside what user asked
`-C` honors what you give it, but `--add-dir` extends write scope. Be conservative.

### Don't trust Codex with destructive ops
`rm -rf`, force-push, drop-table — even if Codex proposes them. Always surface to user before allowing.

### Don't conflate Codex models
- **GPT-5.5** = text/code (default model when you call `codex exec`)
- **GPT-5.4 Image 2** = image generation (auto-routed when prompt clearly asks for image; subscription auth only)
- Override with `-m <model>` only when needed.

## Cost / Latency Profile

| Op | Approx latency | Subscription | API-key |
|----|---------------|--------------|---------|
| Quick `exec` text prompt | 5-15s | counts vs window | per-token |
| `review --base main` (mid PR) | 30-90s | counts vs window | per-token |
| Plan audit (5 files) | 60-180s | counts vs window | per-token |
| Image generation (1 image) | 15-40s | counts ~3-5× text rate | per-token (image rates) |

### Dual-Window Rate Limits (Subscription)

Codex enforces **two windows simultaneously** — both must have budget or you're blocked ([source](https://community.openai.com/t/tips-and-tricks-for-using-codex/1373143)):

1. **5-hour window** (per-session burst limit)
2. **Weekly window** (cumulative limit)

Tiers (May 2026): Plus 5×, Pro 10×, Pro-20× 20×. Check usage at `chatgpt.com/codex/settings/usage` or run `/status` in interactive CLI.

**Workflow implication**: don't burn budget on trivial Codex calls. Reserve for audits, image gen, second-opinion review.

### When To Fork A Session

When Codex starts repeating mistakes or losing track: **fork, don't wrestle** ([community wisdom](https://community.openai.com/t/tips-and-tricks-for-using-codex/1373143)). Run `codex fork --last` or start fresh with `--ephemeral`. Cheaper than corrective prompts.

## Verification Checklist Before Calling Codex

- [ ] CWD is the project root (or pass `-C`)
- [ ] Auth mode confirmed (subscription preferred for images)
- [ ] Sandbox mode matches intent (read-only for audit, workspace-write for generation)
- [ ] Output destination decided (`-o` file vs stdout vs stream)
- [ ] No secrets in prompt or attached files
- [ ] User authorized the call (esp. for `workspace-write` or non-trivial cost)
