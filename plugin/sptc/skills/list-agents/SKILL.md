---
name: list-agents
description: |
  List SPT agents — ready, live, and Psyche processes.
allowed-tools: [Bash]
---

# /sptc:list-agents

> **Skeleton — thin by design.** Operative instructions for this skill are delivered by the
> `sptc` adapter at invocation time (UserPromptSubmit injection from the adapter `[strings]`;
> see `docs/adr/0001-distribution-splits-by-volatility.md`). This SKILL.md stays a stub.
>
> **Operative.** The UPS hook detects `/sptc:list-agents` and injects the body from
> `adapter/strings/skills/list-agents.md` (UPS-fires-on-slash confirmed, ADR-0002; file-backed
> `[strings]` shipped, F-003). If injection ever no-ops (spt absent / adapter unregistered), this
> stub is the floor. (Core roster only — the legacy `--psyches` live-layer view is not in core spt.)

Lists agents/endpoints. Maps to `spt endpoint list`.
