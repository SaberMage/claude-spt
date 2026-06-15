---
name: whoami
description: |
  Report this session's spt endpoint id — "which agent am I?".
allowed-tools: [Bash]
---

# /sptc:whoami

> **Skeleton — thin by design.** Operative instructions for this skill are delivered by the
> `sptc` adapter at invocation time (UserPromptSubmit injection from the adapter `[strings.skills]`;
> see `docs/adr/0001-distribution-splits-by-volatility.md`). This SKILL.md stays a stub.
>
> **Operative.** The UPS hook detects `/sptc:whoami` and injects the body from
> `adapter/strings/skills/whoami.md` (UPS-fires-on-slash confirmed, ADR-0002; file-backed `[strings]`
> shipped, F-003). If injection ever no-ops (spt absent / adapter unregistered), this stub is the floor.

Resolves the current session to its spt endpoint id (`spt whoami`) so the agent can address
replies and discover its own perch identity.
