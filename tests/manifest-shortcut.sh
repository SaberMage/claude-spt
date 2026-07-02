#!/bin/sh
# Brand-value regression guard for the `spt endpoint run` shortcut: the manifest MUST declare
# adapter.shortcut_basename = "cc" (→ cc-<id>, the M12 cc launcher). A drift to "sptc"/"spt"/default
# is caught here, distinct from the structural manifest-schema check. (The launcher brand is
# decoupled from the plugin name `sptc`; the s/sptc/spt/ succession renames the plugin, not this.)
# Run: sh tests/manifest-shortcut.sh (exit 0 = pass).
# [unit->REQ-DIST-SHORTCUT-BASENAME]
ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
MANIFEST="$ROOT/adapter/claude-spt.toml"
fail=0

# The active assignment line (not a comment): a TOML key at column 0. grep -E, exclude `#`-leading.
line=$(grep -E '^[[:space:]]*shortcut_basename[[:space:]]*=' "$MANIFEST")
if [ -z "$line" ]; then echo "FAIL no shortcut_basename assignment in manifest"; exit 1; fi

case "$line" in
  *'"cc"'*) echo "ok   shortcut_basename = \"cc\" (cc-<id> brand intact)" ;;
  *) echo "FAIL shortcut_basename is not \"cc\": $line"; fail=1 ;;
esac

# Defensive: exactly one active assignment (a stray second would make the picker value ambiguous).
n=$(grep -Ec '^[[:space:]]*shortcut_basename[[:space:]]*=' "$MANIFEST")
if [ "$n" -eq 1 ]; then echo "ok   single shortcut_basename assignment"; else echo "FAIL $n shortcut_basename assignments (want 1)"; fail=1; fi

# [unit->REQ-HAZARD-PSYCHE-PERMS-DEADLOCK]
# Non-interactive bringup: ALL FOUR CC spawn commands — [session.self] + [session.resume], base +
# ccs profile — route through the launch shim (0.10.3: `{adapter_dir}/claude-spt launch …`), which
# appends --dangerously-skip-permissions ITSELF (launch.rs cli_argv, unit-tested in the crate). The
# broker spawns CC into a PTY with no operator, so an interactive permission prompt would deadlock
# the launch (docs/KNOWN-HAZARDS.md §2.2). Manifest side: exactly 4 launch spawn lines. Shim side:
# the flag literal must exist in launch.rs (cross-file guard — a shim edit must not silently drop
# the deadlock-breaker). And NO bare claude/ccs spawn line may linger (it would bypass the shim).
spawn=$(grep -E '^[[:space:]]*command[[:space:]]*=[[:space:]]*"\{adapter_dir\}/claude-spt launch ' "$MANIFEST")
nspawn=$(printf '%s' "$spawn" | grep -c .)
if [ "$nspawn" -eq 4 ]; then echo "ok   4 CC spawn commands route through claude-spt launch (self/resume × base/ccs)"; else echo "FAIL expected 4 claude-spt launch spawn commands, found $nspawn"; fail=1; fi
if grep -q -- '--dangerously-skip-permissions' "$ROOT/tools/claude-spt/src/launch.rs"; then echo "ok   launch shim carries --dangerously-skip-permissions (deadlock-breaker)"; else echo "FAIL launch.rs lost --dangerously-skip-permissions"; fail=1; fi
if grep -Eq '^[[:space:]]*command[[:space:]]*=[[:space:]]*"(claude|ccs)([[:space:]]|")' "$MANIFEST"; then echo "FAIL a bare claude/ccs spawn command bypasses the launch shim"; fail=1; else echo "ok   no bare claude/ccs spawn command (all via the shim)"; fi

# [unit->REQ-DIST-SESSION-RESUME]
# [session.resume] declares the native-resume launch — the shim's `--resume {session_id}` maps to
# CC's `-r <session_id>` (reload the real transcript, else a resume re-runs [session.self] → blank;
# the -r mapping is unit-tested in launch.rs resume_argv_leads_with_native_resume_verb). BOTH resume
# roles (base + ccs) must thread {session_id} AND {id}.
resume=$(printf '%s\n' "$spawn" | grep -- '--resume')
nresume=$(printf '%s' "$resume" | grep -c .)
if [ "$nresume" -ne 2 ]; then echo "FAIL expected 2 [session.resume] launch commands (base+ccs), found $nresume"; fail=1; else
  echo "ok   2 [session.resume] launch commands (base + ccs profile)"
  if [ "$(printf '%s\n' "$resume" | grep -c -- '--resume {session_id}')" -eq 2 ]; then echo "ok   [session.resume] reloads by {session_id} (--resume → claude -r)"; else echo "FAIL a [session.resume] command misses --resume {session_id}: $resume"; fail=1; fi
  if [ "$(printf '%s\n' "$resume" | grep -c -- '--id {id}')" -eq 2 ]; then echo "ok   [session.resume] threads the endpoint {id} into the shim"; else echo "FAIL a [session.resume] command misses --id {id}: $resume"; fail=1; fi
fi

# [unit->REQ-DIST-NAME-UNIFY]
# U3: the repo was renamed spt-claude-code -> claude-spt. [update].repo MUST read the new slug (else
# `spt adapter update` pulls from the redirected old slug), and NO owner-qualified old slug may linger
# in the manifest (regression guard for the ref-flip).
if grep -Eq '^[[:space:]]*repo[[:space:]]*=[[:space:]]*"SaberMage/claude-spt"' "$MANIFEST"; then echo 'ok   [update].repo = "SaberMage/claude-spt"'; else echo "FAIL [update].repo is not SaberMage/claude-spt"; fail=1; fi
if grep -q 'SaberMage/spt-claude-code' "$MANIFEST"; then echo "FAIL stale SaberMage/spt-claude-code ref lingers in manifest"; fail=1; else echo "ok   no stale spt-claude-code repo ref in manifest"; fi

