# spt-claude-code — agent working rules

> **Canonical source of truth for how agents work in this repo.** Harness-agnostic:
> Claude Code reads it via the one-line `CLAUDE.md` (`@AGENTS.md`); other harnesses read
> this file directly. Edit working rules HERE, never in `CLAUDE.md`.

## Public-surface-only constraint (read first)

You build `spt-claude-code` against **only the published public surface of spt-core**:
`SaberMage/spt-releases` (the `spt`/`spt.exe` binary, install scripts, `mock-adapter`
source, `manifest.schema.json`) and the GitHub Pages docs at
`https://sabermage.github.io/spt-releases` (mental model, quickstarts, harness-contract +
CLI reference, rustdoc, `llms.txt` / `llms-full.txt`). **Never read the `spt-core` source
tree.** Proving the adapter contract is buildable from the public surface alone is the entire
point of this project. If a capability you need is missing from the public docs/releases,
that is a **finding to report** (spt-core's published contract has a gap) — not a reason to
reach into spt-core source to work around it. (See `HANDOFF.md` §1.)

`spt-claude-code` is the rebuilt Claude Code harness adapter (`claude-spt`) — spt-core's v1
acceptance proof, its first casual-end-user entrypoint (a CC plugin), and an invisible
spt-core installer.

**Orientation — read before working:** `SCOPE.md` (decision ledger, authoritative for
what/why), `HANDOFF.md` (build orientation + the hard public-surface-only constraint),
`CONTEXT.md` (glossary/model, authoritative for meaning), `docs/adr/` (decisions),
`docs/KNOWN-HAZARDS.md` (invariants we must not re-break), `docs/{DOCS-STRATEGY,TRACEABILITY}.md`.

## Requirement traceability (binding)

This project uses [`traceable-reqs`](https://github.com/BigscreenVR/traceable-reqs)
(`traceable-reqs.toml` = the authoritative `REQ-*` registry). The full contract is
`docs/TRACEABILITY.md`. The rules you must follow:

1. **Tag evidence in the same change.** When you write a function/test/doc-section that
   satisfies a requirement stage, add its tag in that same commit:
   `// [impl->REQ-FOO]` · `// [unit->REQ-FOO]` · `<!-- [doc->REQ-FOO] -->`
   Stages: `doc` / `impl` / `unit` / `int`. Tag *on or immediately above* the real
   evidence — never at file tops to satisfy coverage.
2. **Run `traceable-reqs check` before declaring work done.** Exit-1 means missing/invalid
   evidence — fix it, don't ship it.
3. **New requirement → add it to `traceable-reqs.toml` first** (with a `REQ-*` id), then
   satisfy it. No untracked work; no untagged evidence.
4. **KNOWN-HAZARDS are `REQ-HAZARD-*` requirements** — each needs a test before it's
   "covered." Treat the hazard list as a conformance checklist you must satisfy, not advice.
5. **Activate, don't pre-fail.** Requirements you aren't yet working stay
   `required_stages = []`. Activate (set real stages) only when starting the milestone that
   delivers them.

## Other conventions

- Match surrounding code style. spt-claude-code consumes spt-core's **published** manifest
  contract (`manifest.schema.json` from `spt-releases`) — validate your manifest against it.
  Do **not** copy spt-core internals: build against the public surface only.
- Honor every `docs/KNOWN-HAZARDS.md` invariant — these are real bugs already paid for once
  (or hazards you have committed to never introduce). Each is a `REQ-HAZARD-*` with a test.
- Docs are dual-audience (human + AI dev-agent) per `docs/DOCS-STRATEGY.md`; doc generation
  is CI-gated against drift.
- Commit messages end with the project's co-author trailer:
  `Co-authored by: <your live agent name>` (e.g. `Co-authored by: perri`).

## Plans and context hygiene

- **JIT plans.** Plan the next immediate body of work just-in-time (a short `*-PLAN.md`),
  not the whole project up front. A plan names scope, open design questions, tasks, and the
  gate (build + `traceable-reqs check` green).
- If you finish a significant body of work without need for user intervention, or if your
  context gets too high, you can clear your own context and keep moving:
  1. Create a JIT plan for the next immediate body of work, if it isn't already planned.
  2. If you are a live agent: commune immediate next steps + a broad project-status/end-goal
     summary, then clear.
