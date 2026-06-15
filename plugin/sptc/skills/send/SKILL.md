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
> **Operative.** The UPS hook detects `/sptc:send` and injects the body from
> `adapter/strings/skills/send.md` (UPS-fires-on-slash confirmed, ADR-0002; file-backed `[strings]`
> shipped, F-003). If injection ever no-ops (spt absent / adapter unregistered), this stub is the floor.

Delivers a message to another agent; supports reply-to and ring/ask.
