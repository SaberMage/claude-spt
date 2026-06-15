<!-- [doc->REQ-DOCS-SITE] -->
# Introduction

`claude-spt` is the [Spacetime (`spt`)](https://sabermage.github.io/spt-releases) adapter for
Claude Code. You install one Claude Code plugin — `sptc` — and get three things at once:

- **Agent messaging and live agents** inside Claude Code: send messages between agents, run a
  reachable "perch," and drive long-lived live-agent sessions, all delegated to the `spt` binary.
- **An invisible `spt-core` installer.** The first time the plugin loads, it installs `spt-core`
  for you if it is missing. No separate setup step.
- **A casual on-ramp to spt-core.** The plugin is the friendly front door to the wider Spacetime
  agent ecosystem — subnets, terminal hosting, seamless self-update — without leaving your editor.

## Mental model

Claude Code provides the **harness** (hooks, skills, your prompt). The `spt` binary provides the
**core** (messaging, lifecycle, networking). `claude-spt` is the **thin adapter** between them: it
maps Claude Code's hook events to the `spt` binary's harness-contract entry points and surfaces
delivered messages back into your session.

```text
   Claude Code  ──hook events──▶   sptc adapter   ──spt api──▶   spt-core
   (the harness)                  (this project)                (messaging,
        ▲                          thin glue                     live agents,
        └──────  additionalContext / skills  ◀── renders ◀────    networking)
```

Two ideas follow from that picture, and they shape everything else in these docs:

1. **The adapter is thin by design.** Logic and skill instructions live in the `spt` binary and
   its adapter manifest (conducted by spt-core), not in the plugin. The plugin ships skeletons;
   the operative content is delivered at run time. See
   [Harness contract](./reference/harness-contract.md).
2. **It is built against `spt-core`'s public surface only** — the published `spt-releases` binary,
   install scripts, and docs. That constraint is the point: it proves the adapter contract is
   buildable by anyone, from the published surface alone.

## Status

This is an early, skeleton-honest build. Skills surface under the `/sptc:*` namespace; surfaces
that are not yet operative say so in place. Start with the [Quickstart](./quickstart.md).
