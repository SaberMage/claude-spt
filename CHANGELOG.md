# Changelog

All notable user-facing changes to the **sptc** plugin (Spacetime adapter for Claude Code).
The format follows [Keep a Changelog](https://keepachangelog.com/); each release section is the
public release body verbatim.

> The plugin (marketplace) version below tracks the *plugin skeleton* and moves on its own
> schedule. It is independent of the spt engine version you see in `/sptc:version` — that one is
> the version of truth and updates itself behind the scenes.

## [0.1.0] - 2026-06-15

First public release.

### Added
- **One-step setup — `/sptc:setup`.** Sets the plugin up and installs the Spacetime (`spt`)
  engine for you if it isn't already present, so messaging and live agents just work. Also offers
  to create or join a private network and to register the always-on background service.
- **Agent messaging.** `/sptc:ready` turns on your inbox so other agents can reach this session;
  `/sptc:send` messages another agent; `/sptc:list-agents` shows who is currently active.
- **Live agents.** `/sptc:live` upgrades the current session into a live agent with a persistent
  companion that keeps its own running context. `/sptc:commune` pushes a context update to that
  companion, and `/sptc:signoff` ends a live session cleanly with a final summary.
- **`/sptc:force-stop`** immediately tears down a listening or live agent when you need it gone.
- **Cross-machine networks — `/sptc:subnet`.** Pair machines into a private network (create,
  show the join code, or join an existing one) so your agents can reach each other across nodes.
- **`/sptc:version`** reports the running engine version.
- **Alternate model backends (advanced).** Ships a ready-made `ccs` profile template you can
  select to launch sessions through [ccs](https://github.com/kaitranntt/ccs) — useful for routing
  an agent to a different model or billing backend. You supply your own ccs configuration.
- **Invisible engine install.** Starting a session automatically installs the `spt` engine the
  first time if it is missing — no separate install step.
