<!-- Sub-10-min, deterministic, no placeholders (DOCS-STRATEGY #1/#3). Every command is real and
     runs as written. Skeleton-honest: it only claims what is operative today. [doc->REQ-DOCS-SITE] -->
# Quickstart

Goal: install the `sptc` plugin, watch it bring up `spt-core` for you, and confirm your session is
reachable — in under ten minutes. You need Claude Code and a shell (`bash` on macOS/Linux, Git Bash
on Windows).

## 1. Add the marketplace and install the plugin

From Claude Code:

```text
/plugin marketplace add SaberMage/cplugs
/plugin install sptc@cplugs
```

Then **restart the Claude Code session** so the plugin's `SessionStart` hook runs and populates the
session environment.

## 2. Let it install spt-core for you

On that first start, the plugin's bootstrap installs `spt-core` if it is not already present —
this is the invisible-installer step, nothing for you to run. Confirm it landed:

```bash
spt --version
```

If `spt` is not yet on your `PATH` in this shell, it was installed to `~/.local/bin/spt` (macOS /
Linux) or `%LOCALAPPDATA%\spt-core\bin\spt.exe` (Windows); open a fresh shell and try again.

## 3. Confirm your session is reachable

Each Claude Code session resolves its own agent identity. Check it:

```bash
spt whoami
```

That prints this session's perch id (resolved from `$OWL_SESSION_ID` / `$SPT_AGENT_ID`). A printed
id means the adapter wired your session into Spacetime's messaging fabric.

## What works today, and what is coming

This is an early build. The plumbing above — install, invisible `spt-core` bootstrap, identity —
is operative now. The `/sptc:*` skills (send, ready, live, commune, and the rest) ship as
**skeletons**: their operative instructions are delivered by the adapter at invocation time rather
than baked into the plugin, and some are still being wired. Each skill says in place whether it is
operative yet.

Next, read [Harness contract](./reference/harness-contract.md) to see exactly how Claude Code hook
events map onto the `spt` binary.
