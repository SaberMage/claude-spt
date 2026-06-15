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

### `api poll` frame format — the parse contract (provided by doyle from `spool.rs`)

> Provided by the spt-core owner (grounded in `spt-store/src/spool.rs`); **pending** canonical
> publish to the adapter-facing docs-site and **pending our throwaway-session confirm** of the
> binary's actual stdout (F-001 residual). Implement the wrapper parser against this:

`api poll` prints **one message per drained frame** to stdout. Each frame:

- **Named sender:** `__REPLY_TO__:<from_id>\n<body>` — line 1 is the literal header `__REPLY_TO__:`
  followed by the sender id; the remaining lines are the message body.
- **Anonymous sender** (`from_id == ""`): the **bare body**, no header.

The adapter parses the `__REPLY_TO__:<sender>` header to recover the reply target, then renders the
message for CC. **`__REPLY_TO__` is load-bearing** — it is the reply-correlation used by the access
gate (`ADR-0009`) and Psyche routing (`ADR-0012`, both spt-core). We therefore **preserve the
sender** in the CC rendering (e.g. `<owl_messages from="<sender>">…</owl_messages>`, mirroring
legacy), never silently strip it, so reply-correlation survives the harness boundary.

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

## Open (validate empirically in a throwaway session — never on the live perch)

1. **`UPS-fires-on-/sptc:X`** — confirm `UserPromptSubmit` fires when the prompt is a `/sptc:`
   slash-command (the UPS-injection design assumes it). The CC hooks reference lists
   UserPromptSubmit as "Always fires" — strong evidence — but slash-command routing is the exact
   thing SCOPE flagged to confirm empirically. Throwaway session, trivial echo hook.
2. **Wrapper packaging + Windows shell.** Handlers parse CC stdin JSON → `api` flags (no jq
   guarantee; POSIX `sh` via `sed`/`grep`, PowerShell via `ConvertFrom-Json`). hooks.json cannot
   OS-branch, so resolve: `"shell": "bash"` (needs git-bash on Windows) vs a single portable entry.
   Validate on real CC (does `$CLAUDE_PLUGIN_ROOT` + the chosen shell resolve on Windows?).
3. **`api poll` actual stdout bytes** — capture in the throwaway run; send to doyle to confirm-match
   his canonical docs publish (no drift).

## Consequences

- `REQ-DIST-HOOKS-API` / `REQ-UPS-INJECTION` gain a concrete, grounded `doc` design here; their
  `impl` activates when the validated `hooks.json` + wrappers land (gated on Open #1).
- Supersedes the `ADR-0001` "hooks.json delegates to `spt api`" stub with the full wiring; ADR-0001's
  UPS-injection open item (UPS-fires empirical) is carried here as Open #2.
- No spt-core dependency for the wiring itself — only the (non-blocking) residual docs publish of the
  `api poll` frame format, which we can substitute with observed behavior until it lands.
