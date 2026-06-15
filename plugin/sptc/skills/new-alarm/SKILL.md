---
name: new-alarm
description: |
  Schedule a one-shot timed alarm delivered as a TIMED PULSE.
argument-hint: "<time_spec> -- <message>"
allowed-tools: [Bash]
---

# /sptc:new-alarm

> **Skeleton — thin by design.** Operative instructions for this skill are delivered by the
> `sptc` adapter at invocation time (UserPromptSubmit injection from the adapter `[strings]`;
> see `docs/adr/0001-distribution-splits-by-volatility.md`). This SKILL.md stays a stub.
>
> **Out of scope for v1 (no core primitive).** spt-core has no user-facing alarm / timed-pulse
> command — the legacy `$LIVE TIMED PULSE` is an owl/Psyche-layer convenience not lifted into core,
> and an adapter cannot add a core feature (adapter = manifest + binary). There is deliberately no
> `[strings.skills].new-alarm` entry; this stub stays inert until spt-core mints a deferred-pulse
> primitive (tracked spt-core parity-gap finding — `docs/SPT-CORE-FINDINGS.md`).

Would schedule a delayed self-notification — pending a core deferred-pulse primitive.
