# Skill authoring

> How `/sptc:*` skills are written in this repo. Skills live on **two surfaces** (ADR-0001's
> thin-skeleton split). Keep both lean: the plugin file is a stub, the adapter file is the operative
> instructions. Bloat — provenance notes, requirement ids, ADR/finding citations, rationale the
> running agent doesn't need — does not belong in either.

## The two surfaces

| Surface | File | Role | Audience |
|---|---|---|---|
| **Plugin skeleton** | `plugin/sptc/skills/<name>/SKILL.md` | Thin stub shipped on cplugs. Frontmatter `description` is the routing surface; body is a fixed note. | The model deciding *which* skill to load. |
| **Adapter body** | `adapter/strings/skills/<name>.md` | The operative instructions, UPS-injected at invocation from the adapter `[strings]`. | The agent *running* the skill. |

The plugin skeleton carries **no operative steps** — those are injected from the adapter body at call
time. The two never duplicate instructions.

## Plugin SKILL.md template

```md
---
name: <name>
description: |
  <One sentence: what it does.> Use when the user says "<trigger>", "<trigger>", or
  wants to <intent>.
argument-hint: "<args>"        # omit if none
allowed-tools: [Bash]          # the minimum the skill needs (Bash/Read/Write/Monitor)
---

# /sptc:<name>

> **Skeleton — thin by design.** Operative instructions for this skill are delivered by the
> `sptc` adapter at invocation time. Look out for the UserPromptSubmit additionalContext.
>
> **Operative.** If injection ever no-ops (spt absent / adapter unregistered), check
> SPT's installation status using the skill `sptc:setup`. Otherwise, avoid additional steps.

<One line naming what the skill does.>
```

The skeleton note above is **verbatim and identical** across every skill (except `setup` — see
below). Do not re-add ADR/finding/requirement citations to it.

## Adapter body template

```md
# /sptc:<name> — operative instructions

**Goal:** <one line — the outcome the agent is producing>.

**Do this:**

1. <step>
2. <step>
<!-- [<doc>->REQ-NAME] -->   # keep the traceability tag if this body is doc evidence
```

Rules for the body:

- **No provenance preamble.** Do not open with "Delivered file-backed via the adapter `[strings]`…"
  — the running agent does not need to know its own delivery mechanism.
- **Self-contained.** Inline the operative steps; do **not** redirect to `spt how-to <topic>`. (A
  verb's own `spt <verb> --help` is fine to cite as the live source of truth where the surface is
  large, e.g. `subnet`.)
- **Concise.** Commands, the must-do sequence, the reply/output shape — nothing else. Cut rationale,
  repeated warnings, and history.
- **Keep `[<doc>->REQ-*]` HTML-comment tags** — they are traceability evidence; place them on/above the
  real evidence.

## `description` rules (from write-a-skill)

The `description` is the only thing the model sees when choosing a skill. Per
`write-a-skill`: third person, **what it does** then **"Use when [triggers]"**, ≤1024 chars, no
time-sensitive info, consistent terms. Route phrases reference **`/sptc:`** (the shipped plugin
name; the `s/sptc/spt/` succession flip renames them later). The legacy `claude_skill_owl`
descriptions are the basis for the trigger phrasing — adapt them, dropping legacy internals
(`$OWL`/`$LIVE`/`info.json`).

## The `setup` exception

`setup` is **self-contained on both surfaces**: it runs precisely when spt-core may be **absent**,
so UPS-injection (which needs `spt adapter get-string`) can no-op. Its plugin SKILL.md therefore
keeps the operative steps as the floor, and the adapter body mirrors them for the spt-present repair
path. Tighten `setup` for concision, but do **not** reduce it to a stub.

## Checklist

- [ ] `description` is third-person, has "Use when …" triggers, routes via `/sptc:`.
- [ ] Plugin SKILL.md uses the verbatim skeleton note + one what-it-does line (except `setup`).
- [ ] Adapter body has no provenance preamble, is self-contained, ≤ ~40 lines (large surfaces aside).
- [ ] `allowed-tools` is the minimum the skill needs.
- [ ] Traceability `[<doc>->REQ-*]` tags preserved.
