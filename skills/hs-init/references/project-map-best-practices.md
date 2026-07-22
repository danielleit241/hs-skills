# Project Map Best Practices

Use this guide to decide what belongs in each generated document. The project map explains the current project; it does not become an implementation specification or a policy manual.

## `CLAUDE.md` and `AGENTS.md`

**Include:** a short project purpose, the most useful setup/test/validation commands, key directories, navigation links, and only agent-relevant constraints that are already documented by the project. Keep shared facts aligned across both files; add tool-specific instructions only to the relevant file.

**Exclude:** long architecture narratives, product requirements, duplicated configuration, session notes, generated state, and rules that are not evidenced by the repository. Move detail into the three root documents and link to it.

**Why:** `CLAUDE.md` supplies persistent project context and shorter files improve adherence. `AGENTS.md` is a project-level agent guide that commonly covers overview, commands, style, testing, and security; use nested files only for genuinely scoped subprojects.

Sources: [Claude Code memory](https://code.claude.com/docs/en/memory), [AGENTS.md](https://agents.md/).

## `system-architecture.md`

**Include:** system scope, people or external systems, runtime containers, data stores, major integrations, key data/request/event flows, and deployment topology when evidenced. Add a context or container diagram only when it clarifies the relationships; use component detail only when it adds value.

**Exclude:** class-level implementation detail, speculative target architecture, diagrams with no stated audience or purpose, and duplicate module inventories that code navigation already provides.

**Why:** C4 recommends a hierarchy of context, container, component, and code views, but states that context and container views are sufficient for most teams.

Source: [C4 model diagrams](https://c4model.com/diagrams).

## `code-standards.md`

**Include:** languages and tooling, commands that validate the project, explicit repository standards, and concise observed conventions for layout, naming, formatting, testing, error handling, configuration, logging, and dependencies. Separate `Project standard` from `Observed convention` and link to the source configuration or example.

**Exclude:** generic language tutorials, preferences without evidence, copied linter or formatter settings, and new rules introduced solely by the document. Do not prescribe a style when the repository has no stable pattern.

**Why:** technical guidance is most useful when it is clear, consistent, audience-focused, and grounded in the project rather than broad prose.

Source: [Google developer documentation style guide](https://developers.google.com/style).

## `project-overview-prd.md`

**Include:** product purpose, problem and business context, users or actors, domain vocabulary, current capabilities and workflows, confirmed scope, out-of-scope areas, assumptions, and open questions. Link authoritative product, issue-tracker, or customer sources when available.

**Exclude:** unverified user personas, fabricated requirements or success metrics, technical design decisions, implementation task breakdowns, and unsupported roadmap commitments.

**Why:** an effective PRD provides shared context and just-enough detail, while keeping assumptions, questions, and scope boundaries explicit and evolving with the product.

Source: [Atlassian PRD guidance](https://www.atlassian.com/agile/product-management/requirements/).
