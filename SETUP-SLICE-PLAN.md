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

## Open questions (resolve before wiring the blocked parts)

1. **[BLOCKER — doyle, asked 2026-06-15 owl Q1–Q3] End-user `--github` target topology.**
   `adapter add --github` looks for `manifest.toml` at the **clone root**, no subpath. Our dev repo
   is a monorepo (manifest in `adapter/`). So `--github SaberMage/spt-claude-code` would miss.
   Need doyle's ruling: monorepo subpath support? or dedicated adapter repo (root = `manifest.toml`
   + `strings/`)? or a published orphan-branch/release-artifact whose root is the manifest? **This
   decides repo topology + what string the setup `--github` branch uses.** Local-dir activation is
   unblocked regardless.
2. **End-user binary delivery for `claude-spt-digest` / `claude-spt-psyche`.** Command templates
   resolve from PATH; a casual end-user has neither binary. How do they install (ride `install.sh`?
   ship in the `--github` adapter repo per doyle's "manifest + extractor/runner binaries"? a
   `cargo install`?). Affects whether an activated adapter actually *functions* end-to-end. (Tied to
   C — the published adapter repo.)
3. **Setup context detection.** How does the skill tell "operator dogfooding from a repo checkout"
   (→ local-dir form) from "casual end-user, plugin only" (→ `--github` form)? Likely: probe for a
   local `adapter/claude-spt.toml` relative to a known root; else `--github`.

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
- **Plan + `REQ-SETUP-ACTIVATE` seeded (this commit).** Wave-1 build **HELD on OQ1** (doyle topology
  ruling) for the end-user `--github` branch; the **local-dir activation path is buildable now** and
  is what the operator's dogfood exercises. Resume Wave 1 on doyle's reply.
