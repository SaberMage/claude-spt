---
name: send
description: |
  Send a message to another SPT agent. Use when the user says "send to", "message",
  "tell <agent>", or wants to reach another agent.
argument-hint: "<target> [--reply-to <sender>]"
allowed-tools: [Bash]
---

# /sptc:send

> **Skeleton — thin by design.** Operative instructions for this skill are delivered by the
> `sptc` adapter at invocation time. Look out for the UserPromptSubmit additionalContext.
>
> **Operative.** If injection ever no-ops (spt absent / adapter unregistered), check
> SPT's installation status using the skill `sptc:setup`. Otherwise, avoid additional steps.

Delivers a message to another agent; supports reply-to.
