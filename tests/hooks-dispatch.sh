#!/bin/sh
# Unit coverage for the STATIC-FOREVER plugin hook surface (D1). The hook LOGIC now lives in the
# `claude-spt` binary and is unit-tested there (tools/claude-spt/src/hook.rs cargo tests — the port of
# the old tests/hooks-parse.sh helper coverage). What remains in the PLUGIN is static-forever wiring:
# hooks.json routes every CC event to dispatch.sh, and dispatch.sh resolves+execs the binary. This
# test pins that wiring + the adapter-side declarations it depends on.
# [unit->REQ-DIST-HOOK-BINARY] [unit->REQ-DIST-HOOKS-API] [unit->REQ-DIST-SKELETON-THIN]
set -u
fail=0
check() { # check <label> <expected> <actual>
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected [$2] got [$3]"; fail=1; fi
}

ROOT="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
HK="$ROOT/plugin/sptc/hooks"
MAN="$ROOT/adapter/claude-spt.toml"
BR="$ROOT/adapter/strings/briefs"
SK="$ROOT/plugin/sptc/skills"
LV="$ROOT/adapter/strings/skills/live.md"

# --- hooks.json: every CC event routes to dispatch.sh with its own event token (static-forever) ---
for ev in SessionStart UserPromptSubmit PreToolUse Stop SessionEnd SubagentStart SubagentStop PostToolUse; do
  grep -q "\"$ev\"" "$HK/hooks.json" && r=yes || r=no
  check "hooks.json declares $ev" "yes" "$r"
  grep -q "dispatch.sh\\\\\" $ev" "$HK/hooks.json" && r=yes || r=no
  check "$ev routes to dispatch.sh $ev" "yes" "$r"
