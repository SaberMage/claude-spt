# Handoff to perri — building `spt-claude-code`

Welcome, perri. You own `spt-claude-code`: the Claude Code harness adapter for the SPT
ecosystem. This document orients you, states your hard constraints, and points you at the
detailed spec. Read it fully before writing anything.

---

## 1. THE HARD CONSTRAINT — read this first

**You build `spt-claude-code` using ONLY the published public surface of spt-core:**

- **`SaberMage/spt-releases`** — the release artifacts (the `spt`/`spt.exe` binary, install
  scripts, `mock-adapter` source, `manifest.schema.json`).
- **The GitHub Pages docs** at `https://sabermage.github.io/spt-releases` — the mental model,
  quickstarts, the complete harness-contract reference, CLI reference, rustdoc, and the agent
  exports (`llms.txt` / `llms-full.txt`; append `.md` to any doc URL for raw markdown).

**You do NOT have, and must NOT use, the `spt-core` source repository.** That is the entire
point of this project: it proves the adapter contract is buildable from the public surface
alone. If something you need to build the adapter is missing from the public docs/releases,
that is a **finding** — report it (it means spt-core's published contract has a gap), do not
go reach into spt-core source to work around it.

**What you MAY read freely:** everything in *this* repo (`spt-claude-code/`). `SCOPE.md`,
`CONTEXT.md`, this file, and the future PRD/ROADMAP/ADRs are *your own project's* design — not
spt-core source. They describe spt-core features by their *public contract*, not internals.

---

## 2. PREREQUISITE GATE — do not start yet

`spt-claude-code` v1 acceptance = **legacy parity AND proof of spt-core's cross-subnet / PTY
features**. Those features (spt-hosted endpoint bringup via `spt endpoint run`, `spt rc`
cross-node PTY attach, file-backed adapter strings, `adapter:profile` fallback, subnet QR /
self-elevation, `whoami`→alias) are being delivered in **spt-core M12**, in progress now
(maintainer: todlando).

**You begin once full-fat M12 ships AND its docs publish to `spt-releases` GH Pages.** Until
then those capabilities aren't in the public surface you build against. Confirm M12 is
published before starting. (The operator will signal go.)

---

## 3. What `spt-claude-code` is

The `claude-spt` adapter. Three things at once:

1. **spt-core's v1 acceptance proof** — feature parity with legacy `claude_skill_owl` (today's
   shipped CC integration), delegating all core functionality to the `spt` binary. Parity is
   **user-facing feature parity, NOT a 1:1 port** — most legacy machinery now lives inside
   `spt` itself; you build the CC-specific shell only.
2. **spt-core's first casual-end-user entrypoint** — published as a Claude Code plugin on the
   `SaberMage/cplugs` marketplace, like legacy spt is today.
3. **An invisible spt-core installer** — for users who don't have spt-core, the plugin
   bootstraps it. This is the intended pattern for all casual-facing adapters.

---

## 4. How to build it — workflow

This project is instantiated **from the `experimplate` template** (the reusable workflow
scaffold — traceable-reqs gating, JIT plans, grill-with-docs, release + same-repo published
docs). The workflow you must follow:

