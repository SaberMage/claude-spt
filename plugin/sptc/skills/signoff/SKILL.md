---
name: signoff
description: |
  Graceful live-agent shutdown with a final context summary.
allowed-tools: [Bash]
---

# /sptc:signoff

> **Skeleton — thin by design.** Operative instructions for this skill are delivered by the
> `sptc` adapter at invocation time (UserPromptSubmit injection from the adapter `[strings]`;
> see `docs/adr/0001-distribution-splits-by-volatility.md`). This SKILL.md stays a stub.
>
> **Not yet operative.** Wiring is held pending spt-core finding **F-001** (the injection
> contract — `docs/SPT-CORE-FINDINGS.md`) and the M12 file-backed `[strings]` dependency.

Cleanly ends a live session, writing a final summary consumed at teardown.
