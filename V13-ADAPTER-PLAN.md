# V13-ADAPTER-PLAN — build the two v0.13.0 harness-contract seams ahead of the binary

> **Scope.** spt-core's v0.13.0 harness contract is PUBLISHED (sabermage.github.io/spt-releases/
> harness-contract) ahead of the v0.13.0 binary (still v0.12.x on spt-releases). Build + structure
> the two new RUN-group adapter seams against the contract NOW; defer the runtime dogfood (`int`) to
> the v0.13.0 daemon. Public-surface-only (AGENTS.md): the contract pages are the authority.

## Seams

### 1. `[session.resume]` — native-resume (REQ-DIST-SESSION-RESUME)
- CC verb: `claude -r {session_id} --remote-control {id} --dangerously-skip-permissions`,
  keys `["session_id","id"]`. Both flags verified real (`claude --help`: `-r/--resume`,
  `--remote-control [name]`).
- `{session_id}` reloads the real transcript; `{id}` = the remote-control session name (RC is the
  channel native-resume drives — same channel `spt rc` + the idle-translation-binary use). Omitting
  the role → silent fallback to `[session.self]` = blank fresh session (the documented footgun).
- PTY lands in the resumed session's recorded project cwd.

### 2. `[message-idle-translation-binary]` — idle PTY delivery (REQ-DIST-IDLE-TRANSLATE)
- `path = "cc-spt-idle-translate"` — Rust stdin→stdout JSON-lines filter (`tools/cc-spt-idle-translate`).
- Input: `{"type":"init",…}` (no output) · `{"type":"event","envelope":"<EVENT…>"}` · `{"type":"input"}` (no output).
- Output per event = the **choreography**:
  `{"key":"ctrl+s"}` · `{"delay_ms":50}` · `{"text":"<envelope>\r"}` · `{"commit":true}`
  (stash draft → submit line → terminate the inject sequence; CC auto-restores the draft after
  submit, so no trailing restore keystroke). The `\r` submits the line; `{"commit":true}` is the
  MANDATORY terminator — spt-core's `run_inject_worker` FAULTs at a 5s `INJECT_COMMIT_DEADLINE`
  without it (broker.rs:1075-1090, doyle-confirmed). The published contract had **dropped `{commit}`**
  from the vocabulary + degenerate example — a public-surface defect this blind-build caught; doyle
  is republishing manifest.md with `{commit}` documented.
- Idle-only; busy/mid-turn delivery stays the `[inject]` hook path. spt-core spawns on endpoint-up,
  reaps on down, applies keystrokes atomically (coexists with a live `spt rc` controller).

## Status — DONE (impl + unit)
- ✅ `tools/cc-spt-idle-translate` (Rust, 9 cargo tests green)
- ✅ `[session.resume]` + `[message-idle-translation-binary]` in `adapter/claude-spt.toml`
- ✅ `tests/manifest-shortcut.sh` (resume shape + 3rd skip-perms + idle path); `tests/adapter-archive.sh` (3rd binary at root)
- ✅ `ci/idle-translate/build.sh` wired into `ci/run-gates.sh`; packer packs the 3rd binary
- ✅ traceable-reqs: REQ-DIST-SESSION-RESUME + REQ-DIST-IDLE-TRANSLATE (`["impl","unit"]`); REQ-HAZARD-PSYCHE-PERMS-DEADLOCK extended to resume

## Int status (spt 0.13.1 / counter 28)
- ✅ **REQ-DIST-IDLE-TRANSLATE → int** (EMIT half): `ci/idle-translate/translate-proof-int.sh` — real
  `spt adapter translate-proof` spawns+feeds the binary daemon-identically, asserts `TRANSLATE_PROOF_OK`
  + `commit: yes` + the trailing `\r`. GREEN 2026-06-22. The `{commit}` fix (F-016) is exactly what
  the proof's no-commit gate guards.
- ⏳ **REQ-DIST-IDLE-TRANSLATE APPLY half** (atomic PTY + spawn-on-up/reap-on-down lifecycle): deferred —
  needs a real-claude bringup (translate-proof is EMIT-only, ADR-0022).
- ⏳ **REQ-DIST-SESSION-RESUME → int**: deferred — real-claude `endpoint run --resume` bringup
  (transcript reattach + RC drive). translate-proof does NOT cover resume. Static signals green on
  0.13.1 (role accepted, `--resume` flag present). Stays `unit`.
- `doc` for both: docs-site harness-contract RUN-group slice (documented in manifest/module comments meanwhile).

## Gate
`sh ci/run-gates.sh` green + `traceable-reqs check` green.
