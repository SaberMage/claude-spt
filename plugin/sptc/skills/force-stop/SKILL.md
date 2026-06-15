---
name: force-stop
description: |
  Force-stop an SPT agent — ready or live (with its Psyche).
argument-hint: "<id>"
allowed-tools: [Bash]
---

# /sptc:force-stop

> **Skeleton — thin by design.** Operative instructions for this skill are delivered by the
> `sptc` adapter at invocation time (UserPromptSubmit injection from the adapter `[strings]`;
> see `docs/adr/0001-distribution-splits-by-volatility.md`). This SKILL.md stays a stub.
>
> **Operative.** The UPS hook detects `/sptc:force-stop` and injects the body from
> `adapter/strings/skills/force-stop.md` (UPS-fires-on-slash confirmed, ADR-0002; file-backed
> `[strings]` shipped, F-003). If injection ever no-ops (spt absent / adapter unregistered), this
> stub is the floor.

Tears down an agent's endpoint: graceful `spt endpoint shutdown` (final save + Psyche teardown) or
soft `spt endpoint stop`. No hard/no-grace path in core spt (tracked gap).
