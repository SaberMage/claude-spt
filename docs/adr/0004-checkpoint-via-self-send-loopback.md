# Checkpoint clears the session via a self-sent loopback message, authored inline pre-clear

## Status

proposed (2026-06-24)

## Context

The operator asked for **checkpoint** (see `CONTEXT.md`): a live agent flags a commune so its own
session is automatically cleared and re-seeded — the agent-driven sibling of a manual `/clear` —
without the operator intervening. Building it on the **public spt-core surface only** (AGENTS.md)
surfaced four hard forces:

1. **Only the translation binary can drive the spt-hosted PTY.** Typing `/clear` + a wake prompt into
   the broker-held PTY is the `[message-idle-translation-binary]`'s job. But that binary is
   `stdin`-driven (`init`/`event`/`input` lines from spt-core) with **no filesystem or commune
   knowledge** — it cannot read `.claude/<id>-commune.md` to detect a trigger. The daemon is the
   single-writer that ingests+deletes the drop (`REQ-HAZARD-DROP-FILE-SINGLE-WRITER`), so any
   adapter-side reader races it (TOCTOU).
2. **Only IDLE delivery routes to the binary.** While the agent is mid-turn, messages route to the
   poll/hook channel (additionalContext), not the binary. A trigger must reach the binary *as an idle
   delivery* to fire the macro.
3. **Re-seed staleness.** If the commune is authored *after* `/clear` (the boundary/resume-Self
   refresh path), the legacy `psyche-stale-after-clear` gap reappears (LLM-latency-bounded): the
   durable store and the drop file may both be absent/stale at the post-clear SessionStart.
4. **No daemon-push primitive.** The clean design — daemon detects the trigger in the commune it
   ingests and pushes a new `{"type":"checkpoint"}` stdin message to the binary — needs an spt-core
   capability that does not exist on the published surface.

Empirically (proven this session): cyan coloring of the EVENT block is impossible (SGR bytes are
eaten by CC's input box; user-turns are theme-fixed); and a **self-addressed `spt send` loops back
through the endpoint's own translation binary** and lands as a delivered EVENT.

## Decision

Checkpoint is driven by a **self-sent loopback message**, with the commune **authored inline
pre-clear**:

1. The agent runs `/sptc:commune --checkpoint` and authors its commune **inline, during its own
   turn**, embedding the literal trigger `!!checkpoint!!` (one = default wake; a pair brackets a
   custom wake directive). The agent *is* the authoring LLM, so the context is captured **before**
   the clear.
2. A new **PostToolUse hook** detects the trigger in the Write's `tool_input.content` (not a file
   re-read — sidesteps the daemon-delete race), flips the perch idle (`spt api state idle`, so the
   next delivery routes to the binary, not the poll channel), and **self-sends** a reserved
   wire-sentinel: `spt send --from <id> <id> <wire-sentinel[+wake-text]>`.
3. The message loops back into the endpoint's **own** translation binary, which recognizes the
   wire-sentinel and emits the **clear+wake macro** — `ctrl+s · 50ms · /clear · enter · 500ms ·
   <wake-text> · enter · commit` — instead of normal delivery. (`ctrl+s` first is required to stash
   any lingering input.)
4. Post-clear re-seed is carried by spt-core's `psyche-download` verb (v0.15.0 Tier-1 contract), **not**
   adapter-side drop reading. The verb returns durable context + the freshest un-synthesized
   `<pending-commune>` (trigger stripped core-side), race-free.

**Load-bearing invariant:** checkpoint authors the commune **inline pre-clear (Shape 1)** and never
defers authoring to a post-clear resume-Self refresh (Shape 2). Shape 2 reintroduces force #3's stale
gap. Any future refactor that routes checkpoint through boundary/refresh must re-open this ADR.

**Rejected alternatives:**
- *Binary watches the commune file* — wrong actor (no FS knowledge), and TOCTOU against the daemon's
  single-writer ingest+delete.
- *Daemon-push (`{"type":"checkpoint"}`)* — cleaner, but needs an spt-core capability absent from the
  public surface; would block the feature on a core change.
- *Adapter-side raw-file SessionStart inject* — TOCTOU against core's pulse-delete; spt-core owns the
  race-free re-seed (the `psyche-download` `<pending-*>` append).

## Consequences

- **New surfaces:** `[hooks.PostToolUse]` (manifest + hooks.json) + the detector hook; a checkpoint
  branch in `cc-spt-idle-translate` (wire-sentinel filter → macro + custom-wake parse); `/sptc:commune`
  becomes a full-fat skill doc (+ `--checkpoint` + hint) so live agents are natively aware.
- **New/extended requirements to mint:** `REQ-DIST-CHECKPOINT-MACRO`, `REQ-DIST-RESUME-CONTEXT`
  (SessionStart `psyche-download` wiring), extend `REQ-DIST-IDLE-TRANSLATE` (multi-line envelope).
- **Cross-team contracts depended on:** `!!checkpoint!!` marker stripped core-side (todlando, W5
  follow-up); `psyche-download` Tier-1 verb (doyle/todlando, ships v0.15.0 W5). The checkpoint
  *mechanics* (clear+wake) have **zero** spt-core dependency; only the re-seed *richness* waits on W5.
- **spt-hosted-only, by design:** a user-launched (seed-path) CC session has no broker PTY / no
  translation binary, so it cannot checkpoint. Accepted — checkpoint leverages spt-core's hosted
  lifecycle on purpose.
- **The indirection is deliberately documented here** (an agent messaging itself to trigger its own
  clear is non-obvious) so it is not "simplified" away by a future reader.
