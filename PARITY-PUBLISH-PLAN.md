# JIT plan — parity audit → fill LOCKED-ADD gaps → cplugs publish (as sptc)

> Next slice after the live sub-slice (4b042cc) + F-004 flip (692b67c). Goal: PROVE parity
> against the SCOPE.md LOCKED parity-trim, fill the remaining LOCKED-ADD gaps, then publish the
> thin skeleton to cplugs **as `sptc`** (NOT `spt` — succession flip stays gated, see
> [[succession-flip-gated]] / RELEASE-RUNBOOK). Public-surface-only still binds (AGENTS.md).

## Operator decisions (locked this session, 2026-06-15)
1. **Slice = audit + fill gaps + publish.** Build the absent LOCKED-ADD surface (subnet skills,
   ccs profiles), reconcile whoami, THEN publish as sptc. `new-alarm` stays **deferred** — doyle
   TRIAGED it (high-prio 2026-06-15) as an **ACCEPTED parity gap = "deferred-pending-arrangement-
   system", NOT missing**: spt-core has only the alarm event shape + relay handling + a test
   fixture; the durable timer is a deliberate deferral (DEFERRED.md:43, ADR-0018 Q4/V3), and the
   operator has a superseding "arrangement" system in mind. **Do NOT build an adapter-side stopgap
   timer** (throwaway vs the coming model), **no REQ minted**. Remove the dead stub (deferred ≠
   shipping a no-op skill); doyle loops me when the arrangement design surfaces.
2. **Drop the `/whoami` SKILL.** Honor the LOCKED SCOPE decision — core `spt whoami` stays
   (becomes the `endpoint list` alias in M12); the adapter ships no whoami skill.

## Parity matrix (current vs SCOPE LOCKED parity-trim)

| Legacy / target surface        | SCOPE disposition        | Adapter today          | Action (this slice)            |
|--------------------------------|--------------------------|------------------------|--------------------------------|
| /live /commune /ready /send    | KEEP                     | operative (file-backed)| ✓ none                         |
| /list-agents /signoff /force-stop | KEEP                  | operative              | ✓ none                         |
| /new-alarm                     | ACCEPTED GAP (deferred-pending-arrangement-system) | dead stub, no manifest | **remove stub**; no REQ, no build |
| /spt:setup /spt:version        | ADD                      | operative              | ✓ none                         |
| profiles + strings + hints     | ADD                      | wired (deep/live)      | ✓ none                         |
| **subnet skills (create/join/show-code)** | ADD (LOCKED)  | **ABSENT**             | **BUILD** (Phase C)            |
| **ccs profiles (claude-spt:glm …)** | ADD (LOCKED)        | **ABSENT**             | **BUILD** (Phase D)            |
| /whoami SKILL                  | DROP skill               | **operative (violation)** | **REMOVE** (Phase B)        |
| /fork /amend-signoff /revive /clear-psyche | DROP         | absent                 | ✓ none (confirm absent)        |

Public surface confirms the ADD gaps are buildable: `spt subnet {create,join,show-code,status}`
exists; ccs = profile overlays retargeting command templates (SCOPE §ccs, profile *templates*
only — user supplies their own ccs config/keys).

## Progress (this session)
- ✅ **Phase A** (b1db67f) — docs/PARITY.md matrix + REQ seed (REQ-PARITY-AUDIT [doc] satisfied;
  REQ-SKILL-SUBNET / REQ-CCS-PROFILES seeded). DROP set confirmed absent.
- ✅ **Phase B** (0595910) — whoami skill DROPPED (manifest + body + stub + hint + test repoints);
  dead new-alarm stub removed. Surface 11→9.
- ✅ **Phase C** (e3382a0) — /sptc:subnet skill added (one skill wrapping `spt subnet`).
  REQ-SKILL-SUBNET [doc,int] green on v0.7.2. how-to-subnet finding logged. Surface 9→10.
- ⏭️ **Phase D** (ccs profiles) — NEXT. Needs research: the spawn/psyche/echo command seams a ccs
  overlay leaf-replaces. Activate REQ-CCS-PROFILES [doc,impl] when starting.
- ⏭️ **Phase E** (publish prep as sptc) — after D.

## Phases (sequence; one commit + green gate each)

### Phase A — Parity audit artifact + REQ seed
- Write `docs/PARITY.md` (the matrix above + per-row evidence/finding) — the "proven parity"
  record the succession flip gates on. Tag `<!-- doc->REQ-PARITY-AUDIT -->`.