- **Requirement traceability is binding.** Every requirement is a `REQ-*` in
  `traceable-reqs.toml`; tag evidence (`doc`/`impl`/`unit`/`int`) in the same commit; run
  `traceable-reqs check` (EXIT=0) before declaring work done; add a REQ before satisfying it;
  activate stages incrementally (don't pre-fail). See `docs/TRACEABILITY.md` (from experimplate).
- **JIT plans** — plan the next immediate body of work, not the whole project up front.
- **grill-with-docs** — keep `CONTEXT.md` (glossary) and `docs/adr/` current as decisions land.
- **Docs are same-repo** → GH Pages (mdBook, CI-gated against drift), reusing spt-core's docs
  theme. Releases are light (plugin publish + spt-core adapter-registry; **signing delegated to
  the `spt` binary** — you do NOT run a two-key signing runbook).

---

## 5. Parity target + REQ seed

The complete legacy inventory (claude_skill_owl v1.11.25: 7 CC hooks, 12 `/spt:*` skills, the
messaging/live-agent/working-perch surfaces, marketplace packaging, CC-specifics like JSONL
transcript parsing and parent-pid binding) is the parity reference. **It has been triaged**
into DROP / TRANSFORM / KEEP / ADD buckets in `SCOPE.md` → "Parity-trim". Seed your
`traceable-reqs.toml` from those buckets:

- **KEEP** (port the user-facing skill): `/live` `/commune` `/ready` `/send` `/signoff`
  `/force-stop` `/new-alarm` `/list-agents`.
- **DROP** (do not port): `/revive`, `/clear-psyche`, `/whoami` (skill), `/fork`,
  `amend-signoff`, Spine/Touch, legacy psmux Capsule, binary-handoff, the TCP/spool/registry
  internals (all now inside `spt`).
- **TRANSFORM**: Capsule → spt-hosted topology + the `cc` launcher; echo-commune JSONL → the
  `[digest]` extractor; psyche-sync → subnet/`/spt:setup`; doctor → `spt doctor`/setup-verify;
  working-perches → `api worker-*`.
- **ADD**: `/spt:setup`, `/spt:version`, subnet skills (create/join/show-code), profiles +
  strings + hints wiring, ccs profiles.

---

## 6. Locked architecture (full detail in `SCOPE.md`)

- **Distribution**: a thin marketplace **skeleton plugin** (namespaced `/spt:*` skill
  skeletons + `hooks.json` calling `spt api` + a SessionStart bootstrap that installs spt-core)
  on cplugs. The volatile bulk (the `spt` binary + the CC adapter manifest) is **spt-core-
  conducted**, not plugin files — so the plugin rarely needs a marketplace bump and never
  orphans. Updates: file-pull (real channel) + a cautionary `claude plugin update`.
- **Skill instructions**: a `UserPromptSubmit` hook detects `/spt:X` and injects X's real
  instructions as `additionalContext`, sourced from the adapter `[strings]` (file-backed, so
  the manifest doesn't bloat). SKILL.md files stay skeletons. (Verify empirically at build
  time that UPS fires on slash-commands — design assumes it does.)
- **ccs** = profile(s) under `claude-spt` (`claude-spt:glm`, …), NOT its own adapter — leaf-
  replaces the launch command + per-profile `~/.ccs` log dir. Ship profile *templates*; user
  supplies their own ccs config/keys.
- **`/spt:setup`** (needed because users install mid-session, no SessionStart fire): v1 paths
  = generate `cc`/`cc <id>` launcher · `.gitignore` it · create-subnet (QR) · if-installed
  branch (new/join/show-code) · legacy migration · OS-service register · ccs wiring. The `cc`
  launcher wraps `spt endpoint run` defaulted to claude-spt.
- **CI** = autonomous fleet (Windows + Linux), **no LLM in the gate loop**: deterministic
  gates (build, unit, `traceable-reqs check`, manifest-schema); acceptance = scripted
  orchestration spawning real `claude` sessions as the system-under-test; **spt messaging is
  the reporting bus** (dogfood). GH runners are not used. Trigger = git post-push hook →
  `$OWL send` a fleet runner-agent.

---

## 7. Acceptance bar (v1)

Legacy user-facing feature parity **AND** demonstrated cross-subnet + PTY-hosting proof:
- The KEEP skills work end-to-end under Claude Code (harness-hosted).
- spt-hosted mode works: `cc`/`spt endpoint run` brings up a CC endpoint in a broker PTY and
  the user attaches (local); `spt rc` attaches cross-node.
- The `[digest]` extractor surfaces a CC session correctly (carried criterion: **real-CC
  digest-proof** against a real `~/.claude` session JSONL).
- Plugin installs from cplugs, bootstraps spt-core on a clean machine, legacy users migrate.

---

## 8. Your calls / open items (from `SCOPE.md`)

- `/spt:setup` #9 (doctor/verify) — fold inline or defer? (operator left ambiguous)
- The `cc` launcher's exact flag set (must cover every terminal action of `spt endpoint run`).
- Whether to keep UPS-injection or fall back to in-SKILL.md instructions if UPS doesn't fire
  on slash-commands (empirical, build-time).

---

## 9. Pointers

- `SCOPE.md` — the full decision ledger (authoritative for what/why). **Start here after this.**
- `CONTEXT.md` — glossary (authoritative for meaning).
- Public spt-core surface — `SaberMage/spt-releases` + `https://sabermage.github.io/spt-releases`
  (incl. `llms.txt` / `llms-full.txt` for agent ingestion).
- experimplate — the template you instantiate from (workflow scaffolding + INSTANTIATE.md).
- spt-core M12 (your dependency, by its *published contract* only): `spt endpoint run`, `spt rc`,
  file-backed strings, `adapter:profile` fallback, subnet QR/elevation, `whoami`→alias.

Build from the public surface. If the public surface can't build it, that's the bug — report it.
— doyle (scoping, 2026-06-14)
