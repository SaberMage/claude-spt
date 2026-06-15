<!-- [doc->REQ-DIST-HOOKS-API] -->
<!-- [doc->REQ-UPS-INJECTION] -->
# Hook wiring: the sptc plugin hand-writes a CC `hooks.json` that shells `spt api`

## Status

accepted (2026-06-15) · grounds the F-001 resolution (`docs/SPT-CORE-FINDINGS.md`)

## Context

spt-core is **harness-independent** (`CONTEXT.md` L52/L181): it supplies the agnostic `spt api`
primitives + their I/O format; the **adapter** authors the harness-specific wiring and output
formatting (L112). Claude Code drives hooks via a `hooks/hooks.json` whose handlers receive a JSON
payload on **stdin** and may return `additionalContext`. `spt api` primitives are observable on the
public 0.6.0 binary (flags confirmed via `--help`); every call requires `--adapter claude-spt`
(the adapter_name — distinct from the plugin name `sptc`).

Two hard constraints shape the wiring:

1. **`api listen` blocks** ("consume a seed and hold the perch + relay loop (blocks)"). It therefore
   **cannot** run from `SessionStart` — that would hang CC startup. `listen` belongs to an explicit,
   backgrounded `/sptc:ready` / `/sptc:live` invocation (as legacy did).
2. **spt-core must not materialize a CC `hooks.json`** — doing so would be CC-catering, violating
   L52/L181. The plugin hand-writes it.

## Decision

**The `sptc` plugin ships a hand-written `plugin/sptc/hooks/hooks.json` whose handlers shell out to
`spt api --adapter claude-spt <subcommand>`.** Hook params are sourced from CC's native hook input
(stdin JSON / process), mapped by a thin adapter wrapper — *not* by spt-core `{placeholder}`
substitution (that is the spt-hosted-bringup path, where spt-core itself spawns the command).

### CC-event → `spt api` mapping (authored adapter glue)

| Claude Code hook | `spt api` (all prefixed `--adapter claude-spt`) | Notes |
|---|---|---|
| SessionStart (`startup`/`resume`) | `seed --pid <pid> --session-id <sid>` + write env aliases via `$CLAUDE_ENV_FILE` | non-blocking; records the pid↔session seed |
| SessionStart (`clear`/`compact`) | `boundary <clear\|compact> <id> --to-session-id <sid>` | rebind perch, preserve identity |
| UserPromptSubmit | `poll <id>` → stdout → `additionalContext` | the message-delivery + UPS-injection path (L149) |
| Stop | `state idle <id>` | arms echo-gate fallback (L137) since Stop can't inject |
| (activity) | `state busy <id>` | on prompt/tool start |
| SubagentStart / SubagentStop | `worker-start <parent> <id>` / `worker-stop <id>` | nested worker perches |
| SessionEnd | `session-end <id>` | soft teardown; `shutdown <id>` on graceful signoff |
| PreToolUse | — | **out of scope v1** (UPS covers delivery) |

`api listen <id>` is launched by `/sptc:ready` / `/sptc:live` as a backgrounded blocking poll loop,
**not** from a hook.

### Skill instructions (UPS-injection) ride the same UserPromptSubmit hook

The `UserPromptSubmit` hook's stdout becomes CC `additionalContext`. The same channel that delivers
queued messages (`api poll`) is where `/sptc:X` skill-instruction injection lands (from the adapter
`[strings]`, M12-dep). `api poll` emitting to stdout is by design (L149); formatting it for CC is
ours. PTY/relay inject methods are M3 roadmap (M2a = stdout/hook only) — not a gap.

### `api poll` parse contract — the `<EVENT>` envelope (ADR-0020, operator-ruled 2026-06-15)

> **Supersedes** the earlier `__REPLY_TO__` framing (a mis-elevated relic, now deleted from
> spt-core — see `docs/SPT-CORE-FINDINGS.md` F-002, resolved-by-design). Confirmed by doyle as the
> deliberate poll-surface contract (ADR-0020 §1). **Transitional:** the current 0.6.0 binary still
> emits the `__REPLY_TO__` relic at poll until `REQ-MSG-ENVELOPE` ships; build to `<EVENT>` but
> validate against poll only post-refactor.

The **canonical format at every surface, including `api poll`, is the `spt-proto::event` envelope**
(the ADR-0001 grammar the live listener already emits):

- **One whole, single-line `<EVENT type="msg" from="<sender>">body</EVENT>` per message.** Interior
  newlines are `<br>`-escaped, so the envelope never breaks across lines.
- **Self-delimiting** → a multi-message drain splits cleanly on `</EVENT>` (no delimiter, no
  `F-002` ambiguity).
