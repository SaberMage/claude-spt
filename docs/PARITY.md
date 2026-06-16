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
| `/live` | KEEP | operative — `skills/live.md` (`:live` profile + Monitor relay) | ✅ parity |
| `/commune` | KEEP | operative — `skills/commune.md` (file-drop) | ✅ parity |
| `/ready` | KEEP | operative — `skills/ready.md` | ✅ parity |
| `/send` | KEEP | operative — `skills/send.md` | ✅ parity |
| `/list-agents` | KEEP (→ `spt endpoint list`) | operative — `skills/list-agents.md` | ✅ parity |
| `/signoff` | KEEP (harness-hosted v1) | operative — `skills/signoff.md` | ✅ parity |
| `/force-stop` | KEEP (topology-aware) | operative — `skills/force-stop.md` | ✅ parity |
| `/spt:setup` | ADD | operative — `skills/setup.md` | ✅ parity |
| `/spt:version` | ADD | operative — `skills/version.md` | ✅ parity |
| profiles + strings + hints | ADD | wired (`:deep`, `:live`, `[strings]`, `[[hints]]`) | ✅ parity |
| **subnet skills (create/join/show-code)** | ADD (LOCKED) | **absent** | 🔨 BUILD (REQ-SKILL-SUBNET) |
| **ccs profiles (`claude-spt:glm` …)** | ADD (LOCKED) | **absent** | 🔨 BUILD (REQ-CCS-PROFILES) |
| `/whoami` skill | **DROP** (core `spt whoami` stays → M12 `endpoint list` alias) | operative (carry-over) | ⛔ REMOVE |
| `/new-alarm` | accepted gap | dead stub, no manifest entry | ⏸️ DEFER + remove stub |
| `/fork` | DROP | absent | ✅ confirmed absent |
| `/amend-signoff` | DROP | absent | ✅ confirmed absent |
| `/revive` | DROP (daemon owns liveness) | absent | ✅ confirmed absent |
| `/clear-psyche` | DROP (= delete+recreate endpoint) | absent | ✅ confirmed absent |

TRANSFORM bucket (already realised, not skills): capsule→spt-hosted+`cc` (`[session.self]` +
`shortcut_basename="cc"`); echo-commune→`[digest]` extractor (`claude-spt-digest`); psyche-sync→
`/spt:setup`; doctor→setup-verify; working-perches→`api worker-start/stop` hooks. ✅

## Open divergences and dispositions

### subnet skills — LOCKED-ADD gap → BUILD
The published surface carries the verbs (`spt subnet {create,join,show-code,status,…}`), and v1
topology scope is **mandatory** (operator vetoed harness-hosted-only — cross-subnet/PTY proof is
spt-core's central value prop, SCOPE). So this is a real gap to fill, not defer. → `REQ-SKILL-SUBNET`.

### ccs profiles — LOCKED-ADD gap → BUILD
SCOPE §ccs (LOCKED): ccs ships as **profile templates** under the adapter (`claude-spt:glm`, …)
that retarget the spawn/psyche/echo command templates through `ccs <profile>`, with a per-profile
`~/.ccs` log dir. Templates only — the user supplies their own ccs config/keys. → `REQ-CCS-PROFILES`.

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
is a deliberate deferral (DEFERRED.md:43, ADR-0018 Q4/V3 — deferred because the daemon had no
one-shot consumer; building pre-consumer = untested dead code). The **operator has a superseding
"arrangement" system** in mind that would replace the alarm port. Disposition: **do not build an
adapter-side stopgap timer** (throwaway vs the coming model); **no REQ minted**; **remove the dead
`/sptc:new-alarm` stub** from the published surface (deferred ≠ shipping a no-op skill). doyle loops
me when the arrangement design surfaces.

## Parity verdict
**Not yet proven.** Two LOCKED-ADD surfaces (subnet skills, ccs profiles) are unbuilt and one DROP
(whoami skill) is unhonored. Parity is proven — and the succession flip unlocked — once those three
close (this slice) with the rest already ✅. `/new-alarm` is an accepted, documented gap and does
**not** block the parity verdict.
