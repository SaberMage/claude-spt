---
name: force-stop
description: |
  Force-stop an SPT agent — a ready agent, or a live agent and its Psyche. Use when the user
  says "stop listening", "kill live agent", "force stop", or "tear down perch". Session-aware: a
  live target tears its Psyche down too.
argument-hint: "[<id>]"
allowed-tools: [Bash]
---

# /sptc:force-stop

> **Skeleton — thin by design.** Operative instructions for this skill are delivered by the
> `sptc` adapter at invocation time. Look out for the UserPromptSubmit additionalContext.
>
> **Operative.** If injection ever no-ops (spt absent / adapter unregistered), check
> SPT's installation status using the skill `sptc:setup`. Otherwise, avoid additional steps.

Tears down an agent's endpoint (graceful shutdown, or a lighter stop).
