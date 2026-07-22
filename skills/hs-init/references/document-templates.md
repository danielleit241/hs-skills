# Project Map Document Templates

Use these skeletons only for documents selected by the workflow. Follow `project-map-best-practices.md` for inclusion, exclusion, and evidence rules. Omit unsupported or empty sections.

## `CLAUDE.md` / `AGENTS.md`

```markdown
# Project Name

## Purpose
## Navigation
## Common Commands
## Project Constraints
```

## `system-architecture.md`

```markdown
# System Architecture

## Scope and Boundaries
## Components
## Key Flows
## Integrations and Deployment
```

## `code-standards.md`

```markdown
# Code Standards

## Tooling and Validation
## Layout and Naming
## Testing and Error Handling
## Configuration and Dependencies
```

## `project-overview-prd.md`

```markdown
# Project Overview

## Purpose and Scope
## Users and Domain
## Workflows
## Constraints and Open Questions
```

## Evidence Checklist

Inspect the smallest useful set of sources first:

- Root README and existing project documentation
- Package manifests, lockfiles, and build configuration
- Application entry points and top-level module directories
- Tests and fixtures
- CI/CD, deployment, container, and environment configuration
- Existing `CLAUDE.md`, `AGENTS.md`, and root-level project documents

Cross-check names and paths before recording them. Prefer current source and configuration over stale prose when they conflict, and call out the conflict for maintainers.

## Research Notes

When a document needs to state a project practice, record it as one of:

- **Project standard**: explicitly required by repository documentation or configuration.
- **Observed convention**: repeated in current code, but not necessarily enforced.
- **Recommended practice**: supported by an authoritative source and relevant to this project.
- **Open question**: plausible but not verified; do not turn it into guidance.

Do not use generic industry advice to fill gaps. Research the specific language, framework, tool, or standard involved, and prefer primary documentation over secondary summaries. The research guides the document structure; it does not require a generic best-practice section in every generated file.
