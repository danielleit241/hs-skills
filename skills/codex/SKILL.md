---
name: hs:codex
description: "Use OpenAI Codex CLI (GPT-5.5 + gpt-image-2) programmatically: second-opinion code review, GitHub PR audit, plan/spec auditing, edge-case discovery, style/persona prompting, and subscription-billed image generation for visual assets, decorations, infographics, banners. Activate whenever the user says 'codex', 'second opinion', 'audit plan', 'review PR with codex', 'generate image', 'create banner/illustration/visual asset', or wants a careful adversarial reader to catch what Claude (especially Opus) might skim past."
license: MIT
argument-hint: "[review-pr|audit-plan|gen-image|exec|role-play] [target]"
metadata:
  author: hs-skills
  version: "1.0.0"
---

# Codex CLI Skill

Use the `codex` CLI (OpenAI GPT-5.5 + GPT-5.4 Image 2) as a complementary tool to Claude. Codex's strengths are **careful file reading**, **edge-case spotting**, **role-play fidelity**, and **unlimited high-quality image generation** under subscription auth.

## When To Use Codex (Decision Tree)

```
User intent
├── "Review/audit my code/PR/diff"        → Codex review  (see references/code-review-workflows.md)
├── "Audit/review my plan or spec"        → Codex plan audit (see references/plan-audit-workflows.md)
├── "Generate an image/banner/illustration/icon/infographic/visual asset" → Codex image gen (see references/image-generation.md)
├── "Get a second opinion from Codex"     → Codex exec one-shot
├── "Pretend to be Gemini/Qwen/o3"        → Codex role-play (see references/best-practices.md)
└── "Just run codex on X programmatically" → Codex exec (see references/cli-reference.md)
```

**Do NOT** use Codex when:

- The task is small, mechanical, or fully solvable by Claude in the current session (waste of latency/credits).
- The user wants a final implementation pushed to disk by Codex — prefer Claude for in-session edits, use Codex for _analysis only_ unless explicitly asked.
- Sensitive data is in the working dir without user clearance (Codex sends content to OpenAI).

## Why Codex Beats Claude For Certain Tasks

