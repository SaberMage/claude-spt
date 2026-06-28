#!/bin/sh
# sptc hook dispatch — STATIC-FOREVER (D1, ADR-0006 ask #1 → resolve-not-execute).
#
# This is the ONLY hook shell the cplugs plugin still ships. It carries NO hook logic — that all moved
# into the consolidated `claude-spt` binary (`claude-spt hook <event>`), which rides `spt adapter
# update`. This wrapper only RESOLVES that binary and execs it, so it never needs to change again when
# hook behaviour changes. hooks.json wires every CC event to `sh dispatch.sh <CCEventName>`.
#
# Resolution rides spt-core v0.16.0's two pure primitives (no new spt-core execution): the adapter
# `[strings].hook_cmd = "{adapter_dir}/claude-spt hook"` is lazily {adapter_dir}-substituted at
# `spt adapter get-string` read time → the absolute `<install_dir>/claude-spt hook` command. We resolve
# it ONCE per session (cached in $SPTC_HOOK_BIN via $CLAUDE_ENV_FILE on SessionStart) and reuse it per
# hook. Session-scoped keys (session_id, …) are NOT available via get-string — the binary reads those
# from the CC hook payload on stdin (passed through untouched: this wrapper never reads stdin).
#
# Bootstrap stays HERE, not in the binary: the binary lives in the adapter install dir, which does not
# exist until spt-core + the adapter are installed. So SessionStart installs spt-core on demand first;
# and if the adapter is not yet registered (pre-/sptc:setup), get-string yields nothing and we no-op
# (exit 0) — exactly the pre-readiness no-op the old per-hook wrappers had. [impl->REQ-DIST-HOOK-BINARY]
event="$1"

# Resolve the spt binary (PATH first, then known install locations) — only needed to get-string the
# hook command; the binary itself is resolved from {adapter_dir}, not PATH.
spt_bin() {
  if command -v spt >/dev/null 2>&1; then printf 'spt'; return 0; fi
  for p in \
    "$HOME/.local/bin/spt" \
    "$LOCALAPPDATA/spt-core/bin/spt.exe" \
    "$HOME/AppData/Local/spt-core/bin/spt.exe"; do
    [ -x "$p" ] && { printf '%s' "$p"; return 0; }
  done
  printf 'spt'
}

# SessionStart only: invisible-installer (install spt-core if absent — no-op when present). Redirect
# stdin from /dev/null so this never consumes the CC hook payload the binary will read.
if [ "$event" = "SessionStart" ]; then
  sh "$CLAUDE_PLUGIN_ROOT/bootstrap.sh" </dev/null >/dev/null 2>&1 || true
fi

# Resolve the hook command: cached env first, else the lazily-substituted adapter string.
bin="${SPTC_HOOK_BIN:-}"
if [ -z "$bin" ]; then
  bin=$("$(spt_bin)" adapter get-string claude-spt hook_cmd </dev/null 2>/dev/null) || true
fi

# Adapter not registered yet (pre-/sptc:setup) → no perch to serve → no-op.
[ -z "$bin" ] && exit 0

# Cache the resolved command for the rest of the session so later per-prompt hooks skip get-string.
if [ "$event" = "SessionStart" ] && [ -n "${CLAUDE_ENV_FILE:-}" ] && [ -z "${SPTC_HOOK_BIN:-}" ]; then
  printf 'SPTC_HOOK_BIN=%s\n' "$bin" >> "$CLAUDE_ENV_FILE"
fi

# Exec the binary: `$bin` is "<install_dir>/claude-spt hook" (word-split into the program + the `hook`
# subcommand), then the CC event + the seed pid. CC stdin (the hook payload) is inherited untouched —
# the binary reads it directly. $PPID is the seed pid (Rust std has no portable getppid on Windows).
# shellcheck disable=SC2086
exec $bin "$event" --host-pid "$PPID"
