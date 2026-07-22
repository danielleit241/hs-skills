---
name: hs:init
description: "Create or refresh a concise project map for AI-assisted development. Use when a project needs an AI entry point, architecture overview, coding conventions, product/domain context, or a synchronized set of project orientation documents."
argument-hint: "[project-path]"
metadata:
  author: hs-skills
  version: "1.0.0"
---

# Init - Project Map

Create a compact, evidence-based map of an existing project so an AI agent can understand context and navigate the codebase quickly.

## Principle

Produce a map, not a rulebook. Describe the current project as observed; do not invent mandatory policies, prescribe implementation details, or turn preferences into hard rules.

## Workflow

1. Inspect the repository structure, entry points, manifests, configuration, tests, deployment files, and existing documentation.
2. Identify the project purpose, runtime boundaries, major components, data or request flow, development conventions, and important navigation paths.
3. Read existing `CLAUDE.md`, `AGENTS.md`, and target documents before changing them. Preserve useful project-specific context.
4. Read `references/project-map-best-practices.md` before drafting. Use repository evidence to describe the current state and its research-backed include/exclude guidance to keep each document focused. Research stack-specific gaps only from authoritative sources; add a source to a generated document only when it supports useful project-specific guidance.
5. Create or update only the orientation documents that already exist, the user explicitly requests, or repository evidence shows are needed:
   - `CLAUDE.md` or `AGENTS.md`: an AI entry point with repository orientation and links to deeper documentation. Update both only when both exist or both audiences need distinct guidance.
   - `system-architecture.md`: current architecture, boundaries, integrations, and important flows.
   - `code-standards.md`: observed conventions for naming, testing, errors, tooling, and validation.
   - `project-overview-prd.md`: product goal, users, domain concepts, workflows, and business context.
6. Link documents from applicable entry points where useful, remove stale claims, and keep each document short enough to scan.
7. Report unknowns explicitly instead of guessing. Do not modify application code unless the user separately requests it.

## Update Policy

- Refresh the map when architecture, product scope, tooling, or conventions change significantly.
- Prefer small targeted updates over rewriting accurate sections.
- Separate observed facts, inferred relationships, and unresolved questions.
- Apply the reference's research-backed inclusion and exclusion guidance. Do not add generic best-practice sections or unverified preferences to the project map.
- Treat these documents as orientation material; implementation plans and repository-specific rules remain authoritative elsewhere.

## Quality Check

- Confirm every claim is supported by current repository evidence or clearly marked as unresolved.
- Confirm paths, commands, component names, and integrations still exist.
- Confirm applicable entry points guide navigation without duplicating large reference documents.
- Confirm each created or updated document is justified by repository evidence or an explicit user request, remains concise, and has a distinct purpose.

Read `references/project-map-best-practices.md` before drafting and `references/document-templates.md` for the document skeletons and evidence checklist.
