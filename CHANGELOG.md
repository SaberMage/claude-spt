# Changelog

All notable user-facing changes to the **sptc** plugin (Spacetime adapter for Claude Code).
The format follows [Keep a Changelog](https://keepachangelog.com/); each release section is the
public release body verbatim.

> Each release below is keyed to the **adapter version of truth** (the version you see in
> `/sptc:version` and the GitHub release tag). The cplugs *plugin skeleton* version (`plugin.json`)
> moves on its own slower schedule and may differ.

## [0.9.0] - 2026-06-28

> Requires spt-core **v0.16.0 or newer** (unchanged from 0.8.0). This release is an internal
> re-plumbing of how Claude Code hooks run — there is **no change to what you do or see**. After
> updating, run `/reload-plugins` (or restart Claude Code) once, as the update reminds you.

### Changed
- **Hook behaviour now updates with `spt adapter update` — no plugin reinstall needed.** Previously,
  any change to how a hook works (message delivery, the live-agent checkpoint, the session briefing)
  required a separate Claude Code plugin update. Now that logic lives in the `claude-spt` program that
  `spt adapter update` already refreshes, so a single update keeps hooks current. The plugin's hook
  wiring is now fixed and rarely needs a marketplace bump again.

### Fixed
- Nothing user-visible. This is a behaviour-preserving refactor: messaging, the `/sptc:*` skills, the
  live-agent checkpoint (`/sptc:commune --checkpoint`), and the session briefing all work exactly as
  before — they are just driven by the consolidated `claude-spt` program instead of separate hook
  scripts shipped in the plugin.

## [0.8.0] - 2026-06-26

> Requires spt-core **v0.16.0 or newer** (was v0.15.0). This release unifies the project naming,
> turns updating into a single command, and consolidates the adapter to one tool binary — built on
> the update-arc + CLI features that arrive in spt-core v0.16.0.

### Added
- **One-command update — `spt adapter update claude-spt`.** A single command now keeps *everything*
  current: it pulls the new adapter (manifest + binary + strings) **and** reconciles the Claude Code
  plugin in the same step. The only manual residual is `/reload-plugins` (an unavoidable Claude Code
  TUI action), which the update prints a reminder to run.
- **Mid-turn reachability for live agents.** A live agent can now receive a message *while it is
  working* (not only between turns) — incoming messages surface mid-turn, with the endpoint honestly
  marked busy during a turn and idle when it finishes.

### Changed
- **Name unification.** The project/repo and adapter are now **`claude-spt`** everywhere spt-core
  sees them (the repo was renamed `spt-claude-code` → `claude-spt`; install and update both read
  `claude-spt`). The Claude Code plugin stays `sptc` / `/sptc:*` this release.
- **One tool binary.** The separate digest, psyche, and idle-translation binaries are consolidated
  into a single `claude-spt` binary (subcommands) — one artifact per platform in the release.
- **Session display name + remote control.** A spawned/resumed endpoint now shows its `{id}` as the
  session display name and is remote-control-attachable under that id, on both bringup paths.
- **Leaner skills.** `commune` / `send` / `signoff` guidance is now delivered by the adapter (so it
  updates with `spt adapter update`) rather than baked into the plugin.

### Requires
- spt-core **v0.16.0+** (the composite `[update.post]`, the idle-translation `command` seam, and the
  `{adapter_dir}` substitution all land in v0.16.0).

## [0.7.0] - 2026-06-24

> Requires spt-core **v0.15.0 or newer** (was v0.13.2). This release adds self-checkpointing for
> live agents, automatic resume context, and clearer multi-line message delivery — all built on
> features that arrive in spt-core v0.15.0.

### Added
- **Self-checkpointing for live agents — `/sptc:commune --checkpoint`.** A live agent can now reset
  and rebuild its own context without you running `/clear`. Write a commune containing the marker
  `!!checkpoint!!` and the session clears itself, then wakes back up from that very commune and keeps
  going. A single `!!checkpoint!!` wakes with a default "Proceed with next steps"; a **pair** of
  markers wakes with whatever instruction you write between them. The marker is one-shot — it never
  lingers in your rebuilt context.
- **Automatic resume context.** When a live agent's session starts (or clears), it now pulls its
  durable role, working context, and latest unsynced commune and re-injects them automatically — so
  it resumes where it left off instead of coming back blank.

### Changed
- **Incoming messages are easier to read.** A message delivered from another agent now renders across
  multiple lines — the envelope opening, the body, and the close each on their own line — instead of
  one dense single line.
- **Requires spt-core v0.15.0+** (up from v0.13.2). Self-checkpointing and resume context both rely
  on capabilities introduced in that release; `/sptc:setup` and `spt adapter update` will keep you
  current.
- Adapter version of truth is now **0.7.0** (shown in `/sptc:version` and the release tag).

## [0.6.2] - 2026-06-23

> Requires spt-core **v0.13.2 or newer** (unchanged). A small but important delivery fix — no
> change to commands or setup.

### Fixed
- **Messages delivered while you're idle now actually send.** Previously an incoming message from
  another agent could be typed into your Claude Code input box but never submitted — it just sat
  there as an unsent draft. The delivery now presses **Enter** to send it, so idle-delivered
  messages arrive and run on their own. Your half-typed draft is still stashed and restored around
  the delivery, exactly as before.

## [0.6.1] - 2026-06-22

> Requires spt-core **v0.13.2 or newer** (the version that can install a multi-platform package).
> Packaging-only release — no change to what the adapter does, only how it ships.

### Packaging
- **One download now covers every platform.** The adapter ships as a single multi-platform
  `adapter.spt` that bundles both the Windows and Linux builds beside one shared manifest; installing
  picks your platform automatically. This replaces the previous per-OS files and the Windows-only
  stopgap `adapter.spt` (which broke self-update on Linux), so `spt adapter add --release …` and
  `spt adapter update` now just work on either OS with no platform to pick. Requires spt-core
  **v0.13.2+** (the version that can read a multi-platform package).

### Changed
- **Setup is simpler.** `/sptc:setup` now activates the adapter with a plain
  `spt adapter add --release SaberMage/spt-claude-code` — no OS detection or asset selection, since
  the one package is host-agnostic.
- Adapter version of truth is now **0.6.1** (shown in `/sptc:version` and the release tag). The
  cplugs plugin skeleton bumps with the simplified setup body.

## [0.6.0] - 2026-06-22

> Requires spt-core **v0.13.0 or newer** for the two new capabilities below. On older spt-core
> they're simply inactive — nothing else changes, so this release is safe to take on any version.

### Added
- **Idle agents now receive your messages.** When an spt-hosted agent is sitting at its prompt
  (idle, not mid-task), a message sent to it now lands *in that session* — typed in and submitted
  for you — instead of going unseen until the agent next acted. If you were part-way through typing
  your own input, your draft is stashed first and restored right after, so an incoming message never
  eats what you were writing.
- **Resuming an agent brings back its conversation.** Relaunching a session now reloads its prior
  transcript instead of cold-starting a blank one, and the resume picker shows each session's project
  folder so you can tell them apart.

### Changed
- Adapter version of truth is now **0.6.0** (shown in `/sptc:version` and the release tag). The
  cplugs plugin skeleton is unchanged (still on its own slower track).

## [0.5.0] - 2026-06-19

### Added
- **Agents now know who they are the moment a session starts.** When a session is already
  reachable — you launched it through `cc`, or it cleared/compacted mid-run — it now opens with a
  short brief: its own agent name, a reminder that it's already live (so it won't try to re-arm),
  and how to message other agents (`spt send` and reply, plus `spt endpoint list` to see who's
  around). Previously a resumed or spt-launched session could start not knowing its own name.
- **Sessions that aren't reachable yet learn how to reach out.** On a machine that belongs to a
  subnet, a plain session with no perch now gets a one-line tip on reaching other agents with
  `spt ring` — without having to go reachable first. Solo machines with no peers see nothing.

## [0.4.0] - 2026-06-18

### Changed
- **Your live-agent companion now runs in a safe, limited mode.** When you go live with
  `/sptc:live`, the background companion that writes your context-resume notes works with a
  file-only toolset and a lighter, cheaper model. It is more contained and costs less to run,
  with no change to what you see or do.
- **Removed the experimental `:deep` profile.** `claude-spt:deep` was an unused placeholder. The
  one shipped profile overlay is `claude-spt:ccs` (routes sessions through `ccs`). If you ever
  selected `:deep`, use `:ccs` or the base adapter instead.

### Fixed
- **Sessions that spt starts for you no longer stall on a permission prompt.** When spt brings up
  a Claude Code session on your behalf (the live companion, and the spt-hosted launcher), it could
  hang waiting on an approval prompt that no one was there to answer. Those sessions now start
  cleanly.

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
