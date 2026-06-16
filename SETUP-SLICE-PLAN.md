# JIT plan — `/sptc:setup` activation bridge (F-005) → grow toward LOCKED v1 setup {1–7}

> Next slice after the cplugs first-publish (b1e2895). Goal: make `/sptc:setup` actually
> **activate** the claude-spt adapter after the binary check (the F-005 post-install bridge), so a
> freshly-installed plugin yields a *registered & active* adapter — not a `deregistered` one. Then
> stage the richer LOCKED v1 setup paths (`SCOPE.md` §"/spt:setup" = {1..7}) as later waves.
> Public-surface-only still binds (AGENTS.md).

## Why (the dogfooding finding, 2026-06-15)

An agent ran `/sptc:setup` on a fresh install: `spt 0.7.2` present → skill reported "No install
needed" and **stopped**. But `spt adapter list` showed **`claude-spt: … deregistered`** — the
adapter surface (profiles/strings/hints/`[digest]`) was inert, `/sptc:*` UPS-injection had nothing
to source. **Binary present ≠ adapter active.** doyle triaged F-005 (docs/SPT-CORE-FINDINGS.md) and
confirmed the missing step: after the binary check, setup must run
**`spt adapter add [--github <repo>]`** to ACTIVATE. The current skill has no such step, and (Point
2, operator) no already-installed branch at all — it is a degenerate installer-floor stub far below
the LOCKED v1 `{1..7}` scope.

## Operator decisions (this session, 2026-06-15)

1. **Proceed with the setup slice (B).** Activation (A — un-break the local adapter) is fulfilled by
   the operator **dogfooding the plugin**, not a separate step here.
2. **End-user `--github` target = `SaberMage/spt-claude-code`** (operator: "this repo is published
   there"). ⚠ See Open Question 1 — the monorepo layout conflicts with `adapter add --github`'s
   root-`manifest.toml` expectation; topology must be resolved before the end-user branch is wired.

## Ground truth (verified against live `spt 0.7.2` this session)

- `spt adapter add --help`: PATH = **"a dir holding `manifest.toml`, or the manifest file itself"**;
  `--github user/repo` clones under `adapters/_github/`, **manifest-first**, then conducts the
  declared `[update]` avenue once. **No subpath flag.** "Install is the first update."
- Our manifest is **`adapter/claude-spt.toml`** (a subdir, *not* named `manifest.toml`); no
  `manifest.toml` exists anywhere in the repo. → the **local** activation form that works today is
  the *manifest-file-itself* form: `spt adapter add ./adapter/claude-spt.toml`.
- `claude-spt` reads **`deregistered`** in the registry (Phase-D int tests register→clean-up by
  design) — re-adding re-activates.
- Extractor/runner = `tools/claude-spt-digest` + `tools/claude-spt-psyche` (source). Command
  templates are **opaque, resolved from PATH at runtime** — so for the adapter to *function* (digest
  + Psyche), those binaries must be **built and on PATH**, independent of manifest registration.

## Open questions

1. **[RESOLVED — doyle shipped `--release`, owl 2026-06-15] End-user acquisition. NO dedicated repo.**
   doyle shipped a new acquisition source — **`spt adapter add --release <user/repo> [--tag <ver>]`**
   — that fetches a published **`adapter.spt`** release asset (a tar whose **root** holds
   `manifest.toml` + `strings/` + the binaries) from the repo's GitHub **release**, extracts to the
   durable home, and registers the root. **So we ship straight from THIS monorepo — no dedicated
   root-manifest repo needed** (operator: "no separate repo"). First-acquisition trusts HTTPS+GitHub
   like the install one-liner; it's **acquisition only** (does NOT change the `[update]` route;
   re-running `--release --tag <newer>` is a manual re-acquire). Recommended over `--github`.
   Docs (revised): `install-on-demand.html#activate-the-adapter--register-your-manifest`.
   - **Local dev:** file-form `spt adapter add ./adapter/claude-spt.toml` (any path/filename).
   - **End-user:** `spt adapter add --release SaberMage/spt-claude-code` (latest) / `--tag <ver>`.
   - ⚠ **Version gate:** local spt is 0.7.2, which has only `--github` + local path — `--release`
     ships in a **newer** spt release. Authoring is unblocked; the int/dogfood waits on the upgrade.
   - **Superseded:** the root-only `--github`/`source_manifest_file` constraint (dir → exact
     `<dir>/manifest.toml`, no subpath — code-confirmed, a doc-gap doyle patched) still holds, but
     `--release` routes around it. The old "dedicated repo" plan (former Wave C) is **dropped**.
