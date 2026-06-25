# Parity audit — claude-spt vs the legacy owl surface

> The reconciliation record: the adapter's operative surface measured against the **LOCKED
> parity-trim** in `SCOPE.md` (KEEP / ADD / DROP / TRANSFORM). This is the **"proven parity"**
> gate the `sptc`→`spt` succession flip depends on (see `docs/RELEASE-RUNBOOK.md` +
> `docs/KNOWN-HAZARDS.md`): the name flip happens only once this audit shows no unresolved
> divergence AND legacy owl is retired. Audited 2026-06-15 against published spt v0.7.2.
>
> Public-surface-only binds (AGENTS.md): a capability missing from the published `spt` surface is
> a **finding**, never a reason to reach into spt-core source.

<!-- [doc->REQ-PARITY-AUDIT] -->

## Disposition matrix

| Surface | SCOPE bucket | Adapter today | Status |
|---|---|---|---|
| `/live` | KEEP | operative — `skills/live.md` (base-manifest `[session.psyche_init]` + bare `api listen` + Monitor relay; Option A, no `:live` profile) | ✅ parity |
| `/commune` | KEEP | operative — full-fat plugin SKILL (agent-self-driven, not injected) | ✅ parity |
| `/ready` | KEEP | operative — `skills/ready.md` (injected) | ✅ parity |
| `/send` | KEEP | operative — full-fat plugin SKILL (agent-self-driven, not injected) | ✅ parity |
| `/list-agents` | KEEP (→ `spt endpoint list`) | operative — `skills/list-agents.md` (injected) | ✅ parity |
| `/signoff` | KEEP (harness-hosted v1) | operative — full-fat plugin SKILL (agent-self-driven, not injected) | ✅ parity |
| `/force-stop` | KEEP (topology-aware) | operative — `skills/force-stop.md` | ✅ parity |
| `/spt:setup` | ADD | operative — `skills/setup.md` | ✅ parity |
| `/spt:version` | ADD | operative — `skills/version.md` | ✅ parity |
| profiles + strings + hints | ADD | wired (`:ccs`, `[strings]`, `[[hints]]`; live-capability is in base, not a profile) | ✅ parity |
| subnet skill (status/create/show-code/join) | ADD (LOCKED) | operative — `skills/subnet.md` (wraps `spt subnet`) | ✅ parity (REQ-SKILL-SUBNET) |
| ccs profile (`claude-spt:ccs`) | ADD (LOCKED) | operative — `[profiles.ccs]` overlay + CLAUDE_CONFIG_DIR-aware extractor | ✅ parity (REQ-CCS-PROFILES) |
| `/whoami` skill | **DROP** (core `spt whoami` stays → M12 `endpoint list` alias) | removed (was carry-over) | ✅ dropped |
| `/new-alarm` | accepted gap | dead stub, no manifest entry | ⏸️ DEFER + remove stub |
| `/fork` | DROP | absent | ✅ confirmed absent |
| `/amend-signoff` | DROP | absent | ✅ confirmed absent |
| `/revive` | DROP (daemon owns liveness) | absent | ✅ confirmed absent |
| `/clear-psyche` | DROP (= delete+recreate endpoint) | absent | ✅ confirmed absent |

TRANSFORM bucket (already realised, not skills): capsule→spt-hosted+`cc` (`[session.self]` +
`shortcut_basename="cc"`); echo-commune→`[digest]` extractor (`claude-spt digest`); psyche-sync→
`/spt:setup`; doctor→setup-verify; working-perches→`api worker-start/stop` hooks. ✅

## Open divergences and dispositions

