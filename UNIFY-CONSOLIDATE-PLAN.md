# UNIFY-CONSOLIDATE-PLAN.md — JIT plan (doyle-independent prep)

> The next milestone: everything in ADR-0005 (name unification) + ADR-0006 (one-command update +
> consolidated binary) that ships **without** the three spt-core asks. doyle rolls the spt-core build
> (the asks) in parallel; this plan is the work we own meanwhile. Authored 2026-06-24 (perri).
> Companions: `docs/adr/0005-name-unification.md`, `docs/adr/0006-one-command-update-and-consolidated-binary.md`,
> `UPDATE-NAMING-DOYLE-ASKS.md`. Target release: **adapter v0.8.0**.

## Scope

Five doyle-independent tasks (U1–U5). They make the adapter one-lever-*shaped* and consolidate its
binaries, so that when the asks land the remaining wiring (D1–D3) is small. The plugin `sptc`→`spt`
succession (D4) stays gated on **owl retirement**, not doyle — out of this milestone.

## Tasks (doyle-independent)

### U1 — `[update].message` (quick win, ship first) · REQ-DIST-UPDATE-MESSAGE (mint)
- Add `message` to manifest `[update]` (the field is docs-confirmed; prints markdown on a real apply only).
- Copy: tell the user to run **`/reload-plugins`** (unavoidable TUI step) and point at the **`spt`** CLI
  (`spt endpoint run`) as the more powerful endpoint route, alongside `/spt:live`. (Use the operator's
  example phrasing.)
- Gate: `spt adapter update` prints it on a version apply; schema-validates.

### U2 — Binary consolidation, partial · REQ-DIST-BINARY-CONSOLIDATE (mint)
- Merge `claude-spt-digest` + `claude-spt-psyche` into **one `claude-spt` crate** with clap subcommands
  `digest` / `psyche`; add a `post-update` subcommand = the **plugin-sync** logic (detect `claude` vs `ccs`
  CLI → check cplugs marketplace, add if missing → `claude plugin add|update <plugin>` → print the notice;
  it does NOT run `/reload-plugins`). Standalone-runnable + unit-tested NOW even though `[update]` can't
  invoke it until ask #2 lands.
