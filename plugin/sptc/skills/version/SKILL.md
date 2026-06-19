---
name: version
description: |
  Report the spt-core-tracked adapter version (the version-of-truth, not the marketplace plugin
  version). Use when the user asks the spt or adapter version, or runs /sptc:version.
allowed-tools: [Bash]
---

# /sptc:version

> **Skeleton — thin by design.** Operative instructions for this skill are delivered by the
> `sptc` adapter at invocation time. Look out for the UserPromptSubmit additionalContext.
>
> **Operative.** If injection ever no-ops (spt absent / adapter unregistered), check
> SPT's installation status using the skill `sptc:setup`. Otherwise, avoid additional steps.

Reports the version-of-truth: the spt-core-tracked binary + adapter manifest.
