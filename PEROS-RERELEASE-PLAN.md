# Per-OS re-release + cplugs v0.1.2 — JIT plan

> **Status: NOT STARTED.** Gated on operator go-ahead (outward-facing GitHub release).
> Prereqs DONE: v0.8.1 psyche fix (ddf1965) + F-006 retired (717efd2), both committed, proof green.

## Why this release
The registered/published adapter is **v0.1.0** — it predates: the greedy-`--prompt` psyche fix
(ddf1965), the `[update] gh_release` block, the dropped F-006 interim, per-OS assets, ccs (#7) +
subnet (#3/#4) setup waves. End users on v0.1.0 still have the broken psyche + the interim step.
This release ships all of it.

## Scope / tasks

1. **Rebuild the tool binaries from source** (the psyche fix is in source; the install-dir exe was
   hand-deployed during diagnosis — NOT a packaged artifact):
   - `sh ci/digest/build.sh && sh ci/psyche/build.sh` (cargo test + release build, Windows native).
2. **Pack `adapter-windows-x86_64.spt`**: `sh ci/publish/package-adapter.sh --apply` → `dist/`.
3. **Cross-build + pack `adapter-linux-x86_64.spt`** (recipe in `docs/RELEASE-RUNBOOK.md` §Per-OS):
   - zig @ `~/.sptc-zig/...` on PATH; `cargo zigbuild --release --target x86_64-unknown-linux-gnu`
     for BOTH tool crates; then
     `SPTC_OS=linux SPTC_ARCH=x86_64 SPTC_TARGET=x86_64-unknown-linux-gnu sh ci/publish/package-adapter.sh --apply`.
   - Verify both .spt carry the RIGHT binaries (win=PE, linux=ELF) and validate the manifest.
4. **Bump + changelog**: decide version (adapter manifest version — distinct from plugin version).
   Add a `## [<ver>] - 2026-06-16` CHANGELOG section (user-facing: psyche live-agent now works; no
   more manual PATH-copy in setup; per-OS assets; ccs + subnet setup). Regenerate gated docs
   (`sh ci/docs/gen-llms.sh` if needed; `ci/docs/check-docs.sh` must stay green).
5. **[OUTWARD-FACING] Cut the GitHub release** on `SaberMage/spt-claude-code`, attach BOTH per-OS
   `.spt` assets. Tag triggers docs-publish. **← confirm with operator before this step.**
6. **Live gh_release auto-update test (TASK 4)**: the currently-registered adapter is v0.1.0 (no
   `[update]`), so first **re-acquire** the new one: `spt adapter add --release SaberMage/spt-claude-code
   --tag <newver> --asset adapter-windows-x86_64.spt`. Then confirm `spt adapter update` pulls a
   subsequent bump via the declared `[update] gh_release` avenue.
7. **cplugs republish v0.1.2 (TASK 5)** — coupled, AFTER the per-OS release (RELEASE-RUNBOOK ordering:
   assets first, skeleton bump second, else end-user setup 404s). Bump `plugin.json` version; copy the
   skeleton subset (skills/hooks/plugin.json) into the cplugs marketplace clone; `claude plugin install
   sptc@cplugs`. Ships the os-detecting setup floor + ccs + subnet + dropped interim.

## Gate
`sh ci/run-gates.sh` green + `traceable-reqs check` green + both .spt validate + (post-publish)
`spt adapter add --release …` re-acquires active with the fix.

## Known context
- doyle is OFFLINE — the F-009/F-010 findings (in `docs/SPT-CORE-FINDINGS.md` + commit ddf1965) are
  PENDING delivery; retry `spt send doyle --from perri`. The auto-update test (task 4) does NOT need
  doyle, but coordinating the spt-core findings does.
- The psyche runner calls `claude` by bare name; `claude` (`~/.local/bin`) is NOT on the persistent
  logon PATH, so a fresh-logon daemon's psyche seed/pulse turns will no-op (the runner stays resident
  but its claude turns fail). Separate from F-006; verify on a real fresh-logon live session — may need
  a setup step to put `claude` on the persistent PATH, or the psyche to resolve claude robustly.