2. **[OPEN — fold into Wave C′ packaging] Binary resolution for `claude-spt-digest` / `claude-spt-psyche`.**
   The `--release` `adapter.spt` tar **includes** the binaries at the archive root (extracted to the
   durable home). BUT our command templates reference them by **bare name** ⇒ resolved from **PATH**,
   not the durable home. So packing them only helps if spt-core runs templates with the adapter home
   on PATH / cwd — **unverified**. Two clean options: **(a)** ship both binaries **on PATH** via the
   installer (keeps bare-name templates portable; lean), or **(b)** reference them by a path relative
   to the adapter home in the manifest + rely on the archive extraction. **Decide when building the
   release-asset packaging (Wave C′).** Activation/registration does NOT need the binaries — only
   runtime digest/Psyche do — so this never blocks the activation step.
3. **Setup context detection.** Skill probes for a local `adapter/claude-spt.toml` (operator
   dogfooding from a checkout → file-form) else uses `--github <Wave-C repo>` (casual end-user).

## Waves

### Wave 1 — the activation bridge (fulfills A on dogfood) — `REQ-SETUP-ACTIVATE`
**Scope:** make `/sptc:setup`'s binary-present path **activate + verify**, not no-op.
- Rewrite step 1 of both bodies (the self-contained `plugin/sptc/skills/setup/SKILL.md` floor **and**
  the file-backed `adapter/strings/skills/setup.md`): after `command -v spt && spt --version`, check
  whether `claude-spt` is **registered & active** (`spt adapter list` parse). If active → report +
  stop. If absent/`deregistered` → **activate**:
  - **local dev / operator dogfood:** `spt adapter add ./adapter/claude-spt.toml` (manifest-file
    form) when a repo-local manifest is detectable (OQ3).
  - **end-user:** `spt adapter add --github <target>` — **wired once OQ1 resolves** (target TBD).
- **Verify** activation: `spt adapter list` shows `claude-spt` active (not `deregistered`); spot a
  profile resolve (`spt adapter get-string claude-spt:live …` or `spt api … capability`).
- Keep the absent-binary install path (current step 2/3) intact — install **then** activate.
- Idempotent + safe to re-run (mirrors the bootstrap's contract).
- **Evidence:** doc = both bodies; impl = the activation+verify step; int = a registration
  re-activate assertion (`ci/manifest/registration-int.sh` extension, or a new `setup-activate-int`)
  — `deregistered → active`, profile resolves, registry left clean. Activate
  `REQ-SETUP-ACTIVATE = ["doc","impl","int"]`.
- **Note the binary-on-PATH caveat (OQ2)** in the body: activation registers the manifest;
  digest/Psyche need the tool binaries present (built + on PATH) to *function*.

### Wave C′ — release-asset packaging (`adapter.spt`) — the end-user `--release` target — **on A's critical path**
**Replaces the dropped "dedicated repo" Wave C.** doyle's `--release` ships the adapter from THIS
monorepo as a GitHub **release asset** — no separate repo.
- A `ci/publish/` step (mirrors `package-skeleton.sh`) that **packs** `adapter.spt`:
  `tar -czf adapter.spt -C adapter manifest.toml strings/ …` — **but** our manifest is
  `adapter/claude-spt.toml`, and the tar **root must hold `manifest.toml` named exactly that**. So
  the packer renames `claude-spt.toml → manifest.toml` inside the archive + adds the built
  `claude-spt-digest` + `claude-spt-psyche` (release builds) + (per OQ2) lays them where they
  resolve. Default asset name `adapter.spt` (override `--asset`).
- Upload `adapter.spt` as a GitHub release asset on the monorepo (operator: release/tag + push).
- Verify end-to-end (version-gated on the spt release carrying `--release`): a clean machine
  `spt adapter add --release SaberMage/spt-claude-code` → active + a profile resolves + digest/Psyche
  binaries resolve. New REQ (`REQ-DIST-ADAPTER-RELEASE`) when this wave starts.

### Later waves — LOCKED v1 setup paths {1..7} (each its own slice + REQ; deps flagged)
Staged, not built now (JIT). From `SCOPE.md` §"/spt:setup" LOCKED {1,2,3,4,5,6,7}:
- **#4 already-installed branch** (new subnet / join=add-this-machine / show-code / just-add-endpoint)
  — the natural extension of Wave 1's active-adapter path; pairs with `/sptc:subnet` (already ships).
- **#1 `cc`/`cc <id>` launcher** at project root — **dep:** full-fat M12 `spt endpoint run` picker
  ("lands in a later wave" per `endpoint run --help`; REQ-DIST-SHORTCUT-BASENAME int is held on it).
- **#2** offer `.gitignore` the launchers (rides #1).
- **#3 create first subnet** — QR of the TOTP seed + self-elevating window (elevation design LOCKED,
  `SCOPE.md`; unbuilt). **dep:** elevation machinery.
