# HS Skills

## Introduction

HS Skills is a plugin toolkit for **Claude Code** and **Codex**. It provides reusable workflows and MCP configuration for the full development cycle: understanding a task, planning, implementation, testing, and review. The Claude Code plugin also includes specialist subagents and guard rails.

## Install

Install directly from GitHub—no manual clone is required.

### Claude Code

Run these commands in your Claude Code terminal:

```bash
/plugin marketplace add danielleit241/hs-skills
/plugin install hs-skills@hs-skills
```

In an active Claude Code session, run `/reload-plugins` to load the plugin immediately.

### Codex

Run these commands in your Codex terminal:

```bash
/plugin marketplace add danielleit241/hs-skills
/plugin add hs-skills@hs-skills
```

Codex downloads the marketplace snapshot and installs the `hs-skills` plugin from it. The Codex plugin bundles skills and MCP configuration; use the repository's source installer when you also need repository-local agent or hook configuration.

### Remote PowerShell installer

Use this when you want the repository-local Claude Code and/or Codex configuration, including generated subagent and hook settings. Run it from the root of the target project:

```powershell
irm https://raw.githubusercontent.com/danielleit241/hs-skills/main/install.ps1 | iex
```

To install one target, invoke the downloaded script with `--claude` or `--codex`:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/danielleit241/hs-skills/main/install.ps1))) --codex
```

Replace `codex` with `claude` as needed. The installer downloads the repository to a temporary directory, installs the selected configuration into the current project, and removes the temporary files. It replaces the selected `.claude/` and/or `.codex/` directories.

> Security note: this executes code fetched from GitHub. Review [`install.ps1`](install.ps1) before running it. For production, invoke it with a reviewed release tag or commit using `-Ref`.

## Skills

Skills are reusable workflows that the agent can select when they fit the task. You do not need to memorize their names—describe your goal clearly and the agent can use the relevant workflow.

- **Planning and delivery:** `brainstorm`, `hs-plan`, `cook`, `project-organization`, and `journal`.
- **Engineering:** `backend-development`, `frontend-design`, `databases`, and `ui-styling`.
- **Research and analysis:** `research`, `docs-seeker`, `scout`, `repomix`, `sequential-thinking`, and `xia`.
- **Quality and tools:** `code-review`, `chrome-devtools`, and `codex`.

Each skill is documented in `skills/<skill-name>/SKILL.md`.

## Subagents

When a task benefits from a specialist perspective, the agent can delegate work to focused subagents:

- **Planning:** `planner`, `project-manager`, and `brainstormer`.
- **Research, debugging, and testing:** `researcher`, `debugger`, and `tester`.
- **Product and design:** `fullstack-developer` and `ui-ux-designer`.
- **Quality and delivery:** `code-reviewer`, `docs-manager`, and `git-manager`.

Research, planning, and review roles are configured as read-only where possible. Implementation roles can modify the workspace when needed.

## Hooks

HS Skills includes pre-tool-use guard rails that are enabled by default:

- **Privacy guard:** prevents the agent from reading likely secret files, including `.env` files, credentials, private keys, and certificates.
- **Scout guard:** prevents broad scans of generated or dependency directories and overly broad recursive globs.

The Claude Code plugin activates its hook automatically. In a source-based installation, you can adjust `guardrails.hooks.privacy` and `guardrails.hooks.scout` in [`.hs.json`](.hs.json).

## Why

Good software work often needs more than writing code. A task may need research, architecture checks, an implementation plan, tests, or a risk-focused review first. HS Skills makes those practices easier to apply consistently, without repeatedly rebuilding the same prompts and workflows.

## Out of scope

HS Skills does not replace project architecture, CI, access controls, code review, or human approval. It does not store credentials, grant access to external services, or guarantee that every task can be completed autonomously.

Review changes before merging, keep secrets out of prompts and repositories, and adapt the guard rails to your project's security and engineering requirements.