### subnet skills — LOCKED-ADD gap → BUILD
The published surface carries the verbs (`spt subnet {create,join,show-code,status,…}`), and v1
topology scope is **mandatory** (operator vetoed harness-hosted-only — cross-subnet/PTY proof is
spt-core's central value prop, SCOPE). So this is a real gap to fill, not defer. → `REQ-SKILL-SUBNET`.

### ccs profile — LOCKED-ADD gap → BUILT ✅
<!-- [doc->REQ-CCS-PROFILES] -->
SCOPE §ccs (LOCKED): ccs ships as a **profile template** under the adapter that retargets the spawn
command template through `ccs`, with ccs's relocated log dir honored. Templates only — the user
supplies their own ccs config/keys. **Operator ruling (2026-06-15):** the shipped profile is
`claude-spt:ccs` invoking **bare `ccs`** (the account set via `ccs auth default <name>`), NOT
`glm`/`kimi` — those were SCOPE *examples*; this profile IS the worked example of adapter-profile
authoring **and** the operator's own SPT-ecosystem hook. Built + validated against the known-good
sister project **claude_skill_owl**:
- **Spawn seam.** `[profiles.ccs.session.self].command = "ccs"` leaf-replaces the base `claude`.
  owl proves ccs is a drop-in for the `claude` binary on the same argv (`live/wrapper/claude.rs`
  Tier-2 PULSE recovery latches `cli_binary = "ccs"`); `SPT_ENDPOINT_ID` rides inherited env through
  the wrapper unchanged.
- **Log-dir seam → in the extractor, not a manifest leaf.** ccs relocates CC's whole state tree
  (incl. `projects/`) via the **`CLAUDE_CONFIG_DIR`** env var (`~/.ccs/instances/<account>/.claude`),
  a per-account runtime value with no static catalog path. SCOPE's "per-profile `~/.ccs` log dir"
  is therefore honored **in `claude-spt digest`** (dir-locate branch prefers `$CLAUDE_CONFIG_DIR/
  projects` over the `--in` root) — the owl-validated `owlery::claude_projects_root` pattern. The
  base `[digest]` config thus serves base **and** ccs sessions transparently; no `[profiles.ccs.
  digest]` leaf. This env-aware resolver is REQ-CCS-PROFILES's `impl`/`unit` evidence (a `.toml`
  profile leaf alone does not register as `impl`).
- **Finding (refines SCOPE's model).** SCOPE conflated ccs *profiles* (glm/kimi = API-provider
  env-swap, NO transcript relocation) with ccs *accounts* (isolated instances that DO relocate via
  `CLAUDE_CONFIG_DIR`). The operator runs the account/default path, which relocates — so the digest
  seam is real, but its mechanism is `CLAUDE_CONFIG_DIR`, not a fixed `~/.ccs` path. → `REQ-CCS-PROFILES`.

### `/whoami` skill — DROP (honoring LOCKED)
SCOPE DROPs the whoami **skill**; core `spt whoami` stays in the hot path (and becomes the
`endpoint list` alias in M12). The adapter currently still ships a whoami skill (a carry-over from
an early slice). Operator confirmed the drop 2026-06-15. Action: remove `[strings.skills].whoami` +
the file body + the plugin stub; redirect the "who am i" hint to core `spt whoami`. No REQ rides
whoami evidence (the file-backed-string + UPS-injection int examples repoint to `skills.ready`;
the hook-parser unit examples repoint to a surviving skill name). Core `spt whoami` calls in the
hooks (`session-start.sh`, `_common.sh`) are the CLI, not the skill — they STAY.

### `/new-alarm` — ACCEPTED GAP (deferred-pending-arrangement-system)
**Not missing — deliberately deferred.** doyle triage (2026-06-15): spt-core carries only the
alarm *event shape* (spt-proto) + relay handling (psyrelay.rs) + a test fixture; the durable
"fire-at-target-time" timer still lives in legacy owl in-memory, and an in-daemon durable scheduler
is a deliberate deferral (DEFERRED.md:43 — deferred because the daemon had no
one-shot consumer; building pre-consumer = untested dead code). The **operator has a superseding
"arrangement" system** in mind that would replace the alarm port. Disposition: **do not build an
adapter-side stopgap timer** (throwaway vs the coming model); **no REQ minted**; **remove the dead
`/sptc:new-alarm` stub** from the published surface (deferred ≠ shipping a no-op skill). doyle loops
me when the arrangement design surfaces.

## Parity verdict
**PROVEN (adapter surface).** All three open divergences are closed this slice: subnet skill added
(`skills/subnet.md`, REQ-SKILL-SUBNET), ccs profile added (`[profiles.ccs]` + CLAUDE_CONFIG_DIR-aware
extractor, REQ-CCS-PROFILES), whoami skill dropped. The full KEEP/ADD set is ✅ and the DROP set is
confirmed absent. `/new-alarm` is an accepted, documented gap (deferred-pending-arrangement-system)
and does **not** block the verdict.

The `sptc`→`spt` succession flip remains separately gated (NOT unblocked by this verdict alone):
it also requires **legacy owl retired** (KNOWN-HAZARDS / RELEASE-RUNBOOK) and rides the live-relay
int held for spt-core M11 counter-15. This audit clears only the parity precondition.
