# Root-Cause Analysis

Create a short RCA before changing code:

```text
Symptom:
Exact reproduction:
Expected / actual:
Evidence:
Root cause (file:line when available):
Why now:
Blast radius:
```

Use a minimal experiment to disprove each plausible cause. Prefer logs, stack traces, failing assertions, request traces, version history, and direct code paths over intuition. If the original environment is unavailable, state that limitation and use the closest reliable reproduction; do not claim certainty that the evidence cannot support.

Route the work after the RCA:

- **Simple:** one isolated cause and one safe repair path.
- **Moderate:** multiple files, contract implications, or unclear dependencies; track diagnosis, repair, and verification separately.
- **Complex:** security, data, concurrency, distributed systems, migration, or broad public-contract risk; use `--review` and obtain approval before repair.
- **Parallel:** separate RCAs only when failures are independently reproducible and do not share state.
