---
name: live
description: |
  Run a live agent session (Self + Psyche companion). For past sessions, restores a summarized context.
argument-hint: "[<id>] [--auto]"
allowed-tools: [Bash]
---

# /sptc:live

> **Skeleton — thin by design.** Operative instructions for this skill are delivered by the
> `sptc` adapter at invocation time (UserPromptSubmit injection from the adapter `[strings]`;
> see `docs/adr/0001-distribution-splits-by-volatility.md`). This SKILL.md stays a stub.
>
> **Held (body pending).** The injection mechanism is operative, but the `live` body is not yet
> authored: `/sptc:live` upgrades THIS session to a LiveAgent via a `claude-spt:live` profile that
> overlays `[session.psyche_init]`. Held pending doyle confirming (in spt-core code) that the
> seed-time profile PROPAGATES to drive the daemon's `psyche_init` spawn (`SKILLS-SLICE-PLAN.md`).
> Until the body lands this stub is the floor.

Upgrades this session to a live agent (Psyche-backed) — distinct from `spt endpoint run` (which
spawns a separate broker-PTY session). Body lands on the psyche_init propagation confirmation.
