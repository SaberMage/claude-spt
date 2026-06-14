# spt-claude-code — scoping decision ledger

> Running source of truth for the scoping session (started 2026-06-13, doyle).
> Decisions marked **LOCKED** are user-ratified; **OPEN** are still in grill.
> This project will be re-homed onto the `experimplate` template structure once
> that template is authored — until then this ledger is the interim record.

## What this project is

**LOCKED.** `spt-claude-code` is the rebuilt Claude Code harness adapter (the
`claude-spt` adapter) — simultaneously:
1. spt-core's **v1 acceptance proof** (feature parity with legacy `claude_skill_owl`,
   delegating all core to `spt.exe`).
2. spt-core's **first casual-end-user entrypoint** — published as a CC plugin on
   `SaberMage/cplugs`, like legacy spt today.
3. Invisibly an **spt-core installer** for users who don't have it. This is the
   intended pattern for *all* casual-facing harness/shell adapters.

Parity is **user-facing feature parity, NOT 1:1** — most legacy machinery moved
INTO spt.exe/daemon; the adapter is the CC-specific shell only. Dead/rare legacy
concepts get dropped (parity-trim → REQ seed, OPEN). Built by maintainer **perri**
from `SaberMage/spt-releases` + GH Pages docs ONLY (public surface), never the
spt-core source tree.

Legacy parity inventory: captured in this session (claude_skill_owl v1.11.25 —
7 hooks, 12 `/spt:*` skills, owl.exe, cplugs marketplace; messaging / live-agent /
working-perches / binary-handoff / psyche-sync / doctor).

## Distribution architecture

**LOCKED.** Split by volatility (Claude Code has NO plugin-file integrity check —
in-place edits don't orphan; only old version dirs orphan on update, GC'd 7d):

| Layer | Contents | Home | Update path | Churn |
|---|---|---|---|---|
| Plugin (marketplace) | namespaced `/spt:*` skill *skeletons*, `hooks.json` (call `spt api`), SessionStart bootstrap (installs spt-core if absent), `plugin.json` | `SaberMage/cplugs` | `claude plugin update` (rare structural changes only) | low |
| spt binary | all logic | spt-core domain | spt-core's own framework (signed, peer-propagated) | high |
| CC adapter manifest | `[digest]` extractor, profiles, strings, hints | spt-core adapter registry (NOT plugin files) | spt-core adapter-update (file-pull) | medium |

- Skills stay **plugin-provided** → keep `/spt:` namespace (user-scope skills can't
  namespace: `~/.claude/skills` → bare `/live`, collision-prone). Rejected global-skills.
- The "bulk" spt-core installs/updates = **manifest + binary**, not the skills.
- Plugin is a true thin skeleton (wrappers + bootstrap) → rarely needs a marketplace bump.
- → ADR-0001 (to write).

### Skill-instruction delivery — **LOCKED: UPS-injection** (fetch-stub VETOED)

A `UserPromptSubmit` hook detects `/spt:X` in the prompt and injects X's real
instructions as additionalContext. SKILL.md files stay skeletons; instruction churn
lives in spt-core-conducted `[strings]` (file-backed — see M12 dep).
- **fetch-stub VETOED** (operator): adds terminal noise + latency + an extra tool call.
- UPS-injection chosen on operator's empirical confidence from legacy: UPS *does* pick up
  slash-commands (CC highlights slash-commands anywhere in the entry field and isn't strict
  about trailing text). My fact-check called this undocumented/uncertain — **must confirm
  empirically at build time**, but design on it.
