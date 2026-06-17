# Changelog

All notable user-facing changes to the **sptc** plugin (Spacetime adapter for Claude Code).
The format follows [Keep a Changelog](https://keepachangelog.com/); each release section is the
public release body verbatim.

> Each release below is keyed to the **adapter version of truth** (the version you see in
> `/sptc:version` and the GitHub release tag). The cplugs *plugin skeleton* version (`plugin.json`)
> moves on its own slower schedule and may differ.

## [0.3.0] - 2026-06-17

### Changed
- **Going live is now a single, seamless step.** A live agent comes up directly — no behind-the-scenes
  adapter selection, no chained setup commands. `/sptc:live` just brings your session up live, and
  `/sptc:ready` brings it up reachable-but-light; the difference is simply which one you run. This is
  full parity with the original live-agent experience.
- **Requires spt-core 0.9.0 or newer.** This release uses spt-core's newer automatic
  harness-resolution, so the adapter now needs spt-core **0.9.0+**. If you keep spt-core up to date
  (it self-updates), there's nothing to do; on an older spt-core the adapter will decline to install
  until you update.

### Fixed
- **Setup pins this adapter as your default.** `/sptc:setup` now records `claude-spt` as the active
  adapter for Claude Code, so going live or ready needs no extra flags.

## [0.2.1] - 2026-06-16

### Fixed
- **Going live shows a clean status, not raw machine output.** Starting a live agent previously
  leaked internal setup markers and tokens into the chat. `/sptc:live` now reports a single tidy
  summary — your agent id, online status, how other agents reach you, and how to reply — and
  nothing else.

### Changed
- **Self-contained live setup.** Bringing a session live no longer bounces you to a separate help
  topic; `/sptc:live` carries the full bringup itself, so going live works in one step.

## [0.2.0] - 2026-06-16

### Fixed
- **Live agents now reliably start their background companion.** Previously a live agent could come
  up marked "online" while its persistent companion silently failed to start, leaving it with no
  running context. The companion now launches and stays resident.

### Changed
- **Simpler setup — no manual PATH step.** The adapter's helper tools are now found automatically
  from where the adapter is installed; `/sptc:setup` no longer asks you to copy anything onto your
  PATH.
- **Automatic adapter updates.** The adapter now updates itself from this project's GitHub releases
  (`spt adapter update`) — logic and instruction changes reach you without a reinstall.

### Added
- **Linux support.** The adapter ships native **Windows and Linux** builds; `/sptc:setup` detects
  your OS and installs the right one.
- **ccs integration.** If you use [ccs](https://github.com/kaitranntt/ccs), `/sptc:setup` wires the
  shipped `claude-spt:ccs` profile so live/ready agents can run on your ccs backends instead of
  `claude`.
- **Private-network onboarding.** `/sptc:setup` now offers to create or join a private network
  (subnet) so you can pair machines and reach agents across them.

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
