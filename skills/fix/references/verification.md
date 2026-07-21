# Verification and Prevention

Verify in this order:

1. Re-run the exact pre-fix reproduction.
2. Run the focused regression test or add one when practical.
3. Check callers, neighboring error paths, and public contracts in the blast radius.
4. Run relevant lint, type, build, and test commands in proportion to risk.
5. Run code review before finalizing material changes.

Select a prevention measure that addresses the bug class, not merely the one observed instance: a regression test, input validation, invariant, idempotency guard, timeout/retry boundary, alert, or explicit follow-up. Explain the residual risk when no practical prevention measure exists.

Finalization is not verification. After proof is collected, update affected plan status and documentation, offer a focused commit only with authorization, and record a concise journal entry.
