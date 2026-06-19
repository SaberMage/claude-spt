# Skill authoring

> How `/sptc:*` skills are written here. The guiding rule: a skill tells the agent **what to do, what
> it will see, and how to act** — never **how the plugin or spt-core implements it**. Strip internals,
> strip jargon from anything the user reads, never ship an untrue step, and keep the agent's actions to
> the minimum (the end user is often waiting on it).

## What a skill body must NOT contain

- **Plugin / spt-core internals.** No adapter resolution (`--adapter`, parent-pid / `host_binaries`
  matching), no perch-state stamping (`state=live_agent`), no daemon/poll-vs-relay coordination, no
  seed/bind wiring. The agent runs a command; it does not need to know how spt routes it.
- **Internal jargon in user-facing text.** What the *user* reads (e.g. the LIVE announcement) carries
  zero `Perch` / `Psyche` / `daemon` / `LiveAgent` / marker names. Say "Now running as `<id>`", not
  "LiveAgent, Psyche hosted by the daemon".
- **Untrue or stale steps.** Verify against behavior. (E.g. the persistent Monitor relay *survives*
  `/clear`/compact — there is no "re-fire the relay" step.)
- **Ceremony.** Don't make the agent gate on `BOUND`/`READY` markers in the happy path. Fire it,
  announce, move on — inspect markers only when troubleshooting.

Keep the legacy operational tells that *are* useful: the Monitor task `description: "« spt event »"`,
and the `<EVENT type="msg|alarm|echo_commune|init_signoff" …>` envelope catalog the agent handles.

## Minimum-friction bringup

`ready` and `live` bring a perch up while the **user waits**. Optimize for the fewest agent
actions and zero avoidable delay: resolve the id (given, else `spt whoami`), fire the listener as one
persistent Monitor task, announce reachable. No marker-watching, no extra round-trips.

## Two delivery patterns

| Pattern | Files | Use for |
|---|---|---|
| **A — injected** | thin `plugin/sptc/skills/<n>/SKILL.md` stub + `adapter/strings/skills/<n>.md` body (manifest `[strings.skills].<n>`) | Skills the **user** invokes (`/sptc:<n>`) or a hint surfaces. The UPS hook injects the body on the slash-command. |
| **B — full-fat** | `plugin/sptc/skills/<n>/SKILL.md` only — operative body in the SKILL.md, **no** `[strings.skills]` entry, **no** adapter body | Skills the **agent self-drives reactively** without the user typing `/sptc:<n>` — `send`, `commune`, `signoff`. UPS-injection fires only on a slash-command in the prompt, so it cannot deliver these; the always-loadable SKILL.md does. |

Self-drive anchor (both patterns): point the agent at the live source of truth where one exists —
`spt how-to <topic>` (ready · send · subnet · live) or `spt <verb> --help` — instead of duplicating
full reference inline.

## Templates

**Pattern A — plugin skeleton** (thin; the `description` is the routing surface):

```md
---
name: <name>
description: |
  <What it does.> Use when the user says "<trigger>", "<trigger>", or wants to <intent>.
argument-hint: "<args>"        # omit if none
allowed-tools: [Bash]          # the minimum the skill needs
---

# /sptc:<name>

> **Skeleton — thin by design.** Operative instructions for this skill are delivered by the
> `sptc` adapter at invocation time. Look out for the UserPromptSubmit additionalContext.
>
> **Operative.** If injection ever no-ops (spt absent / adapter unregistered), check
> SPT's installation status using the skill `sptc:setup`. Otherwise, avoid additional steps.

<One line naming what the skill does.>
```

**Pattern A — adapter body** (the injected operative instructions):

```md
# /sptc:<name> — operative instructions

<One line: the outcome.>

1. <step> … <step>

Full guidance: `spt how-to <name>` (or `spt <verb> --help`).
<!-- [<doc>->REQ-NAME] -->   # keep the traceability tag if this body is doc evidence
```

**Pattern B — full-fat SKILL.md** (no skeleton note, no adapter body):

```md
---
name: <name>
description: |
  <What it does.> Use when the user says "<trigger>", or when you need to <intent> yourself.
allowed-tools: [Bash]
---

# /sptc:<name>

<The full operative instructions — the agent loads this directly.>
```

## The `setup` exception

`setup` is **self-contained on both surfaces**: it runs precisely when spt-core may be absent, so
injection can no-op. Its plugin SKILL.md keeps the operative steps as the floor; tighten it, never
reduce it to a stub.

## `description` rules (from write-a-skill)

Third person, **what it does** then **"Use when [triggers]"**, ≤1024 chars, no time-sensitive info,
consistent terms. Route phrases reference **`/sptc:`** (the shipped plugin name; the `s/sptc/spt/`
succession renames them later). Trigger phrasing is adapted from the legacy `claude_skill_owl`
descriptions, dropping legacy internals (`$OWL`/`$LIVE`/`info.json`).

## Checklist

- [ ] Body says what to do / what you'll see / how to act — no plugin or spt-core internals.
- [ ] User-facing text carries no internal jargon; no untrue or stale steps.
- [ ] Bringup skills (`ready`/`live`) are minimum-friction — fire and announce, no marker-gating.
- [ ] Right pattern: agent-self-driven (`send`/`commune`/`signoff`) → full-fat, no injection.
- [ ] Cites `spt how-to`/`--help` where one exists; `allowed-tools` is the minimum.
- [ ] `[<doc>->REQ-*]` traceability tags preserved.