# [unit->REQ-DIST-UPDATE-MESSAGE]
# U1: [update] carries a `message` field (markdown spt-core prints on a real apply). It MUST mention
# the unavoidable /reload-plugins manual residual — that is the field's whole reason to exist. Match
# the active `message =` assignment and the reload-plugins notice anywhere in the manifest body.
if grep -Eq '^[[:space:]]*message[[:space:]]*=' "$MANIFEST"; then echo "ok   [update].message present"; else echo "FAIL [update] has no message field"; fail=1; fi
if grep -q 'reload-plugins' "$MANIFEST"; then echo "ok   [update].message points at /reload-plugins"; else echo "FAIL [update].message lacks the /reload-plugins notice"; fail=1; fi
# D2: [update.post] declares the delegated plugin-reconcile = {adapter_dir}/claude-spt post-update.
if grep -Eq '^[[:space:]]*command[[:space:]]*=[[:space:]]*"\{adapter_dir\}/claude-spt post-update"' "$MANIFEST"; then echo "ok   [update.post].command = \"{adapter_dir}/claude-spt post-update\""; else echo "FAIL [update.post].command missing/wrong"; fail=1; fi
if grep -Eq '^\[update\.post\]' "$MANIFEST"; then echo "ok   [update.post] table present"; else echo "FAIL no [update.post] table"; fail=1; fi

# [unit->REQ-DIST-RC-STARTUP]
# U6 + the 0.10.3 node-named upgrade (doyle ask #4 stretch): every spawn path threads {id} into the
# launch shim, which computes the node name ON-NODE and sets the DISPLAY name (-n "<id> @ <node>")
# and the REMOTE-CONTROL channel (--remote-control <id>--<node>) — shapes unit-tested in launch.rs
# (names_carry_id_at_node_and_separator_rc + the argv tests; unknown node degrades to bare <id>).
# Manifest side: all 4 launch lines carry --id {id}, and the two fresh ([session.self]) lines carry
# NO --resume. A drift that drops --id anywhere breaks the display/RC identity on that path.
if [ "$(printf '%s\n' "$spawn" | grep -c -- '--id {id}')" -eq 4 ]; then echo "ok   all 4 launch commands thread --id {id} (display + RC identity)"; else echo "FAIL a launch command misses --id {id}: $spawn"; fail=1; fi
nself=$(printf '%s\n' "$spawn" | grep -v -- '--resume' | grep -c .)
if [ "$nself" -eq 2 ]; then echo "ok   2 fresh [session.self] launch commands (base + ccs profile)"; else echo "FAIL expected 2 fresh launch commands (no --resume), found $nself"; fail=1; fi
# The shim must emit BOTH name flags (cross-file guard, mirrors the skip-perms guard above).
if grep -q -- '"--remote-control"' "$ROOT/tools/claude-spt/src/launch.rs" && grep -q -- '"-n"' "$ROOT/tools/claude-spt/src/launch.rs"; then echo "ok   launch shim emits -n + --remote-control"; else echo "FAIL launch.rs lost the -n/--remote-control name flags"; fail=1; fi

# [unit->REQ-CCS-PROFILES]
# v0.9.1 FIX (bug #6, still binding): the ccs profile leaf-replaces session.self/.resume `command`
# wholesale, so its overrides MUST mirror base's full shim shape — else a ccs endpoint loses its
# name + RC channel. 0.10.3: the ccs overlay = the same launch shim + `--cli ccs`.
ccs_spawn=$(printf '%s\n' "$spawn" | grep -- '--cli ccs')
nccs=$(printf '%s' "$ccs_spawn" | grep -c .)
if [ "$nccs" -eq 2 ]; then echo "ok   2 ccs-profile launch commands carry --cli ccs (self + resume)"; else echo "FAIL expected 2 ccs launch commands (--cli ccs), found $nccs"; fail=1; fi
case "$ccs_spawn" in
  *'--resume {session_id}'*) echo "ok   ccs [session.resume] keeps native-resume (--resume {session_id})";;
  *) echo "FAIL ccs [session.resume] misses --resume {session_id}: $ccs_spawn"; fail=1;;
esac

# [unit->REQ-DIST-IDLE-TRANSLATE]
# [message-idle-translation-binary] declares the idle-delivery filter via `command` (spt-core v0.16.0
# seam; `path` deprecated) = the `translate` subcommand of the consolidated binary, resolved from the
# install dir via {adapter_dir} (D3 fold). MUST be `command` (not the deprecated `path`) and name the
# claude-spt translate subcommand.
idle=$(grep -E '^[[:space:]]*command[[:space:]]*=[[:space:]]*"\{adapter_dir\}/claude-spt translate"' "$MANIFEST")
if [ -n "$idle" ]; then echo "ok   [message-idle-translation-binary] command = \"{adapter_dir}/claude-spt translate\""; else echo "FAIL [message-idle-translation-binary] command != \"{adapter_dir}/claude-spt translate\""; fail=1; fi
# Regression guard: the deprecated bare `path = "cc-spt-idle-translate"` must be GONE (exactly one of path/command).
if grep -Eq '^[[:space:]]*path[[:space:]]*=[[:space:]]*"cc-spt-idle-translate"' "$MANIFEST"; then echo "FAIL deprecated [message-idle-translation-binary].path still present (both-set is refused)"; fail=1; else echo "ok   no deprecated idle-translate path (command-only)"; fi

[ "$fail" -eq 0 ] && { echo "MANIFEST-SHORTCUT OK"; exit 0; } || { echo "MANIFEST-SHORTCUT FAIL"; exit 1; }