- **No `<EVENT-PART>` chunking at the poll surface** (doyle Q2): `poll`/`worker-poll` emit whole
  `<EVENT>`s. `<EVENT-PART seq="N/M">` exists only for the *listener stream* (the `« spt event »`
  Monitor's ~500-char `EVENT_LINE_THRESHOLD`); the hook-drain injects via `additionalContext` which
  has no per-line cap. **No id+seq reassembly on the poll path.**

Parser (`render_frames`, `plugin/sptc/hooks/_common.sh`): split on `</EVENT>`; per envelope, read
the `from` attr → `<sptc_messages from="<sender>">`, decode the body (`<br>` → newline, then entity
unescape `&lt; &gt; &quot;` then `&amp;` **last**). **Sender preserved** (reply-correlation: access
gate `ADR-0009`, Psyche routing `ADR-0012`), never silently stripped. Covered by
`tests/hooks-parse.sh` (named / entity / multi-message / no-from / empty).

**Harness injection-size limit is ours** (harness-agnostic boundary — spt-core emits whole
`<EVENT>`s regardless): CC `additionalContext` caps at **10,000 chars** (larger output is spilled to
a file by CC). A large multi-message drain can exceed it → adapter-side follow-up: truncate with a
marker or spill. (`REQ-UPS-INJECTION` `int` item.)

### Portability

Handlers must map CC stdin JSON → `api` flags. The plugin ships **no binary**, so the mapping is a
thin portable wrapper (POSIX `sh` + PowerShell), selected per-platform. Exact wrapper packaging is
settled during impl (see Open).

### Hook-side id-resolution — RESOLVED (observed on the 0.6.0 binary)

`spt whoami` "Print this session's own perch id. **Resolved from `$OWL_SESSION_ID` /
`$SPT_AGENT_ID`.**" That is the id-resolver: the per-prompt hooks do not need a positional `<id>`
threaded in — they resolve it from the session env. Wiring:

- **SessionStart** writes the session env via `$CLAUDE_ENV_FILE`: `OWL_SESSION_ID=<session_id>`
  (from the hook stdin) + `SPT_ADAPTER=claude-spt`. (It also runs the bootstrap and `api seed`.)
- **Per-prompt hooks** (UserPromptSubmit/Stop/SessionEnd) resolve `id="$(spt whoami)"`; if empty
  (session never readied → no perch), they no-op. Auth: pass `--session-id "$OWL_SESSION_ID"`
  (`poll`/`state`/`session-end` all accept `--session-id` as the association proof — observed) so
  no capability token is needed from the hook.

The frame contract is corroborated at the binary level too: `spt send --from <FROM>` = "Sender id
**written into `__REPLY_TO__`**" — matching the `spool.rs` frame doyle provided.

## Validation results (throwaway `claude -p` session, 2026-06-15)

Ran an isolated temp-project rig (UserPromptSubmit marker hook + a registered `/send` project
skill) on the real CC 2.1.177 binary:

- ✅ **UPS fires on a `/`-slash-command.** `MSYS_NO_PATHCONV=1 claude -p "/send hi"` → the hook
  received `prompt:"/send hi"` (literal) **and** fired **and** the skill ran. Answers the
  SCOPE-flagged question: `UserPromptSubmit` fires on a `/sptc:X` invocation with the token intact,
  so the wrapper can detect `/sptc:X` in `prompt` and inject. (`REQ-UPS-INJECTION`.)
- ✅ **Windows `shell:"bash"` command hooks work** — the hook executed via Git-Bash,
  `$CLAUDE_PROJECT_DIR` resolved, exit-0 stdout honored. Resolves Open#2 for the POSIX-wrapper
  packaging on Windows (no per-OS branch needed for the hook to run).
- ✅ **Hook stdin schema confirmed**: `{session_id, transcript_path, cwd, permission_mode,
  hook_event_name, prompt}` — `json_str` targets the right fields; `session_id` sourcing confirmed.
- ⚠️ **MSYS `/`-arg mangling** observed (run A): a `/send` passed as a Git-Bash *argument* became
  `C:/Program Files/Git/send`. Test artifact (wrappers read stdin, not argv) but a real Windows
  hazard → `docs/KNOWN-HAZARDS.md` 1.1 + `REQ-HAZARD-MSYS-PATHCONV` (test: `tests/msys-hazard.sh`).

## Open / resolved `int`

1. **`api poll` → `additionalContext` round-trip — RESOLVED (v0.7.1, 2026-06-15).** ADR-0020 shipped
   in v0.7.1; a throwaway byte-capture against the live `spt api poll` drain (`od`-verified) confirmed
   the canonical `<EVENT type="msg" from=…>body</EVENT>\n` envelope (no `__REPLY_TO__`, no
   `<EVENT-PART>` on normal drains, multi-drain splits on `</EVENT>`), and `render_frames` confirm-
   matched it. Locked by `ci/hooks/poll-int.sh` (5/5); `REQ-DIST-HOOKS-API` + `REQ-UPS-INJECTION`
   `int` flipped green. See `docs/SPT-CORE-FINDINGS.md` F-002.
2. **Large-drain injection size** — CC `additionalContext` caps at ~10k chars; add truncate/spill in
   the UPS wrapper (adapter-side; still open, lower priority — normal drains are well under the cap).

## Consequences

- `REQ-DIST-HOOKS-API` / `REQ-UPS-INJECTION` gain a concrete, grounded `doc` design here; their
  `impl` activates when the validated `hooks.json` + wrappers land (gated on Open #1).
- Supersedes the `ADR-0001` "hooks.json delegates to `spt api`" stub with the full wiring; ADR-0001's
  UPS-injection open item (UPS-fires empirical) is carried here as Open #2.
- No spt-core dependency for the wiring itself — only the (non-blocking) residual docs publish of the
  `api poll` frame format, which we can substitute with observed behavior until it lands.