| Task                    | Why Codex                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Plan/spec audit         | Codex (GPT-5.5) reads files carefully — catches edge cases Opus skims. Uses ~4× fewer tokens than Claude on equivalent work                                                                                                                                                                                                                                                                                                                                              |
| PR review               | Independent reader, fresh context, no shared bias with the implementing Claude session. Native GitHub integration via `@codex review`                                                                                                                                                                                                                                                                                                                                    |
| Image generation        | `gpt-image-2` ([announced Oct 2025](https://community.openai.com/t/introducing-gpt-image-2-available-today-in-the-api-and-codex/1379479)) via subscription counts toward limits but no per-image dollar charge; iterate fast in terminal. Field reports prefer it over Gemini Nano Banana Pro for mockups/decorations/banners. Invoke via bundled `$imagegen` skill. **Native transparency NOT supported — uses official chroma-key workflow** (see image-generation.md) |
| Style/persona prompting | Persona instructions in AGENTS.md or one-off prompts shift Codex's voice/verbosity reliably. Cross-model mimicry (Codex behaving as Gemini/Qwen/o3) is community-reported but unverified — use for prompt iteration only, not production routing                                                                                                                                                                                                                         |

## Core Invocation Patterns

All Codex calls are **non-interactive** (`codex exec` or `codex review`). NEVER call bare `codex` in a script — it opens the TUI.

### Pattern 1: One-shot prompt

```bash
codex exec -C "$PWD" --skip-git-repo-check </dev/null \
  "Audit ./plans/foo.md for missing edge cases"
```

### Pattern 2: Full-auto write (convenience for automation)

```bash
codex exec --full-auto -C "$PWD" </dev/null "Generate hero.png in ./assets"
# --full-auto == --sandbox workspace-write + --approval-policy on-failure
```

### Pattern 3: Code review against branch

```bash
codex review --base main "Focus on auth and data-loss risks"
```

### Pattern 4: Capture last message only (for piping into Claude)

```bash
codex exec -o /tmp/codex-out.md "Review this diff" -C "$PWD"
```

### Pattern 5: JSON event stream (programmatic parsing)

```bash
codex exec --json "..." | jq -r 'select(.type=="agent_message") | .message'
```

## Critical Defaults & Avoidances

- **Always pass `-C "$PWD"`** when invoking from a script so Codex roots at the right project, not `~/.codex`.
- **Pass `--skip-git-repo-check`** when CWD is not a git repo, otherwise Codex aborts with `Not inside a trusted directory`.
- **Redirect stdin** (`</dev/null`) in non-interactive scripts — without it, Codex hangs reading stdin when both arg-prompt and a TTY-less stdin are present.
- **Default sandbox is good** (`workspace-write`). Use `read-only` for pure review/audit. Use `danger-full-access` ONLY when user explicitly authorizes.
- **Network is blocked by default** inside `workspace-write` / `read-only`. Enable per-call: `-c 'sandbox_workspace_write.network_access=true'`.
- **Approval-policy quirk**: setting policy via config can silently revert to `on-failure` (open bug [#11885](https://github.com/openai/codex/issues/11885)). Pass `--approval-policy` directly on the CLI.
- **NEVER use `--dangerously-bypass-approvals-and-sandbox`** unless the parent process is already externally sandboxed and the user asked for it.
- **Prefer `$imagegen` skill invocation for images** — the literal token `$imagegen` in the prompt loads Codex's bundled [official imagegen skill](https://github.com/openai/codex/blob/main/codex-rs/skills/src/assets/samples/imagegen/SKILL.md) (correct model routing, save-path policy, transparency flow). `scripts/codex-generate-image.sh` auto-prepends it.
- **Images land in two places** — `~/.codex/generated_images/<session>/ig_*.png` (built-in tool) OR CWD (if prompt says "Save as X"). `scripts/codex-generate-image.sh` snapshots both.
- **`gpt-image-2` does NOT support native transparent PNG** — official chroma-key workflow: generate on `#00ff00` background then run `scripts/codex-strip-chroma-key.sh`. Only escalate to `gpt-image-1.5 --background transparent` after asking user (upstream rule: never silently downgrade).
- **`gpt-image-2` ignores exact pixel dimensions** — verified empirically (a "256x256" request returned 1254x1254). Resize via ImageMagick if exact dimensions matter.
- **Don't double-instruct**: Codex respects `AGENTS.md` cascading from project root → CWD. Don't repeat global rules in the prompt.
- **Don't pipe huge files**: prefer `-i path` for images; let Codex read text files via its own tools. Stdin >100KB is slow/truncatable.
- **Codex sessions persist** in `~/.codex/sessions/`. Use `--ephemeral` for one-off prompts you don't want logged.
- **Watch the dual-window rate limit** (subscription): 5-hour window AND weekly window both must have budget. Check via `/status`.
- **Platform sandbox gotchas** (see `references/best-practices.md`): Windows error 1385, macOS MCP shell-exec blocked in workspace-write, Linux symlinked `.codex/` panics.

## Workflows

| Task                                                                      | Script                                                 | Reference                             |
| ------------------------------------------------------------------------- | ------------------------------------------------------ | ------------------------------------- |
| Review a GitHub PR with Codex                                             | `scripts/codex-review-pr.sh <pr-number>`               | `references/code-review-workflows.md` |
| Audit a plan file                                                         | `scripts/codex-audit-plan.sh <plan-path>`              | `references/plan-audit-workflows.md`  |
| Generate + relocate image (auto-prepends `$imagegen`)                     | `scripts/codex-generate-image.sh "<prompt>" [out-dir]` | `references/image-generation.md`      |
| Strip chroma-key → transparent PNG (uses upstream `remove_chroma_key.py`) | `scripts/codex-strip-chroma-key.sh <in.png> <out.png>` | `references/image-generation.md`      |
| Persona prompting (style/tone only)                                       | inline `codex exec` with persona prompt                | `references/best-practices.md`        |
| All CLI flags                                                             | —                                                      | `references/cli-reference.md`         |

## Output Handling

After every Codex call:

1. **Read the output** — never assume Codex succeeded silently.
2. **Surface findings to user verbatim** when Codex audits something; do not summarize away edge cases (that defeats the point of asking Codex).
3. **If Codex generated images**, run the post-move logic in `scripts/codex-generate-image.sh` or manually:
   ```bash
   latest_session=$(ls -t ~/.codex/generated_images/ | head -1)
   mv ~/.codex/generated_images/"$latest_session"/* ./assets/ && rm -rf ~/.codex/generated_images/"$latest_session"
   ```
4. **Cite findings** with `file:line` when relaying Codex's review back to user.

## Security Policy

This skill handles: invoking `codex` CLI, parsing its stdout, moving generated images, optionally piping diffs/plans into Codex.

This skill does NOT handle: storing OpenAI API keys (uses existing `~/.codex/auth.json`), modifying Codex config, executing arbitrary user code outside `codex exec`.

Refuse to: bypass sandbox without explicit user authorization, send `.env` or credential files to Codex, run `codex exec` against directories the user didn't ask you to touch.
