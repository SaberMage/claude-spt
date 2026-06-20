# SESSIONSTART-BRIEF-PLAN — agent-facing SessionStart relay

> JIT plan. Closes the parity gap: legacy owl injects identity at SessionStart
> (`<owl-active-perch>` / `<spacetime-reorientation>`); the sptc adapter injects
> nothing. Grilled 2026-06-19 (perri ↔ operator). REQ: `REQ-DIST-SESSIONSTART-BRIEF`.

## Scope

`session-start.sh` (today: silent `exit 0`) emits agent-facing briefs as
`hookSpecificOutput.additionalContext`, by session state:

| state | trigger | brief |
|---|---|---|
| has perch | `bind` (`$SPT_ENDPOINT_ID`) + `boundary` (clear/compact) | **identity**: who (`{id}`) + perch-live/don't-re-arm + send + reply + roster |
| no perch | `seed`/fresh `startup`, **peer-gated** | **ring**: `spt ring … --timeout 60` + roster |
| seed w/o peers · subagent (`agent_type` set) | — | nothing |

Not in scope: live-vs-ready flavoring (deferred — public liveness-query gap, logged
with doyle, post-v0.13.0 `spt whoami --json`); boundary psyche resume (separate path:
active `echo_commune`, daemon-fired).

## Locked decisions (grill ledger)

1. **Scope = bind + boundary for identity; seed for ring.** Seed needs no identity
   (the agent ran the CLI → already knows its id). No-perch ring brief is net-new
   (no legacy precedent).
2. **Altitude = lean.** Identity preamble + curated messaging only. No full command
   card. Perched agents get send + reply (NOT ring — they have an id). No-perch gets
   ring (the no-id reach path, per send SKILL.md gating).
3. **Discriminator = id-present vs id-absent**, not live-vs-ready. Ready agents get
   the identity brief (send/reply), not ring.
4. **Roster line** (`spt endpoint list`) in **both** blocks.
5. **Sourcing = adapter strings, unified.** All prose → `[strings.briefs]` (mirrors
   `[strings.skills]`); hook composes + `{id}`-substitutes, never authors prose.
   One-liners inline in the manifest; multi-line → `adapter/strings/briefs/*.md`.
   Composable (no duplication):
   - `briefs/identity.md` (file, `{id}`) — who + perch-live + don't-re-arm
   - `briefs/messaging-perch.md` (file) — send + reply
   - `briefs/messaging-no-perch.md` (file) — ring
   - `briefs.endpoint-list` (inline one-liner) — shared roster line
6. **id resolution** (bind & boundary): `$SPT_ENDPOINT_ID` first, then `sptc_self_id`
   fallback.
7. **Peer gate** (ring brief): line-count presence on `spt subnet status` (>1 line ⇒
   peers ⇒ emit). No column-value parsing (doyle: don't parse columnar stdout).
8. **Liveness flavor dropped** — single liveness-agnostic identity brief. No Psyche
   line. Finding logged with doyle.

## Tasks

- [ ] `adapter/claude-spt.toml`: add `[strings.briefs]` (file pointers + inline
      `endpoint-list`); register on `adapter add`/`update`.
- [ ] `adapter/strings/briefs/{identity,messaging-perch,messaging-no-perch}.md`.
- [ ] `_common.sh`: `sptc_compose_brief` (select by state, resolve strings via
      `spt adapter get-string`, `{id}` sed-subst, concat) + a JSON-string encoder
      (`"` `\` newline→`\n`) for additionalContext + `sptc_node_has_peers`
      (line-count gate).
- [ ] `session-start.sh`: per verb — `bind`/`boundary` → identity (id resolved,
      `$SPT_ENDPOINT_ID` then whoami); `seed`+`startup`+peers → ring. Skip
      `agent_type`. Emit `hookSpecificOutput` JSON. Keep registration side-effects.
- [ ] `docs-site` harness-contract: document the SessionStart brief surface.
- [ ] Tests: brief composition, `{id}` subst, peer-gate line-count, `agent_type`
      skip, JSON-encode round-trip; int — bind/boundary emits resolved brief vs a
      live perch.
- [ ] Tag evidence `[doc|impl|unit|int->REQ-DIST-SESSIONSTART-BRIEF]`; **activate**
      the REQ (`required_stages`) as stages land.

## Gate

Build green · `traceable-reqs check` green (REQ activated + all stages tagged) ·
hooks-parse + new unit tests pass · no hardcoded agent-facing prose in `_common.sh`
(overflow-fallback excepted).

## Future-nicety (non-blocking)

- When doyle ships `spt whoami --json {id,kind,...}`: add live/ready identity flavor
  (Psyche/commune line for live).
- Cleaner peer signal (`spt subnet status --json`/count) would retire the line-count
  gate — fold into the same doyle ask if cheap.
