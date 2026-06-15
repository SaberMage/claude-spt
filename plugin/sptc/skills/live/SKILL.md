---
name: live
description: |
  Run a live agent session (Self + Psyche companion). For past sessions, restores a summarized context.
argument-hint: "[<id>] [--auto]"
allowed-tools: [Bash]
---

# /sptc:live

> **Skeleton — thin by design.** Operative instructions for this skill are delivered by the
> `sptc` adapter at invocation time (UserPromptSubmit injection from the adapter `[strings]`;
> see `docs/adr/0001-distribution-splits-by-volatility.md`). This SKILL.md stays a stub.
>
> **Not yet operative.** Wiring is held pending spt-core finding **F-001** (the injection
> contract — `docs/SPT-CORE-FINDINGS.md`) and the M12 file-backed `[strings]` dependency.

Runs a live agent (Self) with its Psyche companion. Maps to spt-hosted bringup + the harness-hosted listen loop.
