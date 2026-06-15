---
name: setup
description: |
  Install or repair spt-core for this Claude Code session (mid-session installer).
allowed-tools: [Bash]
---

# /sptc:setup

> **Skeleton — thin by design.** Operative instructions for this skill are delivered by the
> `sptc` adapter at invocation time (UserPromptSubmit injection from the adapter `[strings]`;
> see `docs/adr/0001-distribution-splits-by-volatility.md`). This SKILL.md stays a stub.
>
> **Not yet operative.** Wiring is held pending spt-core finding **F-001** (the injection
> contract — `docs/SPT-CORE-FINDINGS.md`) and the M12 file-backed `[strings]` dependency.

Covers the mid-session install gap (ADR-0001): a user who installs the plugin mid-session has not
had a SessionStart bootstrap fire, so `/sptc:setup` runs the same invisible-installer bootstrap to
fetch + verify spt-core on demand.
