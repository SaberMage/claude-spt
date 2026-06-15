---
name: whoami
description: |
  Report this session's spt endpoint id — "which agent am I?".
allowed-tools: [Bash]
---

# /sptc:whoami

> **Skeleton — thin by design.** Operative instructions for this skill are delivered by the
> `sptc` adapter at invocation time (UserPromptSubmit injection from the adapter `[strings]`;
> see `docs/adr/0001-distribution-splits-by-volatility.md`). This SKILL.md stays a stub.
>
> **Not yet operative.** Wiring is held pending spt-core finding **F-001** (the injection
> contract — `docs/SPT-CORE-FINDINGS.md`) and the M12 file-backed `[strings]` dependency.

Resolves the current session to its spt endpoint id (`spt whoami`) so the agent can address
replies and discover its own perch identity.
