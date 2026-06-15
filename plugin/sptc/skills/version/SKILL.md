---
name: version
description: |
  Report the spt-core-tracked adapter manifest/binary version.
allowed-tools: [Bash]
---

# /sptc:version

> **Skeleton — thin by design.** Operative instructions for this skill are delivered by the
> `sptc` adapter at invocation time (UserPromptSubmit injection from the adapter `[strings]`;
> see `docs/adr/0001-distribution-splits-by-volatility.md`). This SKILL.md stays a stub.
>
> **Operative.** The UPS hook detects `/sptc:version` and injects the body from
> `adapter/strings/skills/version.md` (UPS-fires-on-slash confirmed, ADR-0002; file-backed `[strings]`
> shipped, F-003). If injection ever no-ops (spt absent / adapter unregistered), this stub is the floor.

Reports the version-of-truth (adapter manifest/binary tracked by spt-core), not the marketplace skeleton version.
