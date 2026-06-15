---
name: commune
description: |
  Send a communal context update to your Psyche.
argument-hint: "<<stdin>>"
allowed-tools: [Bash]
---

# /sptc:commune

> **Skeleton — thin by design.** Operative instructions for this skill are delivered by the
> `sptc` adapter at invocation time (UserPromptSubmit injection from the adapter `[strings]`;
> see `docs/adr/0001-distribution-splits-by-volatility.md`). This SKILL.md stays a stub.
>
> **Not yet operative.** Wiring is held pending spt-core finding **F-001** (the injection
> contract — `docs/SPT-CORE-FINDINGS.md`) and the M12 file-backed `[strings]` dependency.

Pushes a context summary to the Psyche so it can produce echo-commune briefs across session boundaries.
