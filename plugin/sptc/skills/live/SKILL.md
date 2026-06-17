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
> **Operative.** The UPS hook detects `/sptc:live` and injects the body from
> `adapter/strings/skills/live.md` (UPS-fires-on-slash confirmed, ADR-0002; file-backed `[strings]`
> shipped, F-003). If injection ever no-ops (spt absent / adapter unregistered), this stub is the
> floor.

Upgrades THIS session to a LiveAgent (Psyche-backed) — distinct from `spt endpoint run` (which
spawns a separate broker-PTY session). Base `claude-spt` is live-capable (`[session.psyche_init]` in
the base manifest); going live is just the command — a resident Monitor relay running bare
`spt api listen <id>` (no `--adapter`). The live listen path stamps the perch `state=live_agent`, so
the daemon hosts the Psyche; `/sptc:ready` (poll) stays Psyche-less.
