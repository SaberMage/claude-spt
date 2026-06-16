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

1. **[RESOLVED — doyle, owl 2026-06-15, from source] End-user `--github` target topology.**
   `adapter add` is **ROOT-ONLY, code-confirmed** (`source_manifest_file`): a dir source resolves to
   `<dir>/manifest.toml` **exactly** (exact filename, no scan, no subpath); `--github user/repo`
   reads `<clone-root>/manifest.toml`. Our `adapter/claude-spt.toml` misses on both counts → a
   **doc-gap** (it's in spt-core source, not the published docs; doyle is patching the activation
   docs). **Ruling:**
   - **Local dev** keeps the monorepo `adapter/claude-spt.toml`; activate via the **file-form**
     `spt adapter add ./adapter/claude-spt.toml` (takes any path + any filename).
   - **End-user `--github`** needs a **DEDICATED published adapter repo** (Wave C) whose **root** is
     `manifest.toml` (named exactly) + `strings/` + the binaries the manifest references.
   - **Copy-vs-pointer by `[update]` avenue:** claude-spt's avenue is `delegated`
     (`claude plugin update spt`) → **POINTER mode**: spt-core copies **nothing** into
     `adapters/<name>/`; it reads `manifest.toml` + `strings/` **live from the durable
     `adapters/_github/<safe>` clone**, for life. (`file_pull`/no-`[update]` = COPY mode instead.)
     Root-only holds in both modes.
2. **[RESOLVED via Q3 ruling] End-user binary delivery for `claude-spt-digest` / `claude-spt-psyche`.**
   doyle: the manifest-referenced **binaries are NOT auto-copied** in either mode (only `strings/`
   is). So they must be **resolvable on the target**: absolute path, on PATH, or — in our pointer
   mode — **shipped in the `--github` repo at the manifest's referenced paths** so they resolve from
   the durable `_github` clone. **Action:** our command templates reference the binaries by **bare
   name** (`claude-spt-digest …`, `claude-spt-psyche …`) ⇒ resolved from **PATH**. So end-user
   delivery must put both on PATH (ride the installer) OR we switch the manifest to clone-relative
   paths + ship the binaries in the Wave-C repo. **Decide in Wave C** (lean: ship on PATH via the
   installer — keeps templates portable). Folded into Wave C.
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

### Wave C — the dedicated published adapter repo (the end-user `--github` target) — **on A's critical path**
**Why:** the operator's A-fulfilling dogfood is "install the **plugin**" (the end-user path) → setup
runs `adapter add --github <repo>` → so that repo must EXIST and be correctly shaped. The monorepo
`SaberMage/spt-claude-code` **cannot** be it (root-only rule). **Decision needed (operator):** repo
name + creation (SaberMage org credentials) + the binary-delivery choice (OQ2: on-PATH-via-installer
vs clone-relative-paths-in-repo).
- Lay out repo **root** = `manifest.toml` (the monorepo's `adapter/claude-spt.toml`, renamed) +
  `strings/` (copied) + (per OQ2 decision) the built `claude-spt-digest` + `claude-spt-psyche`.
- A `ci/publish/` step that **generates** this repo from the monorepo `adapter/` (rename + copy +
  drop binaries) so the two never drift — mirrors `package-skeleton.sh` for the cplugs side.
- Verify end-to-end: a clean machine `spt adapter add --github <repo>` → active + a profile resolves
  + digest/Psyche binaries resolve. New REQ (`REQ-DIST-ADAPTER-REPO`) when this wave starts.

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
- **OQ1/OQ2 RESOLVED (doyle, owl 2026-06-15).** Repo topology decided: monorepo file-form for dev;
  dedicated root-`manifest.toml` repo for `--github` (pointer mode, binaries on PATH). Wave 1 is now
  **fully unblocked** — authoring both activation branches.
- **Wave C is on A's critical path:** the operator's "dogfood the plugin" = end-user path = needs the
  dedicated `--github` repo to exist. Surfaced to operator (repo name + creation + OQ2 binary choice).
