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
# Non-interactive bringup: ALL FOUR CC spawn commands — the two [session.self] (base `claude`, the
# `ccs` profile) AND the two [session.resume] (base `claude -r …`, the `ccs -r …` profile, v0.9.1) —
# MUST carry --dangerously-skip-permissions. The broker spawns CC into a PTY with no operator, so an
# interactive permission prompt would deadlock the launch (docs/KNOWN-HAZARDS.md §2.2). Match the active
# `command =` lines whose value is a bare claude/ccs CC spawn — NOT `claude-spt psyche` (the runner;
# `claude-spt` has `-`/no-space after `claude`, so the (claude|ccs)(space|") match correctly excludes
# it — its turns are asserted in the tools/claude-spt crate's psyche unit tests).
spawn=$(grep -E '^[[:space:]]*command[[:space:]]*=[[:space:]]*"(claude|ccs)([[:space:]]|")' "$MANIFEST")
nspawn=$(printf '%s' "$spawn" | grep -c .)
if [ "$nspawn" -eq 4 ]; then echo "ok   4 CC spawn commands ([session.self] base+ccs, [session.resume] base+ccs)"; else echo "FAIL expected 4 CC spawn commands, found $nspawn"; fail=1; fi
nomiss=$(printf '%s\n' "$spawn" | grep -c -v -- '--dangerously-skip-permissions')
if [ "$nspawn" -gt 0 ] && [ "$nomiss" -eq 0 ]; then echo "ok   every CC spawn command carries --dangerously-skip-permissions"; else echo "FAIL a CC spawn command lacks --dangerously-skip-permissions ($nomiss without it)"; fail=1; fi

# [unit->REQ-DIST-SESSION-RESUME]
# [session.resume] declares CC's native-resume verb — `-r {session_id}` (reload the real transcript,
# else a resume re-runs [session.self] → blank) and `--remote-control {id}` (thread the endpoint id
# as the RC session name). A drift that drops either fill silently breaks native resume / RC drive.
resume=$(grep -E '^[[:space:]]*command[[:space:]]*=[[:space:]]*"claude -r ' "$MANIFEST")
if [ -z "$resume" ]; then echo 'FAIL no [session.resume] claude -r … command in manifest'; fail=1; else
  case "$resume" in
    *'-r {session_id}'*) echo "ok   [session.resume] reloads by {session_id} (-r)";;
    *) echo "FAIL [session.resume] missing -r {session_id}: $resume"; fail=1;;
  esac
  case "$resume" in
    *'--remote-control {id}'*) echo "ok   [session.resume] threads {id} as the remote-control name";;
    *) echo "FAIL [session.resume] missing --remote-control {id}: $resume"; fail=1;;
  esac
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
# U6: {id} threads the DISPLAY name (`-n {id}`) on BOTH bringup paths and the REMOTE-CONTROL channel
# (`--remote-control {id}`) on BOTH, so a FRESH ([session.self]) and a RESUMED ([session.resume])
# endpoint are identified + RC-controlled identically. self currently `claude -n {id} …`, resume
# `claude -r {session_id} -n {id} …`. A drift that drops -n on either, or --remote-control on self,
# silently breaks the {id} display/RC parity. ({id}-only now; -> {id}@{node} when a {node} key lands.)
self_cmd=$(grep -E '^[[:space:]]*command[[:space:]]*=[[:space:]]*"claude -n ' "$MANIFEST")
if [ -z "$self_cmd" ]; then echo 'FAIL no [session.self] "claude -n {id} …" command in manifest'; fail=1; else
  case "$self_cmd" in
    *'-n {id}'*) echo "ok   [session.self] sets {id} as the display name (-n)";;
    *) echo "FAIL [session.self] missing -n {id}: $self_cmd"; fail=1;;
  esac
  case "$self_cmd" in
    *'--remote-control {id}'*) echo "ok   [session.self] threads {id} as the remote-control name";;
    *) echo "FAIL [session.self] missing --remote-control {id}: $self_cmd"; fail=1;;
  esac
fi
# resume carries -n {id} too (the U6 addition — parity with self; --remote-control {id} already
# asserted by the REQ-DIST-SESSION-RESUME block above, $resume reused).
case "$resume" in
  *'-n {id}'*) echo "ok   [session.resume] sets {id} as the display name (-n, U6 parity)";;
  *) echo "FAIL [session.resume] missing -n {id} (U6 display-name parity): $resume"; fail=1;;
esac

# [unit->REQ-CCS-PROFILES]
# v0.9.1 FIX (bug #6): the ccs profile leaf-replaces session.self/.resume `command`, so its overrides
# MUST carry the SAME U6 {id} display + RC flags base has — else a ccs endpoint loses its name + RC
# channel. Match the `ccs …` spawn lines and assert -n {id} + --remote-control {id} on each.
ccs_self=$(grep -E '^[[:space:]]*command[[:space:]]*=[[:space:]]*"ccs -n ' "$MANIFEST")
ccs_resume=$(grep -E '^[[:space:]]*command[[:space:]]*=[[:space:]]*"ccs -r ' "$MANIFEST")
if [ -z "$ccs_self" ]; then echo 'FAIL ccs profile [session.self] not "ccs -n {id} …"'; fail=1; else
  case "$ccs_self" in *'-n {id}'*'--remote-control {id}'*) echo "ok   ccs [session.self] carries -n {id} + --remote-control {id}";; *) echo "FAIL ccs [session.self] missing -n/--remote-control {id}: $ccs_self"; fail=1;; esac
fi
if [ -z "$ccs_resume" ]; then echo 'FAIL ccs profile [session.resume] not "ccs -r {session_id} …"'; fail=1; else
  case "$ccs_resume" in *'-r {session_id}'*'-n {id}'*'--remote-control {id}'*) echo "ok   ccs [session.resume] carries -r {session_id} + -n {id} + --remote-control {id}";; *) echo "FAIL ccs [session.resume] missing native-resume/-n/RC flags: $ccs_resume"; fail=1;; esac
fi

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
