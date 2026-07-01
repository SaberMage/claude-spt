# DIGEST-FETCHER-PLAN — v0.10.0: consume spt-core v0.19.0 (#17 fetcher strategy)

**Trigger:** todlando GO 2026-07-01 — spt-core v0.19.0 (counter 38) published + verified.
**Goal:** claude-spt adopts the `[digest]` fetcher strategy + `[env] direction="read"` seam and
bumps `min_spt_core` → 0.19.0. Ship as adapter v0.10.0.

## Scope

1. **Re-vendor schema** — `adapter/manifest.schema.json` from the published
   https://sabermage.github.io/spt-releases/manifest.schema.json (now carries
   `DigestStrategy` + `EnvDirection.read`). CI manifest gate keeps validating against it.
2. **Manifest** (`adapter/claude-spt.toml`):
   - `min_spt_core_version = "0.19.0"` + floor-bump comment (fetcher strategy + [env] read seam
     + captured-read-var fill all land in 0.19.0 — an older node can't fill `{CLAUDE_CONFIG_DIR}`).
   - `[digest]`: `strategy = "fetcher"`; extractor becomes the locator —
     `claude-spt digest --session {session_id} --config-dir {CLAUDE_CONFIG_DIR}`;
     DROP `source` (ignored under fetcher; spt-core no longer pre-reads).
   - NEW `[env.CLAUDE_CONFIG_DIR]`: `direction = "read"`, `value = "~/.claude"` (fallback when the
     session env lacks it; spt-core captures at bind → info.json.read_env → fill → ~expand).
     Closes the "ccs CLAUDE_CONFIG_DIR not expressible statically" gap FOR REAL: the captured
     per-session value reaches the on-demand extractor in the daemon's context.
   - version → 0.10.0 + history note.
3. **Extractor** (`tools/claude-spt/src/digest.rs`):
   - New `--config-dir <dir>` flag: dir-branch root = `<config-dir>/projects` (highest precedence,
     it IS the captured/fallback value), then `$CLAUDE_CONFIG_DIR` env (in-session invocations),
     then legacy `--in` root (digest-proof + old manifests mid-update), then `~/.claude/projects`.
   - `--in` stays for the file shape (digest-proof `--sample`) + legacy dir shape.
   - Unit tests for the new precedence.
4. **Traceability**: new `REQ-DIST-DIGEST-FETCHER` (doc/impl/unit) in traceable-reqs.toml;
   REQ-CCS-PROFILES notes gain the read-var path.
5. **Hazard note** (todlando nudge, separate concern): KNOWN-HAZARDS entry — hook_cmd SHAPE and the
   plugin dispatch shim must move in LOCKSTEP (the v0.9.2-mid-session skew bricked a session:
   old dispatch × new bare-path hook_cmd → unknown-subcommand → CC blocked all tools + Stop loop).
   Registry entry `REQ-HAZARD-HOOKCMD-DISPATCH-LOCKSTEP`, stages [] (activate when guard work starts).

## Gate

- `cargo test` green (tools/claude-spt)
- `traceable-reqs check` green
- manifest-schema CI test green against re-vendored schema
- LIVE proof on the 0.19.0 binary: re-register adapter → `spt adapter digest-proof` (fetcher shape)
  + a real `spt endpoint digest` against this session's transcript (base) — ccs-profile proof too
  (this node IS a ccs instance: CLAUDE_CONFIG_DIR capture is the whole point).
- Publish v0.10.0 (fat .spt) + verify `spt adapter update` applies it.

## Non-goals

- `[history]` sibling seam (still deferred — separate slice).
- The skew-brick guard implementation (post-update reconcile of live plugin cache) — logged as
  hazard + open thread, not this slice.
