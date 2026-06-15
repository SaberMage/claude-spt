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
> **Operative.** The UPS hook detects `/sptc:ready` and injects the body from
> `adapter/strings/skills/ready.md` (UPS-fires-on-slash confirmed, ADR-0002; file-backed `[strings]`
> shipped, F-003). If injection ever no-ops (spt absent / adapter unregistered), this stub is the floor.

Registers a perch so this session can receive inter-agent messages.
