---
name: ready
description: |
  Make this Claude Code session reachable for inter-agent messages (register a perch and
  listen). Use when the user says "listen as", "ready as", or wants to receive messages from
  other agents.
argument-hint: "[<id>]"
allowed-tools: [Bash, Read, Monitor]
---

# /sptc:ready

> **Skeleton — thin by design.** Operative instructions for this skill are delivered by the
> `sptc` adapter at invocation time. Look out for the UserPromptSubmit additionalContext.
>
> **Operative.** If injection ever no-ops (spt absent / adapter unregistered), check
> SPT's installation status using the skill `sptc:setup`. Otherwise, avoid additional steps.

Registers a perch and listens, so other agents can reach this session.