- Keep `cc-spt-idle-translate` separate (folds in at D3, after ask #3).
- Update manifest `[digest].extractor` → `claude-spt digest …`, `[session.psyche_init].command` →
  `claude-spt psyche …`.
- Update `ci/publish/package-adapter.sh` (binary set per triple: `claude-spt` + `cc-spt-idle-translate`),
  `ci/{digest,psyche}/build.sh` → one build, and the proof-ints.
- Gate: all subcommand tests green; digest-proof + (existing) translate-proof green; archive packs the 2
  binaries per triple.

### U3 — Name unification: repo rename + references · REQ-DIST-NAME-UNIFY (mint)
- Rename GitHub repo `spt-claude-code` → `claude-spt`. Update `[update].repo`, README, CI, package scripts,
  every `SaberMage/spt-claude-code` reference, and the install-dir assumptions in tests
  (`adapters/_github/SaberMage-claude-spt`).
- Adapter name `claude-spt` UNCHANGED. Plugin `sptc` UNCHANGED this milestone (succession = D4, owl-gated).
- Gate: a clean `spt adapter add --release SaberMage/claude-spt` re-acquires + runs on-node; `--release`
  + `update` both read `claude-spt`.

### U4 — Thin the reactive skills · REQ-DIST-SKELETON-THIN (mint)
- Move `commune`/`send`/`signoff` bodies OUT of the plugin SKILL.md (stubs: frontmatter + "live agents
  only — `/spt:live` first") and INTO adapter strings: a new **perched SessionStart brief** string
  (commune incl. **`--checkpoint`**, signoff) + the existing `/spt:live` UPS body for the go-live moment.
- Solve the delivery-timing wrinkle: perched brief fires on bind|boundary; `/spt:live` UPS body covers a
  seed→live transition (confirm whether going live re-surfaces a brief; if not, the UPS body is the path).
- Gate: a perched session's SessionStart additionalContext carries commune/checkpoint/signoff guidance;
  reactive-skill prose now rides `spt adapter update`.

### U5 — README install UX + agent-prompt skin · REQ-DIST-INSTALL-UX (mint)
- Platform-specific install chains (cmd / PowerShell / bash): check-for / install spt-core (claude-spt may
  be a user's first spt-core exposure → call the spt-releases per-platform install script), then
  `spt adapter add --release SaberMage/claude-spt`.
- A copy-paste **agent prompt** (the casual-user skin) that runs the install chain in one sequenced Bash
  call. Symmetric with the update lever (`spt adapter update claude-spt`).
- Gate: docs build / llms.txt in sync; the chains are copy-paste-correct per OS.

### U6 — `{id}`-name + RC channel on BOTH bringup paths · REQ-DIST-RC-STARTUP (mint)
- Thread `{id}` into BOTH the session display name and the RC channel, on BOTH `[session.self]` (fresh
  bringup) and `[session.resume]`, so a fresh and a resumed endpoint are identified + controlled
  identically. Two real CC flags (verified via `claude --help`):
  - **`-n {id}`** (`--name`, "set a display name for this session, shown in the prompt box / `/resume`")
    — add to **both** `[session.self]` and `[session.resume]` (currently on neither).
  - **`--remote-control {id}`** (RC channel name) — add to `[session.self]` (currently only on
    `[session.resume]`).
- Resulting commands:
  - `[session.self].command = "claude -n {id} --remote-control {id} --dangerously-skip-permissions"`
  - `[session.resume].command = "claude -r {session_id} -n {id} --remote-control {id} --dangerously-skip-permissions"`
- `{id}` is already in `[session.self].keys = ["id"]` and `[session.resume].keys = ["session_id","id"]` —
  no keys change for the `{id}`-only form. Small, standalone manifest edit (like U1), doyle-independent.
- **STRETCH (doyle ask #4, operator-raised): `{id}@{node}`.** Ideal display/RC name is `{id}@{node}` so a
  same-id endpoint on different machines is distinguishable. The substitution-key catalog is now PUBLISHED
  (harness-contract/manifest.html#substitution-keys) and `{node}` is confirmed ABSENT; `{session_name}`
  exists but is the *supplied* name (circular). Operator is raising a `{node}` fill key with doyle directly.
  Ship the `{id}`-only form now; upgrade to `{id}@{node}` (add `node` to both `keys`) once doyle adds it.
- Open: confirm `-n {id}` + `--remote-control {id}` coexist cleanly with the `$SPT_ENDPOINT_ID` env path
  on a fresh launch (env names the bind id at SessionStart; `-n`/RC name the display+control channel —
  no conflict expected). spt tokenizes-then-fills, so each flag is a clean argv element.
- Gate: a fresh `spt endpoint run` endpoint shows `{id}` as its display name and is `spt rc <id>`-attachable;
  idle delivery + checkpoint still fire (re-run the on-node translate/checkpoint dogfood with the flags present).

## Deferred (doyle-gated — land when the asks ship; NOT this milestone)
- **D1** generic `hooks.json` + `claude-spt hook <event>` subcommand ← ask #1 (`spt api run-hook`).
- **D2** wire `[update]` composite to invoke `claude-spt post-update` (the subcommand U2 prepped) ← ask #2.
- **D3** fold `translate` into `claude-spt translate` + retire `cc-spt-idle-translate` ← ask #3.
- **D4** plugin `sptc`→`spt` succession (`/spt:*`) ← owl retirement gate (separate from doyle).

## Sequencing
- U1 + U6 first (isolated one-line manifest changes, quick wins). Then U2 (the big refactor; preps the
  post-update subcommand for D2).
- U3 after U2 (both touch `package-adapter.sh`); batch them into the v0.8.0 cut. Rename the repo as part
  of cutting v0.8.0 so the new release lands on `claude-spt` (v0.7.0 stays on the redirected old slug).
- U4 / U5 parallel-able with U2/U3.
- Cut **v0.8.0** once U1–U5 green (bump adapter version; cplugs skeleton bump for the thinned stubs/new
  hooks.json only if structural).

## Open questions
- Repo rename vs the v0.8.0 release ordering (rename-then-cut, confirmed above — watch the install-dir
  break for the one existing install: a re-add covers it).
- `post-update` plugin-sync: exact `claude` vs `ccs` detection + idempotency + what it prints.
- Reactive-brief split: does `/spt:live` re-fire a SessionStart brief, or is the UPS body the only go-live
  delivery? (Empirical check.)
- Whether the cplugs skeleton needs a bump this milestone at all (U4 thins SKILL.md = structural → likely
  one bump; U1–U3 are adapter-side).

## Validation gate (per AGENTS.md)
- `cargo build` + all crate tests green (consolidated binary); `sh ci/run-gates.sh` green.
- `traceable-reqs check` green — REQs minted in `traceable-reqs.toml` FIRST, evidence tagged in-commit.
- On-node dogfood: `spt adapter add --release SaberMage/claude-spt` re-acquires + digest/translate-proof
  the consolidated binary; `spt adapter update` prints `[update].message`.
- v0.8.0 release cut (adapter `.spt` + cplugs skeleton if structural).
