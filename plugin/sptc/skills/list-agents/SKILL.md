---
name: list-agents
description: |
  List SPT agents and endpoints reachable from this node. Use when the user says "list agents",
  "who's live", "who's listening", or wants a roster of active perches.
allowed-tools: [Bash]
---

# /sptc:list-agents

> **Skeleton — thin by design.** Operative instructions for this skill are delivered by the
> `sptc` adapter at invocation time. Look out for the UserPromptSubmit additionalContext.
>
> **Operative.** If injection ever no-ops (spt absent / adapter unregistered), check
> SPT's installation status using the skill `sptc:setup`. Otherwise, avoid additional steps.

Shows the roster of spt endpoints, with this session's own pinned distinctly.
