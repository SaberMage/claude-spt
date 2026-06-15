# CI-ACCEPTANCE — JIT plan (slice 1)

> Activates **REQ-CI-ACCEPTANCE** (doc→impl) and **REQ-HAZARD-PERCH-COLLISION** (unit).
> Seeds the real-`claude`-as-SUT acceptance lane. Harness-agnostic POSIX sh; runs on the fleet.

## Scope (this slice)

Scripted orchestration that spawns a **real `claude` session as the system-under-test**, wired
with the sptc UserPromptSubmit hook, and asserts a deterministic **side-effect (digest marker)** —
proving the harness-contract hook entry point fires inside a real harness. The LLM is the SUT; the
orchestration is deterministic and never judges model text.

Deliberately NARROW for slice 1: assert UPS-hook-fires-in-real-claude via a hook-written digest
file (not the spt bus, not model output) — isolates the adapter-glue contract from bus/auth flake.
Bus-delivery acceptance (poll→additionalContext over real spt) is a later slice, gated on
REQ-MSG-ENVELOPE (doyle/todlando).

## Hard invariant (headline — perch collision)

The acceptance harness's whole job is spawning nested `claude`s. A nested session that resolves the
SAME perch id as the live operator agent (`perri`) **tears down the operator's perch + poll stream**
(name-keyed, last-establish-wins; diagnosed 2026-06-15, operator). So:

> **Every nested SUT runs under a DISPOSABLE identity** (`SPT_AGENT_ID=sptc-ci-<n>`), never a live
> agent name. The harness MUST set it; a unit test proves the harness never emits a live id and
> always overrides `SPT_AGENT_ID`/`OWL_SESSION_ID`.

→ new KNOWN-HAZARDS entry 2 + `REQ-HAZARD-PERCH-COLLISION` (`["unit"]`).

## Tasks

1. `traceable-reqs.toml`: add `REQ-HAZARD-PERCH-COLLISION` (`["unit"]`); flip `REQ-CI-ACCEPTANCE`
   → `["doc","impl"]`. Add `ci/acceptance` to `[scan].roots`.
2. `docs/KNOWN-HAZARDS.md`: entry **2. Perch collision** (failure/invariant/mapping/cite).
3. `ci/acceptance/lib.sh`: `sptc_ci_identity` (disposable id + isolated env), `sptc_ci_mkproject`
   (temp project + `.claude/settings.json` + digest-writing UPS hook fixture), `sptc_ci_assert`.
4. `ci/acceptance/run-acceptance.sh`: orchestrator — scaffold → spawn `claude -p` under disposable
   id → assert digest marker → teardown. **Env-gated**: skips cleanly (rc 0) unless
   `SPTC_ACCEPTANCE=1` and `claude` on PATH, so deterministic gates stay green auth-free.
   Carries the `int->REQ-CI-ACCEPTANCE` evidence tag (execution = slow lane).
5. `tests/acceptance-harness.sh`: UNIT test of the deterministic harness pieces — identity
   isolation (perch-collision guard → `unit->REQ-HAZARD-PERCH-COLLISION`), scaffold shape, assert
   helper, env-gate skip. No real `claude` spawned. Wired into `run-gates.sh` unit loop already.
6. `docs/CI.md`: note (a) **pre-push is correct** (git has no client-side post-push); (b) the
   disposable-identity acceptance invariant.

## Gate

`sh ci/run-gates.sh` ⇒ PASS · `traceable-reqs check` green. Commit atomically, `Co-authored by: perri`.

## Follow-up (not this slice)

Attempt one real `claude -p` acceptance run under disposable id; if green, add `int` tag to
`run-acceptance.sh` evidence + flip `REQ-CI-ACCEPTANCE` to include `"int"`; report byte result to
doyle. Hold `int` until actually demonstrated (activate-don't-pre-fail).
