---
name: commune
description: |
  Push a context update to your Psyche so it can brief a resume across a reset. Use when the
  user says "commune", "update psyche", or wants to brief their Psyche before a /clear or compact.
  Live agents only.
allowed-tools: [Bash, Write]
---

# /sptc:commune

> **Skeleton — thin by design.** Operative instructions for this skill are delivered by the
> `sptc` adapter at invocation time. Look out for the UserPromptSubmit additionalContext.
>
> **Operative.** If injection ever no-ops (spt absent / adapter unregistered), check
> SPT's installation status using the skill `sptc:setup`. Otherwise, avoid additional steps.

Drops a context delta for the Psyche to absorb (a file the daemon ingests).
