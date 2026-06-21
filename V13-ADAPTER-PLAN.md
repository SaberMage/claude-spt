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
- Output per event = the **operator choreography**:
  `{"key":"ctrl+s"}` · `{"delay_ms":50}` · `{"text":"<envelope>\r"}`
  (stash draft → submit message; CC auto-restores the draft after submit, so no trailing restore
  keystroke — an inbound message never eats a half-typed draft).
- Idle-only; busy/mid-turn delivery stays the `[inject]` hook path. spt-core spawns on endpoint-up,
  reaps on down, applies keystrokes atomically (coexists with a live `spt rc` controller).

## Status — DONE (impl + unit)
- ✅ `tools/cc-spt-idle-translate` (Rust, 9 cargo tests green)
- ✅ `[session.resume]` + `[message-idle-translation-binary]` in `adapter/claude-spt.toml`
- ✅ `tests/manifest-shortcut.sh` (resume shape + 3rd skip-perms + idle path); `tests/adapter-archive.sh` (3rd binary at root)
- ✅ `ci/idle-translate/build.sh` wired into `ci/run-gates.sh`; packer packs the 3rd binary
- ✅ traceable-reqs: REQ-DIST-SESSION-RESUME + REQ-DIST-IDLE-TRANSLATE (`["impl","unit"]`); REQ-HAZARD-PSYCHE-PERMS-DEADLOCK extended to resume

## Deferred — `int` (GATED on v0.13.0 daemon — doyle pings on ship)
- Native-resume launch: real `--resume` reloads the transcript + RC drive → add `int` to REQ-DIST-SESSION-RESUME.
- Idle-translation lifecycle: spawn-on-up / reap-on-down + atomic PTY apply → add `int` to REQ-DIST-IDLE-TRANSLATE.
- `doc` for both: docs-site harness-contract RUN-group slice (documented in manifest/module comments meanwhile).

## Gate
`sh ci/run-gates.sh` green + `traceable-reqs check` green.
