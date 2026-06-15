# cplugs publish-prep — JIT plan (slice)

> Toward an actually-installable cplugs skeleton artifact. Activates **REQ-DIST-PLUGIN-SKELETON**
> impl+unit (hooks.json now exists, so the impl hold is lifted). Harness-agnostic POSIX sh.

## Found while scoping (fix in this slice)

`plugin/sptc/.claude/LIVE_AGENT_IDS.json` — live perch runtime state (my `perri` id) was **tracked
into the publishable skeleton**: the root `.gitignore` pattern `.claude/LIVE_AGENT_IDS.json` is
root-anchored and missed the nested `plugin/sptc/.claude/`. A published skeleton must carry ZERO
runtime/agent state. → untrack + depth-safe ignore + a validator gate so it can't recur.

## Scope

1. **`ci/publish/validate-skeleton.sh`** — deterministic installability gate (exit 0/1). Asserts:
   - `plugin.json` is valid JSON, `name == "sptc"`, has `version` + `description`.
   - `hooks/hooks.json` is valid JSON and every referenced `hooks/<x>.sh` wrapper EXISTS.
   - every `skills/*/` dir has a `SKILL.md`.
   - **skeleton-subset invariant**: NO runtime state (`LIVE_AGENT_IDS.json`, `*-commune.md`,
     `*-signoff.md`, generated `cc`/`cc-*` launchers) and NO binary/manifest (`*.exe`, `*.bin`,
     `manifest.json`) anywhere under the plugin — the binary + adapter manifest ride the spt-core
     registry, never cplugs (RELEASE-RUNBOOK).
   [impl->REQ-DIST-PLUGIN-SKELETON]
2. **`ci/publish/package-skeleton.sh`** — codifies the runbook "per skeleton bump" cp mechanic as a
   real, idempotent script. `--dry-run` default (prints the staging plan); validates first, refuses
   to stage if validation fails; stages only the skeleton subset into `$MARKET`
   (`~/.claude/plugins/marketplaces/cplugs/plugins/sptc`). Never pushes (creds/external = operator).
   [impl->REQ-DIST-PLUGIN-SKELETON]
3. **`tests/skeleton-validate.sh`** — UNIT: validator PASSES on the real skeleton, and FAILS on a
   tampered copy (planted `LIVE_AGENT_IDS.json` / planted `.exe` / removed `SKILL.md`) — proves the
   gate actually catches breakage, not just green-on-green. [unit->REQ-DIST-PLUGIN-SKELETON]
4. **Hygiene fix**: `git rm --cached plugin/sptc/.claude/LIVE_AGENT_IDS.json`; depth-safe
   `.gitignore` (`**/.claude/LIVE_AGENT_IDS.json` etc.).
5. **Wire** the validator as a new deterministic gate in `ci/run-gates.sh` ("skeleton-validate").
6. **traceable-reqs.toml**: flip `REQ-DIST-PLUGIN-SKELETON` → `["doc","impl","unit"]`; add
   `ci/publish` to `[scan].roots`.
7. **docs/RELEASE-RUNBOOK.md**: note the mechanics are now scripted (`ci/publish/*`).

## Gate

`sh ci/run-gates.sh` ⇒ PASS · `traceable-reqs check` green. Atomic commit, `Co-authored by: perri`.

## Next (per doyle)

Report cplugs-prep → roll straight to mdBook docs-site → then seed next parity-trim milestone REQs.
