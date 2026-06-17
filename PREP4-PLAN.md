# PREP-4 — legacy-parity bringup (Option A) → v0.3.0 — JIT plan

> **Trigger:** spt-core **v0.9.0 SHIPPED** (2026-06-17, doyle). Adapter-agnostic seed + bind-time
> resolution by `host_binaries` + `spt adapter use` + optional `--adapter`. Activates the PREP-4
> staging from v0.2.1. Closes the legacy-parity arc.

## Decision: OPTION A (doyle-ruled + code-confirmed, livehost.rs:282)
`:live` differs from base ONLY by `[session.psyche_init]` → fold psyche_init INTO base claude-spt,
DELETE `[profiles.live]`. ready-vs-live is the COMMAND, not the profile:
- `/sptc:live`  → bare `spt api listen <id>` → base has psyche_init → perch state=live_agent → daemon
  hosts the Psyche. LIVE.
- `/sptc:ready` → bare `spt ready/poll <id>` → perch state=ready_agent → livehost.rs:282 SKIPS psyche
  regardless of base psyche_init. READY.
Zero `--adapter` on the default path. `:ccs`/`:deep` stay as sanctioned override profiles (genuine
deltas: command=ccs, digest window) — selected with explicit `--adapter claude-spt:<p>`.

Compat gate = (a): hard-bump `min_spt_core_version` 0.7.0 → 0.9.0 (no <0.9.0 users; compat gate
refuses older spt-core). Bind/boundary hooks KEEP explicit `--adapter claude-spt` (sanctioned
override, valid on 0.9.0; only seed + live-listen go bare — doyle scope).

## Tasks (wire)
1. **adapter/claude-spt.toml**: add `[session.psyche_init]` to base (move the 4-key command from
   `[profiles.live.session.psyche_init]`); DELETE the `[profiles.live...]` block; `min_spt_core_version
   = "0.9.0"`; rewrite the stale base=ReadyAgent/:live-activates comments to the Option-A model.
2. **adapter/strings/skills/live.md**: bringup → single persistent Monitor task running bare
   `spt api listen <id>` (NO seed-chain, NO `--adapter`, NO `--manifest`). SessionStart already seeded
   the perch agnostically; listen resolves claude-spt by pid→host_binaries and the live path stamps
   state=live_agent. Strip the PREP-4 interim note + all `:live` composite refs. Keep OUTPUT
   DISCIPLINE + canonical LIVE block.
3. **plugin/sptc/hooks/session-start.sh**: `seed)` branch → bare `spt api seed --pid "$PPID"
   --session-id "$sid"` (drop `--adapter "$ADAPTER"`). bind/boundary branches UNCHANGED.
4. **adapter/strings/skills/setup.md**: add a step calling `spt adapter use claude-spt` (durable
   active-profile pointer → claude-spt for the `claude` host binary); fix the line-49 spot-check
   (`get-string claude-spt:live` → a live profile that still exists, e.g. `:deep`). ccs `:ccs` refs
   stay valid (override profile).
5. **plugin/sptc/skills/live/SKILL.md**: stub text — drop the "activates claude-spt:live profile"
   claim; base is now live-capable, the listen command actualizes.
6. **ci/manifest/registration-int.sh**: drop `:live`-profile assertions (profile deleted); keep the
   `skills.live` file-string check (that's the skill KEY, not a profile).
7. **ci/psyche/live-relay-int.sh**: `A=claude-spt:live` → `claude-spt`; seed/listen drop `--adapter`
   composite (bare or base). Asserts psyche hosts off the BASE manifest + live listen path.
8. **traceable-reqs.toml**: rewrite REQ-SKILL-LIVE title/notes to the Option-A model (base
   psyche_init + command-decides, no :live profile). Fix line-180 ":deep/:live" comment.
9. **docs/PARITY.md**: lines 18,27 — ":live profile" → base psyche_init / command-decides.
10. **tools/claude-spt-psyche/src/main.rs + Cargo.toml**: doc-comment accuracy (base now declares
    psyche_init; the runner itself is unchanged).
11. Lower-priority doc accuracy (not gate-blocking, may defer): docs/adr/0002 wording,
    SPT_HARNESS_ADAPTER_TIPS.md (general :live-overlay pattern still valid as a technique), historical
    PLAN docs + SPT-CORE-FINDINGS.md = dated snapshots, leave.

## Gate
`sh ci/run-gates.sh` green + `traceable-reqs check` green + manifest validates + both .spt repack &
validate. Then **VERIFY on live spt 0.9.0**: update local spt 0.8.2→0.9.0 (`spt update fetch &&
apply`, restart daemon); run `/sptc:live` end-to-end with NO `--adapter` anywhere; confirm the perch
stamps adapter=claude-spt + state=live_agent + online + Psyche hosted, and the user sees only the
clean LIVE block. Empirically reconfirms poll-stays-ready on a psyche_init base.

## Release (v0.3.0)
Bump adapter version → 0.3.0 (min_spt_core + structural change). CHANGELOG [0.3.0] (user-facing:
going live is now one bare step, full legacy parity; requires spt-core 0.9.0+). Repack both per-OS
.spt (binaries unchanged), tag, GH release. **cplugs republish** this time (session-start.sh is a
structural skeleton change) → bump plugin.json 0.1.2→0.1.3, copy skeleton subset, push cplugs.
Sequence: per-OS-asset release FIRST, then cplugs skeleton bump (runbook coupling).

## Closes
The whole legacy-parity arc (doyle). PREP-4 fully activated; staging from v0.2.1 retired.