- Seed REQs in `traceable-reqs.toml` FIRST (before building): `REQ-SKILL-SUBNET`,
  `REQ-CCS-PROFILES`, `REQ-PARITY-AUDIT`. Activate stages as each phase lands.
- Confirm the DROP set is truly absent (grep no fork/revive/clear-psyche/amend-signoff residue).

### Phase B — Drop the whoami skill (honor LOCKED)
- Remove `whoami = { file = "skills/whoami.md" }` from manifest `[strings.skills]`.
- Delete `adapter/strings/skills/whoami.md` + `plugin/sptc/skills/whoami/`.
- **registration-int.sh** uses `skills.whoami` as the canonical file-backed + UPS-injection
  example (4b/4c) — repoint to a surviving skill (`skills.ready`).
- Redirect the `who am i` **hint** (currently → /sptc:whoami) to core `spt whoami` guidance.
- Audit REQ evidence: nothing is tagged `REQ-*` on whoami.md directly, but check
  `tests/hooks-parse.sh` / manifest-shortcut for whoami coupling before deleting.

### Phase C — Subnet skills (LOCKED ADD; public verbs exist)
- **Open shape decision (resolve at top of phase):** three skills
  (`/sptc:subnet-create|join|show-code`) vs one routing `/sptc:subnet` skill. Lean: match SCOPE's
  enumeration but as ONE `subnet` skill body that documents create/join/show-code (fewer
  surfaces, cleaner UX) — confirm before authoring.
- File-backed body(ies) `adapter/strings/skills/subnet*.md` (run `spt how-to subnet` / wrap the
  real `spt subnet …` verbs); manifest `[strings.skills]` entries; thin SKILL.md stub(s); hint(s).
- `REQ-SKILL-SUBNET` [doc,impl] (+ int via registration-int file-backed-resolve assertion).

### Phase D — ccs profiles (LOCKED ADD)
- **Research first** (mcp/context7 not needed — read SCOPE §ccs + the existing `[profiles.*]`
  command seams). ccs profile = a `[profiles.<glm|kimi>]` overlay that leaf-replaces the spawn /
  psyche / echo command templates to route through `ccs <profile> …`, with a per-profile `~/.ccs`
  log dir. Author profile *templates* only (no user keys).
- Add `[profiles.glm]` (+ maybe `[profiles.kimi]`) overlays; observable via `spt adapter
  get-string claude-spt:glm …` + resolves in registration-int (mirror the :deep/:live assertions).
- `REQ-CCS-PROFILES` [doc,impl] (+ int).

### Phase E — Publish prep (as sptc; NO name flip)
- **Create `CHANGELOG.md`** with a `## [<version>] - 2026-06-15` section (Added/Changed/Fixed,
  user-facing UX only, no internal lingo) — release fails loudly without it.
- **Bump `plugin.json`** `version` 0.0.1 → first real (structural first publish). Keep `name=sptc`.
- Run `sh ci/publish/validate-skeleton.sh` + `sh ci/publish/package-skeleton.sh` (DRY-RUN) green.
- Regenerate docs (mdBook + llms.txt) — drift gate green.
- The actual cplugs commit/push + `claude plugin install sptc@cplugs` stays the **operator's**
  step (credentials + pointer flip) — plan stops at a validated dry-run + a publish checklist.

### Gate (every phase)
`sh ci/run-gates.sh` PASS + `traceable-reqs check` green. Commit `Co-authored by: perri`.

## Open questions (resolve in-phase, don't block planning)
- Subnet skill shape: 3 skills vs 1 routing skill (Phase C top).
- ccs: which profiles ship as templates (glm only, or glm+kimi)? SCOPE names `claude-spt:glm`.
- plugin.json first-publish version number (0.1.0? matches adapter manifest 0.1.0, but RUNBOOK
  says keep them DISTINCT — pick independently).

## Findings carried (not ours to fix)
- new-alarm core alarm/deferred-pulse primitive (blocks new-alarm parity) — doyle.
- hard/no-grace force-stop primitive — doyle.
- Live relay int held for spt-core M11 counter-15 release ([[live-int-gated-m11-counter15]]).

## Done immediately before (context)
- 4b042cc live sub-slice (claude-spt-psyche runner + /sptc:live body, REQ-SKILL-LIVE [doc,impl,unit]).
- 692b67c F-004 flip (digest-proof int GREEN on v0.7.2, REQ-DIST-DIGEST-EXTRACTOR full).
- spt upgraded 0.7.1 → 0.7.2 (operator-approved daemon bounce).