- **#5 legacy owl migration** — detect `claude_skill_owl`/owl → migrate identity+agents+psyche.
- **#6 OS-service registration** (always-on daemon) — **dep:** spt-core service support.
- **#7 ccs profile wiring** — if `~/.ccs` present; also offer to install ccs. Pairs with the shipped
  `claude-spt:ccs` profile (REQ-CCS-PROFILES).
- Deferred per SCOPE: **#8** off-subnet Psyche sync, **#9** doctor/verify-at-end (operator: "except 9").

## Gate (every wave)
`sh ci/run-gates.sh` PASS + `traceable-reqs check` green. Commit `Co-authored by: perri`.

## Status
- **OQ1 RESOLVED via `--release` (doyle shipped it, owl 2026-06-15).** End-user acquisition ships
  from THIS monorepo as an `adapter.spt` release asset — **no dedicated repo** (operator-aligned).
  Wave 1 bodies updated to the `--release` path.
- **Wave 1 (activation logic) DONE** (`REQ-SETUP-ACTIVATE` doc green) — correct regardless of the
  acquisition source; only the end-user target string changed (`--github` → `--release`).
- **Version gate:** `--release` needs a spt release newer than local 0.7.2 → int/dogfood waits on the
  upgrade. Same gate-pattern as the live relay int.
- **Wave C′ (release-asset packaging) is on A's critical path** for the plugin-dogfood end-user path;
  OQ2 (binary resolution) decided there. Local-dir activation is dogfoolable now.
- **Carry-over:** cplugs republish (the published skeleton still has the pre-activation setup body) +
  optional bootstrap auto-activate.
- **PRE-POSITIONED + GATE LIFTED (2026-06-15):** monorepo pushed (origin/main); GitHub **release
  `v0.1.0`** cut with the `adapter.spt` asset
  (https://github.com/SaberMage/spt-claude-code/releases/tag/v0.1.0). **spt `v0.7.3` PUBLIC** —
  `adapter add --release` in the binary.
- **✅ DOGFOOD PROVEN END-TO-END (2026-06-15) — A IS FULFILLED via the real end-user path.**
  `spt update fetch`→`apply` (0.7.2→0.7.3, exe hash = signed `d867…0794`, seamless) →
  `adapter add --release SaberMage/spt-claude-code --tag v0.1.0` → fetched `adapter.spt` → registered
  → **`claude-spt` ACTIVE** (Harness Copy, from `…/adapters/_github/SaberMage-spt-claude-code`).
  One gap found + logged: bundled binaries extract beside the manifest but bare-name templates once
  resolved from PATH only (**F-006**). **RESOLVED (v0.8.1 dogfood 2026-06-16):** spt-core's install-dir
  resolution (**REQ-INSTALL-11**, v0.8.0 Feature B) is dogfood-proven for both binaries; the interim
  PATH-copy step is dropped from both setup bodies and the interim copies deleted.
- **DONE (2026-06-16):** int scripts flipped REQ-SETUP-ACTIVATE + REQ-DIST-ADAPTER-RELEASE int
  stages green. `ci/setup/activate-int.sh` = the deregistered→active RE-ACTIVATE assertion (local
  file-form, F-005 bridge); `ci/publish/release-acquire-int.sh` = real `adapter add --release` acquire
  (active + `_github` source + .spt-shipped profiles/strings resolve). Both slow-lane
  (SPTC_ACCEPTANCE=1), both PASS live on spt 0.7.3; `traceable-reqs check` green.
- **DONE (2026-06-16):** the live relay int (REQ-SKILL-LIVE int) — `ci/psyche/live-relay-int.sh`.
  F-007 resolved to a docs-gap (not a missing feature): the non-interactive live bringup is a
  PERSISTENT child `spt api --adapter claude-spt:live --manifest <claude-spt.toml> listen <id>` (the
  Monitor surrogate, heir to `$LIVE start`) — NOT `endpoint run`, NOT `--once`. With `--manifest` the
  in-process listen path spawns the Psyche. Asserts BOTH legs live on 0.7.3: `PSYCHE_SPAWNED` +
  relayed `<EVENT>` + BOUND/READY + live_agent kind. Gotchas baked in: WINPID anchor (not `$$`),
  `bind` before `send`. REQ-SKILL-LIVE flipped to [doc,impl,unit,int].
- **Remaining:** per-OS `adapter.spt` assets · LOCKED v1 setup {1..7} later waves · (on doyle) the
  post-M11 `how-to live` topic → re-point /sptc:live step 2 at the canonical guidance.
- **PRE-POSITIONED (2026-06-15):** monorepo pushed (origin/main); GitHub **release `v0.1.0`** cut with
  the `adapter.spt` asset (https://github.com/SaberMage/spt-claude-code/releases/tag/v0.1.0).
  `spt adapter add --release SaberMage/spt-claude-code` is ready to run **the moment spt v0.7.3
  publishes** (doyle pings). Asset is Windows-only (native binaries) — per-OS assets a follow-on.
