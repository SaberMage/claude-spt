<!-- [doc->REQ-SKILL-LIVE] -->
<!-- [doc->REQ-HAZARD-PSYCHE-PERMS-DEADLOCK] -->
# The Psyche runs as a constrained, auto-approving companion (legacy owl parity)

## Status

accepted (2026-06-18)

## Context

A live session's *Psyche* (see `CONTEXT.md`) is a second `claude` process the spt-core daemon
hosts alongside the parent agent. The daemon launches our `claude-spt-psyche` runner **detached,
with `Stdio::null`**; the runner seeds one headless `claude` turn from the daemon-supplied prompt,
then drives one `claude --continue` turn per pulse. The Psyche's only job is to author a *commune*
on each pulse.

Forces:

1. **No operator is attached.** The Psyche is detached and its stdio is discarded. Anything that
   would normally prompt the user — a tool-permission gate — has nothing to answer it, so the turn
   would block forever and the daemon would believe it hosts a working companion that silently never
   communes. (Generalizes to the `[session.self]` bringup, which spawns CC into a broker PTY with no
   operator at spawn.)
2. **A commune needs file IO, nothing more.** The Psyche reads context and writes its commune
   delta. It does not run the build, hit the network, or message other agents. Granting it the
   parent agent's full toolset is unnecessary blast radius for an unattended, auto-approving process.
3. **It must not silently ride the parent's heavy model.** The companion is a cheap, frequent actor;
   leaving the model unpinned lets it inherit whatever the parent uses.
4. **A proven reference exists.** The legacy sibling `claude_skill_owl`
   (`src/live/wrapper/claude.rs`) already solved this exact shape — its psyche init/resume/final
   invocations are uniformly sandboxed and auto-approving. Parity with that posture is the safe
   default, not a novel design.

## Decision

Every Psyche `claude` turn — the seed **and** each pulse — runs inside a fixed sandbox, mirroring
legacy owl. `claude-spt-psyche` appends this flag set (`sandbox_flags()`) to both `seed_cmd` and
`pulse_cmd`:

- `--tools Read,Edit,Write` — file IO only; **no** Bash, network, messaging, etc.
- `--disable-slash-commands` — the Psyche is driven by its prompt, not a slash surface.
- `--dangerously-skip-permissions` — **required**, not cosmetic: with no operator/stdin (force 1),
  an interactive permission prompt would deadlock the turn. Auto-approve is *bounded* because it sits
  inside the Read/Edit/Write cap.
- `--model sonnet --fallback-model opus --effort medium` — pin the cheap companion (force 3).

The same `--dangerously-skip-permissions` rationale (force 1) applies to the non-interactive
`[session.self]` bringup commands (base `claude` and the `ccs` profile), which therefore also carry
the flag. The cross-cutting "non-interactive spawn must bypass the permission gate" invariant is
recorded as a hazard (`REQ-HAZARD-PSYCHE-PERMS-DEADLOCK`, `docs/KNOWN-HAZARDS.md` §2.2).

Rejected: launching the Psyche as a bare, unconstrained `claude` (the pre-2026-06-18 state). It gave
the unattended companion the full toolset *and* left it without skip-permissions — broader blast
radius and a latent detached-deadlock at once.

## Consequences

- The Psyche cannot perform non-file actions even if a prompt asks it to — by design. If a future
  Psyche capability genuinely needs a wider tool (e.g. to `git commit` its own context), that is a
  deliberate change to `sandbox_flags()` + this ADR, not an accident.
- `--dangerously-skip-permissions` reads alarming in isolation; it is safe **only** in combination
  with the tool cap. The two must move together — never widen the tools without re-justifying the
  auto-approve, and never drop the cap while keeping skip-permissions.
- These flags mirror legacy owl **verbatim**. If a future Claude Code renames `--tools` /
  `--disable-slash-commands`, the Psyche turn breaks — but that risk is shared with the proven
  sibling, and surfaces loudly (no commune produced).
- `doc`-stage evidence for `REQ-SKILL-LIVE` (the Psyche runner) and `REQ-HAZARD-PSYCHE-PERMS-DEADLOCK`
  (the deadlock invariant). `unit` evidence is the
  `every_turn_is_sandboxed_to_legacy_owl_parity` test plus the manifest assertion on the two
  `[session.self]` commands.
- The shipped `dist/*.spt` still embed the pre-sandbox psyche binary; they pick this up on the next
  release rebuild (held for a versioned release).
