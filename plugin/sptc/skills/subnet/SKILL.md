---
name: subnet
description: |
  Manage subnet membership — create, show a pairing code, or join, so agents reach each other across machines.
argument-hint: "[status|create|show-code|join]"
allowed-tools: [Bash]
---

# /sptc:subnet

> **Skeleton — thin by design.** Operative instructions for this skill are delivered by the
> `sptc` adapter at invocation time (UserPromptSubmit injection from the adapter `[strings]`;
> see `docs/adr/0001-distribution-splits-by-volatility.md`). This SKILL.md stays a stub.
>
> **Operative.** The UPS hook detects `/sptc:subnet` and injects the body from
> `adapter/strings/skills/subnet.md` (UPS-fires-on-slash confirmed, ADR-0002; file-backed
> `[strings]` shipped, F-003). If injection ever no-ops (spt absent / adapter unregistered), this
> stub is the floor.

Manages this machine's **subnet** — the private group of paired machines whose agents reach each
other across nodes. Wraps `spt subnet {status,create,show-code,join,…}`: create a subnet, show a
pairing code to invite a machine, or join an existing one. Cross-machine `/sptc:send` + live agents
depend on it.