done
# No per-event logic .sh remain (the eight wrappers + _common.sh were folded into the binary).
n=$(ls "$HK"/*.sh 2>/dev/null | grep -Ec 'session-start|user-prompt-submit|pre-tool-use|stop|session-end|subagent-start|subagent-stop|post-tool-use|_common')
check "old per-hook wrappers removed" "0" "$n"
# PostToolUse keeps its Write matcher (the checkpoint detector scope).
grep -q '"matcher": "Write"' "$HK/hooks.json" && r=yes || r=no
check "PostToolUse keeps the Write matcher" "yes" "$r"

# --- dispatch.sh: static resolver shape ---
sh -n "$HK/dispatch.sh" && r=ok || r=bad
check "dispatch.sh is valid POSIX sh" "ok" "$r"
grep -q 'get-string claude-spt hook_cmd' "$HK/dispatch.sh" && r=yes || r=no
check "dispatch resolves the binary via [strings].hook_cmd" "yes" "$r"
grep -q 'SPTC_HOOK_BIN' "$HK/dispatch.sh" && r=yes || r=no
check "dispatch caches the resolved bin (SPTC_HOOK_BIN)" "yes" "$r"
# v0.9.1 env-file fix: the cache value is QUOTED (CC sources $CLAUDE_ENV_FILE per Bash call; an
# unquoted value with a space → `VAR=val cmd` → `hook: command not found` + lost value).
grep -q 'SPTC_HOOK_BIN="%s"' "$HK/dispatch.sh" && r=yes || r=no
check "dispatch quotes the cached value (env-file space-safe)" "yes" "$r"
# `hook` is appended as a LITERAL subcommand (not embedded in the cached path).
grep -q 'exec "\$bin" hook "\$event"' "$HK/dispatch.sh" && r=yes || r=no
check "dispatch execs \"\$bin\" hook <event> (literal subcommand)" "yes" "$r"
# Defensive: a trailing ` hook` from an older manifest value is stripped.
grep -q 'bin="\${bin% hook}"' "$HK/dispatch.sh" && r=yes || r=no
check "dispatch strips a legacy trailing ' hook' (cross-version safe)" "yes" "$r"

# REGRESSION (v0.9.1, the env-file bug at its real seam): CC SOURCES $CLAUDE_ENV_FILE per Bash/hook
# invocation. Emulate the exact line dispatch caches and source it in THIS shell — the v0.9.0 unquoted
# value (a trailing ` hook`) must be shown to break (`hook: command not found`), and the v0.9.1 quoted
# value must source clean AND preserve the value verbatim even with a space in the path.
_ef=$(mktemp); _errf=$(mktemp)
_old="/opt/spt/adapters/x/claude-spt hook"          # the exact v0.9.0 cached value (space before hook)
_p="/c/Program Files/spt dir/claude-spt"            # worst case: a path WITH spaces
# v0.9.0 (unquoted) — sourcing runs the bare `hook` token.
unset SPTC_HOOK_BIN; printf 'SPTC_HOOK_BIN=%s\n' "$_old" > "$_ef"; : > "$_errf"
. "$_ef" 2>"$_errf" || true
grep -q 'hook: command not found' "$_errf" && r=yes || r=no
check "unquoted v0.9.0 value DOES break when sourced (documents the bug)" "yes" "$r"
# v0.9.1 (quoted) — clean source, value intact.
unset SPTC_HOOK_BIN; printf 'SPTC_HOOK_BIN="%s"\n' "$_p" > "$_ef"; : > "$_errf"
. "$_ef" 2>"$_errf" || true
[ -s "$_errf" ] && r=dirty || r=clean
check "quoted cache sources CLEAN (no stray command)" "clean" "$r"
[ "${SPTC_HOOK_BIN:-}" = "$_p" ] && r=intact || r=lost
check "quoted cache preserves the value verbatim (space-safe)" "intact" "$r"
unset SPTC_HOOK_BIN; rm -f "$_ef" "$_errf"
grep -q 'bootstrap.sh' "$HK/dispatch.sh" && r=yes || r=no
check "dispatch runs the SessionStart bootstrap (invisible installer)" "yes" "$r"
# bootstrap only on SessionStart (the binary cannot exist before spt-core + the adapter install).
awk '/if \[ "\$event" = "SessionStart" \]/{s=1} /bootstrap.sh/{if(s)b=1} END{exit !b}' "$HK/dispatch.sh" && r=yes || r=no
check "bootstrap gated to SessionStart" "yes" "$r"
grep -q -- '--host-pid' "$HK/dispatch.sh" && r=yes || r=no
check "dispatch passes the seed pid (--host-pid)" "yes" "$r"
# No-op (exit 0) when the binary is unresolvable (adapter not registered yet / pre-/sptc:setup).
grep -q '\[ -z "\$bin" \] && exit 0' "$HK/dispatch.sh" && r=yes || r=no
check "dispatch no-ops when the adapter is not yet registered" "yes" "$r"

# --- manifest: the declarations the wiring depends on ---
# v0.9.1: hook_cmd is the bare binary PATH (no trailing ` hook`); dispatch appends the subcommand.
grep -q 'hook_cmd = "{adapter_dir}/claude-spt"' "$MAN" && r=yes || r=no
check "manifest [strings].hook_cmd = {adapter_dir}/claude-spt (bare path)" "yes" "$r"
# And the ASSIGNMENT line (anchored at col 0, not the explanatory comment) must not carry the old
# space-before-hook value (the env-file regression).
grep -qE '^hook_cmd = "\{adapter_dir\}/claude-spt hook"' "$MAN" && r=present || r=absent
check "manifest hook_cmd assignment has no embedded ' hook' (env-file fix)" "absent" "$r"
grep -q '^\[hooks\.PreToolUse\]' "$MAN" && r=yes || r=no
check "manifest declares [hooks.PreToolUse]" "yes" "$r"
grep -q 'live-ops = { file' "$MAN" && r=yes || r=no
check "manifest registers briefs.live-ops" "yes" "$r"

# --- U4: reactive-skill thinning (prose rides adapter strings, SKILL.md are thin stubs) ---
grep -q 'commune' "$BR/live-ops.md" && grep -q '!!checkpoint!!' "$BR/live-ops.md" && grep -q 'endpoint shutdown' "$BR/live-ops.md" && r=yes || r=no
check "live-ops brief carries commune+checkpoint+signoff" "yes" "$r"
grep -q 'commune.md' "$LV" && grep -q '!!checkpoint!!' "$LV" && r=yes || r=no
check "go-live body inlines commune+checkpoint" "yes" "$r"
for s in commune signoff send; do
  grep -q 'thin skeleton' "$SK/$s/SKILL.md" && r=yes || r=no
  check "$s SKILL.md is a thin stub" "yes" "$r"
done
grep -q 'Normal commune' "$SK/commune/SKILL.md" && r=present || r=absent
check "commune SKILL.md full body removed" "absent" "$r"

[ "$fail" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "FAILURES"; exit 1; }
