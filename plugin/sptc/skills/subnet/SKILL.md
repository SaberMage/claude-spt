---
name: subnet
description: |
  Manage subnet membership — create a subnet, show a pairing code to invite a machine, or join
  an existing one. Use when the user wants to pair machines, set up a subnet, or reach agents
  across machines. Cross-machine /sptc:send and live agents depend on it.
argument-hint: "[status|create|show-code|join]"
allowed-tools: [Bash]
---

# /sptc:subnet

> **Skeleton — thin by design.** Operative instructions for this skill are delivered by the
> `sptc` adapter at invocation time. Look out for the UserPromptSubmit additionalContext.
>
> **Operative.** If injection ever no-ops (spt absent / adapter unregistered), check
> SPT's installation status using the skill `sptc:setup`. Otherwise, avoid additional steps.

Pairs machines into a private network so agents reach each other across nodes.