- Long instruction bodies → **file-backed adapter strings** (M12 spt-core dep #1) so the
  manifest doesn't bloat.
- `[hints]` channel (same UPS hook, keyword-triggered) kept as-is — legacy proves it works.

### Update notification — **LOCKED**

spt-core conducts updates seamlessly → users don't check. Version-of-truth =
manifest/binary version spt-core tracks (`spt adapter list` / `/spt:version`), NOT the
~static marketplace skeleton version. On update applied: spt-core announces via one-time
SessionStart additionalContext (changelog) + optional `notify`. Update path = file-pull
(real channel) + cautionary `claude plugin update` (skeleton sync) — dual, kept in sync.

## ccs integration

**LOCKED.** ccs = **profile(s) under spt-claude-code** (`claude-spt:glm`,
`claude-spt:kimi`, …), NOT its own adapter. It's structurally CC — only launch command +
model/billing backend differ, which is exactly the profile seam (leaf-replace
spawn/psyche/echo command templates). Per-profile `~/.ccs` log dir → profile also
leaf-replaces the history/`[digest]` locate-template. **Hybrid** delivery: ship the
profile *templates* (ccs-invoking command structure), user supplies own ccs config/keys.
Reconcile spt-core CONTEXT.md: cross-adapter fallback must target `<adapter>:<profile>`,
not only bare adapter_name (profile model already supports composite addressing).

## `/spt:setup` skill

Needed because most users install the plugin **mid-session** (no SessionStart fire).
Proposed paths:
1. Generate `cc`/`cc <id>` launcher (capsule-style) at project root
2. Offer `.gitignore` the launchers
3. Offer create first subnet — surfaces a **QR code** of the TOTP seed → spawns a window
   (self-elevating; see elevation + M12 dep #2)
4. If spt-core already installed → branch: new subnet / **join subnet (= add this machine)** /
   show join-code / just-add-endpoint  *(join == add-this-machine — collapsed)*
5. Legacy migration — detect claude_skill_owl/owl → migrate identity+agents+psyche
   (spt-core CONTEXT.md first-class commitment)
6. OS-service registration (always-on daemon)
7. ccs profile wiring — if `~/.ccs` present; **also offer to install ccs** (+1-sentence value
   prop) if absent
8. Psyche cross-machine sync — **in-subnet sync is AUTOMATIC** (confirmed, M4-D6c); only the
   optional off-subnet/hub-mode backup remains, retired-as-default → near-zero v1 surface
9. Doctor/verify at end

**LOCKED:** v1 = {1,2,3,4,5,6,7}, defer {8,9}. Item #1 (`cc` launcher) IS in v1 — depends on
full-fat M12 (gating prerequisite, todlando-built before perri starts). `cc` wraps
`spt endpoint run` defaulted to claude-spt. _Operator "9. agree" then "except 9" — deferred 9;
flag if verify should fold inline._

### `cc` launcher (capsule-style) — **LOCKED (design)**

= thin wrapper over spt-core's **spt-hosted topology** (broker PTY + inject + attach),
NOT a reimplemented psmux. `cc <id>` → `spt` spawns-or-attaches a CC endpoint in a broker
PTY. Reattach-if-exists / `--live` / `--resume` = spt-core spawn/resume seam semantics.
No-id picker = reuse spt-core's built-in id-resolution (don't reimplement legacy SEED-001).
Sendkeys hazards = spt-core's inject concern, not the adapter's.
**OPEN gap:** confirm spt-core "remote attach" covers *local user interactive attach* to a
hosted CC session (not just headless PTY).

### Elevation (subnet create/join/show-totp) — **LOCKED (design)**

Detect (interactive? elevated? desktop?) → least-friction path:
Windows = self-elevating UAC window; Linux+desktop = pkexec/polkit or x-terminal-emulator;
Linux+TTY = inline sudo; headless/no-TTY = print exact command, agent relays to user.
Question the premise: scope elevation to only steps that need it (service-install /
firewall / privileged-port) — subnet-create itself likely unprivileged.

## CI model

**LOCKED.** Wholly **agent-driven, autonomous, no LLM-in-the-loop**, on the existing
Win+Linux fleet (hfenduleam + kitsubito). GH runners DROPPED.
- Gates (build, unit, `traceable-reqs check`, manifest-schema) = deterministic scripts.
- Acceptance = scripted orchestration spawning real `claude`/headless sessions as the
  **system-under-test** (LLM is SUT, never the runner); assert spt-state/digest output.
- **Reporting bus = legacy spt** (`$OWL send` CI progress to responsible agent) — dogfoods
  the product as its own CI nervous system.
- Rationale: a stock GH runner physically can't run Claude Code (auth/interactivity);
  only a real harness on the fleet reaches the acceptance bar. spt-core's GH-runner
  justification (heavy multi-platform Rust + signed releases + two-host net) doesn't carry
  — the adapter binary is thin glue and delegates releases/signing to spt.exe.
- **Trigger (LOCKED):** git post-push hook → `$OWL send` pings a fleet runner-agent → runs
  gates → reports over spt. Manual "run gates" = fallback. (Polling rejected: latency + waste.)
  - **NOTE:** the `$OWL send` (legacy spt) binary location must be discovered flexibly — it
    lives in a per-version `~/.claude/` or `~/.ccs/` plugins folder whose path changes each
    version. No further legacy-spt changes anticipated, but the CI bus must locate it robustly.
- This CI pattern → reusable, goes in `experimplate`.

## Parity-trim (→ REQ seed / acceptance bar)

**DROP** (LOCKED): Spine & Touch; binary-handoff/owl.exe trampoline; TCP transport + SQLite
spool + registry + listener internals; localhost-only networking. (all spt.exe/daemon now)

**TRANSFORM** (LOCKED): Capsule→spt-hosted + `cc`; echo-commune Haiku JSONL→`[digest]`
extractor (M10); psyche-sync→subnet/`/spt:setup`; `doctor`→`spt doctor`/setup-verify;
working-perches→`api worker-start/stop`.

**ADD** (LOCKED): `/spt:setup`, `/spt:version`, subnet skills (create/join/show-code),
profiles + strings + hints wiring, ccs profiles.

**DECIDE** (LOCKED): DROP `/spt:fork` + `amend-signoff`. (fork near-unused & only meaningful
harness-hosted; amend-signoff deprecated, folds into a follow-up commune)

**KEEP — FINALIZED** (post-investigation 2026-06-14):
- `/live`, `/commune`, `/ready`, `/send`, `/new-alarm`, `/list-agents` — KEEP. (`/list-agents`
  → `spt endpoint list`.)
- `/signoff` — KEEP. v1 = harness-hosted semantics (writes file; consumed at teardown). The
  spt-hosted "drop user from PTY" UX only applies once `cc`/local-attach lands (fast-follow).
- `/force-stop` — KEEP, topology-aware. spt-hosted routing already has CLI: `spt endpoint
  shutdown` (graceful) + `spt endpoint stop` (soft), both exist.
- `/revive` — **DROP.** Daemon owns psyche-loop + liveness (no orphan/dead-listener states to
  recover); restart = re-`ready`/re-`listen` or `endpoint stop`+bringup. Confirm.
- `/clear-psyche` — **DROP.** Equivalent = delete + recreate endpoint. Confirm.
- `/whoami` — **DROP skill**. Core `spt whoami` STAYS in hot-path but → **becomes an alias for
  `spt endpoint list`** (M12), whose SELF-pin output gains the Self `endpoint description`.

### v1 topology scope — **LOCKED** (operator vetoed harness-hosted-only)
v1 acceptance = legacy parity **AND** cross-subnet/PTY proof (spt-core's central value prop is
networking + PTY ownership). So **spt-hosted mode + local PTY attach + `spt endpoint run`
picker are MANDATORY v1.** → `cc` launcher is IN v1; `/spt:setup` #1 back in v1.
**Gating prerequisite: full-fat M12 (todlando builds it after this grill, BEFORE perri starts
spt-claude-code).** M12 deliverables incl. `spt endpoint run` (picker — see
`../spt-core/M12-ENDPOINT-RUN-PICKER.md`) + `spt rc` (cross-node PTY connect) + whoami→alias.

## spt-core upstream deps
Recorded in `../spt-core/M12-CANDIDATES.md` (1: file-backed strings · 2: subnet QR +
self-elevating window · 3: spt-hosted bringup + PTY attach · 4: fallback targets
adapter:profile · 5: whoami obsolescence). spt-claude-code blocks on these.

## experimplate (template) — resolved content
- **Release procedure = generic shape + placeholders** (CHANGELOG · version bump · tag · GH
  Release on same repo); project fills publish specifics. spt-claude-code's publish = cplugs
  marketplace + spt-core adapter-registry; **release is light — signing delegated to spt.exe**
  (not spt-core's two-key/counter runbook).
- **Docs = same-repo `docs-site/` → GH Pages, mdBook, CI-gated against drift.** Reuse
  **spt-core's docs CSS / page-layout / styling as a shared transferable theme** (it's strong;
  carry it across all consumer projects). DOCS-STRATEGY reframed separate-repo→same-repo.
- AGENTS.md = source of truth + thin `CLAUDE.md`=`@AGENTS.md` stub.
- Must teach acquisition of `traceable-reqs` + the grill-with-docs skill (toml/INSTANTIATE).

## Open threads (grill queue)

- [ ] CI trigger mechanism (git-hook signal vs polling routine)
- [ ] Handoff framing to perri (package presentation + public-surface-only constraint)
- [ ] Docs split: what lands in experimplate vs spt-claude-code
- [ ] experimplate authoring: finalize skeleton + write INSTANTIATE.md
- [ ] (downstream) confirm `/spt:setup` #9 verify fold-inline vs deferred
