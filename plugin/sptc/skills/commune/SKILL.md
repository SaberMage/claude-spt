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
> **Operative.** The UPS hook detects `/sptc:commune` and injects the body from
> `adapter/strings/skills/commune.md` (UPS-fires-on-slash confirmed, ADR-0002; file-backed
> `[strings]` shipped, F-003). If injection ever no-ops (spt absent / adapter unregistered), this
> stub is the floor.

Pushes a context delta to the Psyche via a file-drop (`<id>-commune.md` into the adapter's
`[session].commune_dir`); the daemon ingests it. Live agents only (a Psyche must exist).
