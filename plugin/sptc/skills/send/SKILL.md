---
name: send
description: |
  Send a message to another SPT agent.
argument-hint: "<target> [--reply-to <sender>]"
allowed-tools: [Bash]
---

# /sptc:send

> **Skeleton — thin by design.** Operative instructions for this skill are delivered by the
> `sptc` adapter at invocation time (UserPromptSubmit injection from the adapter `[strings]`;
> see `docs/adr/0001-distribution-splits-by-volatility.md`). This SKILL.md stays a stub.
>
> **Not yet operative.** Wiring is held pending spt-core finding **F-001** (the injection
> contract — `docs/SPT-CORE-FINDINGS.md`) and the M12 file-backed `[strings]` dependency.

Delivers a message to another agent; supports reply-to and ring/ask.
