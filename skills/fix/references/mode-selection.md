# Mode Selection

Choose the least permissive mode that still fits the evidence and risk.

| Mode | Use when | Do not use when |
| --- | --- | --- |
| `--auto` | The failure is reproducible, scope is low/moderate risk, and verification is straightforward. | The change affects money, authorization, data integrity, public contracts, or production remediation. |
| `--review` | A human must approve diagnosis, repair, and verification separately. | The user explicitly delegates low-risk work and no material risk is present. |
| `--fast` | A deterministic lint/type/build failure has an isolated, low-risk cause. | The source, reproduction, or blast radius is uncertain. |
| `--parallel` | Two or more failures have separate touchpoints and file ownership. | Failures share state, contracts, migrations, or a likely common root cause. |

Escalate to `--review` when new evidence expands blast radius or changes the risk classification. Never let a mode bypass the root-cause or exact-reproduction gates.
