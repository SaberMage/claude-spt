# v0.9.0 — D1: hook logic → `claude-spt hook <event>` (static-forever hooks.json)

> JIT plan. The DEFERRED-D1 milestone (UNIFY-CONSOLIDATE-PLAN §D1 / ADR-0006 ask #1).
> Goal: move all hook **logic** out of the cplugs plugin shell and into the consolidated
> `claude-spt` binary, so hook churn rides `spt adapter update` (NOT a cplugs republish).
> The plugin `hooks.json` + a thin dispatch wrapper become **static-forever**.

## Design (locked — ADR-0006, UPDATE-NAMING-DOYLE-ASKS Ask 1 → RESOLVE-NOT-EXECUTE)

spt-core stays a pure resolver (executes no new thing). Two v0.16.0 primitives carry D1 — BOTH
verified live on this node's spt 0.16.0 (throwaway probe-d1 adapter, 2026-06-28):
- **(a) `{adapter_dir}` / `{adapter_name}` substitution keys.** `get-string` of a `[strings]` value
  containing `{adapter_dir}` returns the install dir path. Confirmed: `hook_cmd = "{adapter_dir}/claude-spt hook"`
  → `<install_dir>/claude-spt hook`.
- **(b) lazy substitution inside `[strings]` at `get-string` read time** (adapter-static keys only;
  session-scoped `{session_id}` NOT available there — hooks still read those from CC stdin).

### Components

1. **`tools/claude-spt/src/hook.rs`** (NEW) — `claude-spt hook <event>` subcommand. Reads the event
   name from argv + the CC hook payload JSON from stdin; shells `spt api …`; emits additionalContext.
   Faithful port of all 8 hook wrappers + `_common.sh` (pure helpers → pure fns with unit tests;
   impure resolvers → `spt`-spawning fns). **Behaviour-preserving refactor**: same `spt api` command
   lines, same stdout contract per event (SessionStart = `hookSpecificOutput` JSON; UPS/PreToolUse =
   raw rendered text), same no-op-when-no-perch.
2. **`tools/claude-spt/src/main.rs`** — add `Sub::Hook`; dispatch `hook` → `hook::run()`.
3. **`plugin/sptc/hooks/dispatch.sh`** (NEW, static-forever) — the only plugin-resident hook shell.
   - SessionStart only: run `bootstrap.sh` first (invisible installer — the binary CANNOT exist before
     spt-core + the adapter are installed), then cache the resolved bin to `$CLAUDE_ENV_FILE`.
   - Resolve bin: `$SPTC_HOOK_BIN` (cached) → else `spt adapter get-string claude-spt hook_cmd`.
   - No-op (exit 0) if unresolvable (adapter not registered yet = pre-/sptc:setup window).
   - Pass `--host-pid "$PPID"` (the seed pid — Rust std has no portable getppid on Windows) and the
     event; the binary reads CC stdin directly (dispatch does NOT cat, so stdin passes through clean).
4. **`plugin/sptc/hooks/hooks.json`** — static-forever: every event → `sh dispatch.sh <event>`.
5. **`adapter/claude-spt.toml`** — add `[strings] hook_cmd = "{adapter_dir}/claude-spt hook"`;
   version → 0.9.0; min_spt_core stays 0.16.0 (primitives already shipped there); `[hooks.*]` comments
   note the binary handler.
6. **Delete** the 8 `*.sh` hook wrappers + `_common.sh` (logic now in the binary). **Keep** `bootstrap.sh`.
7. **Tests** — port `tests/hooks-parse.sh` coverage into `hook.rs` `#[cfg(test)]` (runs under
   `cargo test`, the digest-extractor gate). Replace `tests/hooks-parse.sh` with a thin
   `tests/hooks-dispatch.sh` (hooks.json static shape + dispatch wrapper sh -n + referenced files exist).
8. **traceable-reqs.toml** — add `REQ-DIST-HOOK-BINARY` (doc/impl/unit), activate; retag the migrated
   REQ evidence (REQ-DIST-HOOKS-API / REQ-UPS-INJECTION / REQ-DIST-* unit tags now point at hook.rs).
9. **cplugs skeleton** — STRUCTURAL change (hooks.json rewrite + .sh removal + dispatch.sh add) →
   `plugin.json` sptc 0.1.7 → 0.1.8.

### Bootstrap / no-op invariant (the one behavioural nuance)

A session that ran the spt-core bootstrap but is BEFORE `/sptc:setup` (adapter not yet registered)
has no `{adapter_dir}/claude-spt` → dispatch no-ops. Today's shell `api seed` would run there; the
binary path won't. Acceptable: a seed for an UNregistered adapter is unusable (ready/live resolve the
adapter by host_binaries from the registered set). Next session post-setup seeds normally. No real-world
regression (the perch was already a no-op pre-readiness today).

## Gate

`sh ci/run-gates.sh` green (shell-syntax, cargo test+build incl. new hook tests, traceable-reqs check,
skeleton-validate, manifest-schema) + a local idle/digest-proof dogfood of the repacked binary.

## Release (see it through — docs/RELEASE-RUNBOOK.md)

CHANGELOG `## [0.9.0]` · build win + linux (zigbuild) · `package-adapter.sh --apply` · gh release
v0.9.0 on SaberMage/claude-spt with `dist/adapter.spt` · cplugs sptc 0.1.8 push. gh = SaberMage
(repo+workflow scopes) — publish is doable from this node.

## Status: BUILT + GATES GREEN (2026-06-28, perri) — releasing

- hook.rs (8 events + _common.sh ported), main.rs `hook` dispatch, dispatch.sh, static hooks.json,
  [strings].hook_cmd, 8 wrappers + _common.sh deleted. All default gates PASS (89 cargo tests,
  traceable-reqs green incl. new REQ-DIST-HOOK-BINARY doc/impl/unit, msys-hazard reworked, docs-drift).
- Adapter.spt repacked (win + linux); translate-proof + digest-proof + hook subcommand dogfooded from
  the extracted binary. CHANGELOG [0.9.0], plugin.json sptc 0.1.8, manifest 0.9.0.
- poll-int live binary-drain e2e blocked on THIS node (2 subnets → bind needs --subnet); covered by
  hook.rs unit tests + live skill-injection dogfood. Live full-perch e2e stays in the deferred
  harness-glue bucket (needs single-subnet/real-CC node). registration-int 4c reworked to the binary
  (not run live here — would soft-deregister the live node's adapter).
- Remaining: commit · tag v0.9.0 + push · gh release w/ dist/adapter.spt · cplugs sptc 0.1.8 push.
