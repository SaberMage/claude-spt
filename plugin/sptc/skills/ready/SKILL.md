---
name: ready
description: |
  Enable inter-agent messaging for the current session.
argument-hint: "[<id>]"
allowed-tools: [Bash]
---

# /sptc:ready

> **Skeleton — thin by design.** Operative instructions for this skill are delivered by the
> `sptc` adapter at invocation time (UserPromptSubmit injection from the adapter `[strings]`;
> see `docs/adr/0001-distribution-splits-by-volatility.md`). This SKILL.md stays a stub.
>
> **Not yet operative.** Wiring is held pending spt-core finding **F-001** (the injection
> contract — `docs/SPT-CORE-FINDINGS.md`) and the M12 file-backed `[strings]` dependency.

Registers a perch so this session can receive inter-agent messages.
