---
name: live
description: |
  Run a live agent session. For past sessions, restores a summarized context.

  EXPLICIT START phrases (route to /spt:live <id>):
  - "live as"
  - "start live"
  - "go live"
  - "start a live agent"

  AUTO-RESUME phrases (route to /spt:live --auto, resumes most-recently-active live agent):
  - continue live work
  - resume live work
  - continue live agent
  - resume live agent
  - live agent continue
  - live agent resume
  - live work continue
  - live work resume

  Does NOT route here (too ambiguous — require BOTH "live" AND ("agent" or "work")):
  - "keep going"
  - "resume work"
  - "continue" (bare)
argument-hint: "[<id>] [--auto]"
allowed-tools: [Monitor, Read]
---

# /sptc:live

> **Skeleton — thin by design.** Operative instructions for this skill are delivered by the
> `sptc` adapter at invocation time. Look out for the UserPromptSubmit additionalContext.
>
> **Operative.** If injection ever no-ops (spt absent / adapter unregistered), check
> SPT's installation status using the skill `sptc:setup`. Otherwise, avoid additional steps.

Upgrades THIS session to a LiveAgent (Psyche-backed).
