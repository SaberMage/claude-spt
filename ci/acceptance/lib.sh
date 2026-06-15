# shellcheck shell=sh
# sptc CI acceptance harness — shared helpers. Pure/deterministic except sptc_ci_spawn (which
# drives a real `claude`). Sourced by run-acceptance.sh and exercised (sans real claude) by
# tests/acceptance-harness.sh. [impl->REQ-CI-ACCEPTANCE]

# ── Disposable identity (perch-collision guard) ──────────────────────────────
# Mint a throwaway perch id and EXPORT it over any inherited live-agent identity, so a nested
# SUT can never resolve the operator's perch id (name-keyed, last-establish-wins → teardown).
# $1 = a caller-supplied uniquifier (e.g. a counter or pid); never random (scripts stay replayable).
# Sets+exports SPT_AGENT_ID, OWL_SESSION_ID, and SPTC_CI_ID (the id) IN THE CURRENT SHELL so the
# mutation reaches the later spawn. Call it bare — do NOT capture with $(...), which would run the
# export in a subshell and lose it; read the result from $SPTC_CI_ID. [impl->REQ-HAZARD-PERCH-COLLISION]
sptc_ci_identity() {
  _n="${1:?sptc_ci_identity needs a uniquifier}"
  SPTC_CI_ID="sptc-ci-${_n}"
  # Hard override — must NOT inherit the operator's identity into the spawn env.
  SPT_AGENT_ID="$SPTC_CI_ID"
  OWL_SESSION_ID="$SPTC_CI_ID"
  export SPTC_CI_ID SPT_AGENT_ID OWL_SESSION_ID
}

# True iff $1 is a disposable CI identity (the shape the harness is allowed to spawn under).
# Used by the guard test and as a belt-and-braces preflight before any real spawn.
# [impl->REQ-HAZARD-PERCH-COLLISION]
sptc_ci_is_disposable() {
  case "${1:-}" in
    sptc-ci-?*) return 0 ;;
    *) return 1 ;;
  esac
}

# ── Isolated project scaffold ────────────────────────────────────────────────
# Build a throwaway CC project that wires a UserPromptSubmit hook writing a digest marker to
# $2 (the digest file). Echoes the project dir. The fixture hook is deliberately self-contained
# (no spt bus, no auth beyond claude's own) so slice-1 acceptance asserts purely that a real
# harness FIRES the hook entry point. $1 = project dir (created), $2 = digest file path.
sptc_ci_mkproject() {
  _proj="${1:?need project dir}"; _digest="${2:?need digest file}"
  mkdir -p "$_proj/.claude/hooks" || return 1
  # Hook reads CC's stdin payload (stdin, never argv — KH 1.1) and appends a marker.
  cat > "$_proj/.claude/hooks/ups-digest.sh" <<HOOK
#!/bin/sh
# Acceptance fixture: prove a real claude fires UserPromptSubmit. Reads stdin payload, never argv.
input=\$(cat)
prompt=\$(printf '%s' "\$input" | sed -n 's/.*"prompt"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
printf 'UPS_FIRED:%s\n' "\$prompt" >> "$_digest"
exit 0
HOOK
  chmod +x "$_proj/.claude/hooks/ups-digest.sh" 2>/dev/null || true
  cat > "$_proj/.claude/settings.json" <<SETTINGS
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [ { "type": "command", "command": "sh \"$_proj/.claude/hooks/ups-digest.sh\"" } ] }
    ]
  }
}
SETTINGS
  printf '%s' "$_proj"
}

# ── Assertion ────────────────────────────────────────────────────────────────
# sptc_ci_assert <label> <needle> <file> : pass iff <file> contains <needle>. Deterministic
# side-effect / digest assertion — the harness never judges model text. Returns 0/1, prints PASS/FAIL.
sptc_ci_assert() {
  _label="$1"; _needle="$2"; _file="$3"
  if [ -f "$_file" ] && grep -q "$_needle" "$_file" 2>/dev/null; then
    printf 'PASS: %s\n' "$_label"; return 0
  fi
  printf 'FAIL: %s (no "%s" in %s)\n' "$_label" "$_needle" "$_file"; return 1
}
