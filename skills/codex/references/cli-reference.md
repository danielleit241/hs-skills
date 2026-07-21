# Codex CLI Reference

`codex-cli 0.129.0` (verify with `codex --version`).

## Subcommands

| Cmd | Purpose |
|-----|---------|
| `codex exec` | Non-interactive prompt (the workhorse — use this from scripts) |
| `codex review` | Non-interactive code review against branch/commit/uncommitted |
| `codex mcp-server` | Expose Codex as an MCP server (stdio) |
| `codex mcp` | Manage external MCP servers Codex can call |
| `codex apply` | Apply Codex's last produced diff via `git apply` |
| `codex resume` | Resume a previous interactive session |
| `codex login` / `logout` | Manage subscription/API auth |

## `codex exec` Key Flags

| Flag | Use |
|------|-----|
| `-C, --cd <DIR>` | **Always set** to project root |
| `--full-auto` | Shorthand for `--sandbox workspace-write --approval-policy on-failure`. Practical default for automation ([docs](https://developers.openai.com/codex/agent-approvals-security)) |
| `--skip-git-repo-check` | Required when CWD is not a git repo |
| `-s, --sandbox <MODE>` | `read-only` \| `workspace-write` (default) \| `danger-full-access` |
| `-m, --model <MODEL>` | Override model (default GPT-5.5) |
| `-i, --image <FILE>` | Attach image(s) to prompt (multimodal input) |
| `-o, --output-last-message <FILE>` | Write final agent message to file |
| `--json` | Emit JSONL events on stdout |
| `--output-schema <FILE>` | Constrain final response to a JSON schema |
| `--ephemeral` | Don't persist session to `~/.codex/sessions/` |
| `--add-dir <DIR>` | Extra writable dirs |
| `--skip-git-repo-check` | Allow non-git directories |
| `--ignore-user-config` | Skip `~/.codex/config.toml` |
| `--ignore-rules` | Skip user/project `.rules` files |
| `-c key=value` | Override any config value (TOML-parsed) |

## `codex review` Flags

| Flag | Use |
|------|-----|
| `--base <BRANCH>` | Review changes vs base branch (most common) |
| `--commit <SHA>` | Review one commit |
| `--uncommitted` | Review staged + unstaged + untracked |
| `--title <TITLE>` | Display title in review summary |
| `[PROMPT]` | Custom focus instructions (optional) |

## Config Overrides (`-c`)

```bash
# Switch model
codex exec -c model='"gpt-5.5-thinking-high"' "..."

# Bump reasoning effort
codex exec -c model_reasoning_effort='"high"' "..."

# Allow network in workspace-write sandbox (blocked by default)
codex exec -c 'sandbox_workspace_write.network_access=true' "..."
```

**Network is blocked by default** in `read-only` and `workspace-write` — important when Codex needs `npm install`, `curl`, `git fetch`, etc. ([source](https://developers.openai.com/codex/sandboxing)).

## Auth Modes

- **Subscription auth** (`codex login` → ChatGPT account): credentials in `~/.codex/auth.json`. Plus/Pro/Pro-20× tiers give 5×/10×/20× usage — **dual-window throttling** (5-hour + weekly, both must have budget; check via `/status` in CLI or `chatgpt.com/codex/settings/usage`).
- **API key auth** (`OPENAI_API_KEY` env or `--api-key`): metered per-token, no rate-limit windows.
- **Multi-account**: new `~/.codex/accounts.json` mechanism; community tools: [codex-multi-auth](https://github.com/ndycode/codex-multi-auth), [codex-switcher](https://github.com/Lampese/codex-switcher).
- **CI/CD**: use [`openai/codex-action`](https://github.com/openai/codex-action) — don't embed raw tokens in pipeline logs.

Check active mode:
```bash
cat ~/.codex/auth.json | jq -r '.tokens.access_token // "api-key-mode"' | head -c 20
```

## JSONL Event Stream (when `--json`)

Event types: `turn.started`, `item.completed`, `turn.completed`, `turn.failed`, `agent_message`, `agent_reasoning`, `tool_call`, `tool_result`, `error`.

Final agent message:
```bash
codex exec --json "..." | jq -r 'select(.type=="agent_message") | .message'
```

Token spend per turn (useful for guarding CI against runaway cost):
```bash
codex exec --json "..." 2>/dev/null \
  | jq -r 'select(.type=="turn.completed") | "Tokens: \(.usage.input_tokens + .usage.output_tokens)"'
```
([source](https://developers.openai.com/codex/noninteractive))

## Exit Codes

- `0` — success
- `1` — runtime error (auth, network, sandbox denial)
- `2` — invalid args

Always `set -e` in scripts and inspect `$?` rather than parsing stdout for errors.
