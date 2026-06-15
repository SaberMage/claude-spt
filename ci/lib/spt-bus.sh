# shellcheck shell=sh
# Locate the spt messaging (bus) binary ROBUSTLY at run time. The bus is legacy spt (`$OWL send`,
# the dogfood reporting channel per SCOPE/docs/CI.md); its path MOVES each release (per-version
# plugins cache), so NEVER hard-code a versioned location — resolve fresh. [impl->REQ-CI-OWL-DISCOVERY]
# [impl->REQ-CI-BUS]
resolve_spt_send() {
  # 1) explicit override (CI config / fleet host setup)
  if [ -n "${SPTC_CI_BUS:-}" ] && [ -x "${SPTC_CI_BUS}" ]; then printf '%s' "$SPTC_CI_BUS"; return 0; fi
  # 2) a live session's injected $OWL
  if [ -n "${OWL:-}" ] && [ -x "${OWL}" ]; then printf '%s' "$OWL"; return 0; fi
  # 3) on PATH (owl.exe / owl = legacy bus; spt = newer core, also has `send`)
  for c in owl.exe owl spt; do
    if command -v "$c" >/dev/null 2>&1; then command -v "$c"; return 0; fi
  done
  # 4) per-version plugin caches — newest wins (version-sorted), path never hard-coded
  cand=$(ls -1 \
    "$HOME"/.claude/plugins/cache/*/spt/*/owl.exe \
    "$HOME"/.ccs/*/plugins/cache/*/spt/*/owl.exe 2>/dev/null | sort -V | tail -n1)
  if [ -n "$cand" ] && [ -x "$cand" ]; then printf '%s' "$cand"; return 0; fi
  return 1
}
