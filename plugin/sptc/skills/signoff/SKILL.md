---
name: signoff
description: |
  Gracefully shut down this live agent, saving a final context summary. Use when the user
  says "sign off", "graceful stop", or wants to cleanly end a live session.
allowed-tools: [Bash, Write]
---

# /sptc:signoff

> **Skeleton — thin by design.** Operative instructions for this skill are delivered by the
> `sptc` adapter at invocation time. Look out for the UserPromptSubmit additionalContext.
>
> **Operative.** If injection ever no-ops (spt absent / adapter unregistered), check
> SPT's installation status using the skill `sptc:setup`. Otherwise, avoid additional steps.

Cleanly ends this session's endpoint, saving a final summary at teardown.
