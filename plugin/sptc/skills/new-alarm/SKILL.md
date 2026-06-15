---
name: new-alarm
description: |
  Schedule a one-shot timed alarm delivered as a TIMED PULSE.
argument-hint: "<time_spec> -- <message>"
allowed-tools: [Bash]
---

# /sptc:new-alarm

> **Skeleton — thin by design.** Operative instructions for this skill are delivered by the
> `sptc` adapter at invocation time (UserPromptSubmit injection from the adapter `[strings]`;
> see `docs/adr/0001-distribution-splits-by-volatility.md`). This SKILL.md stays a stub.
>
> **Not yet operative.** Wiring is held pending spt-core finding **F-001** (the injection
> contract — `docs/SPT-CORE-FINDINGS.md`) and the M12 file-backed `[strings]` dependency.

Schedules a delayed self-notification delivered when the time arrives.
