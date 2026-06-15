# JIT plan — the 4 live-layer skills (live / commune / force-stop / new-alarm)

> Next slice after large-drain (8487ea0). Fully specced by **doyle's scope ruling 2026-06-15**
> (grounded in spt-core CONTEXT, not memory). Public-surface-only still binds (AGENTS.md). Each
> skill body is a file-backed `[strings.skills].<x> = { file = "skills/<x>.md" }` (F-003 pattern);
> flip the inline summary → `{ file }` pointer; refresh the thin SKILL.md stub.

## doyle's ruling (authoritative for this slice)

1. **live — IN SCOPE.** Semantics = upgrade THIS CC session to a **LiveAgent**; do NOT spawn a
   separate/nested broker-PTY session (that's the `spt endpoint run`/`spt rc`/picker door — a
   different entry). Harness-hosted-bind model: `/sptc:ready` = ReadyAgent (perch + poll, no Psyche);
   `/sptc:live` = upgrade this session to LiveAgent = **trigger the Psyche spawn for it**.
   - **MECHANISM (doyle):** LiveAgent-vs-ReadyAgent is gated by the manifest **`[session.psyche_init]`**
     seam — the daemon BrainLifecycle only spawns the Psyche when the manifest declares it
     (early-returns None otherwise). There is **no "go-live" api verb**. So "this session is a
     LiveAgent" ≡ "its adapter/profile declares `psyche_init`."
   - **RESOLVED (research 2026-06-15):** TWO-PROFILE shape. base `claude-spt` = ReadyAgent (no
     `psyche_init`); `[profiles.live.session.psyche_init]` overlay = LiveAgent. `/sptc:ready` seeds
     `--adapter claude-spt`; `/sptc:live` seeds `--adapter claude-spt:live`. **Empirically the api
     accepts the composite:** `spt api --adapter claude-spt:deep seed …` → `SEEDED`. psyche_init keys
     the daemon fills: `{session_name}` `{psyche_dir}` `{psyche_prompt}` `{psyche_context}`. Example:
     `[session.psyche_init] command="… --name {session_name}" cwd="{psyche_dir}" detach=true`.
   - **DOC GAP flagged to doyle (2026-06-15):** published llms-full.txt says api calls do NOT accept
     profile qualifiers ("profiles are registration/data, not runtime dispatch") — CONTRADICTS the
     empirical `--adapter claude-spt:deep seed` acceptance. Unconfirmed on the public surface: (1) does
     seed→listen PROPAGATE the profile so the daemon spawns the `:live` psyche_init? (2) psyche_init
     {keys} filled for a harness-hosted bind. doyle owns the doc fix; live-daemon int deferred (like
     other acceptance ints) until confirmed.
   - **OPEN design Q to doyle:** the CC Psyche spawn COMMAND (`psyche_init.command`) — what the daemon
     expects the Psyche process to DO (summarizer companion contract? same as legacy owl?). Shapes the
     command (likely `claude` headless w/ {psyche_prompt}/{psyche_context}). **Author on doyle's reply.**

2. **commune — IN SCOPE, FILE-DROP (not a command).** No `api commune` by design. The adapter writes
   `<endpoint_id>-commune.md` into the manifest-declared **`[session].commune_dir`** (a spawn-session
   seam field); the daemon watches/ingests/deletes it (daemon = single writer). So `/sptc:commune` =
   compose the delta + drop the file. **Author `[session].commune_dir` (+ `signoff_dir`) in the
   manifest.** (Schema confirmed: `Session.commune_dir` / `Session.signoff_dir` exist.)

3. **new-alarm — OUT OF SCOPE v1.** No core primitive (spt has internal daemon pulse loops but NO
   user-facing alarm/timed-pulse command; legacy `$LIVE TIMED PULSE` is owl/Psyche-layer, not lifted
   into core). Adapters don't add core features. **Disposition: mark explicit-out-of-scope** in the
   manifest comment + traceability (visible-not-silent). doyle carries a PARITY-GAP FINDING (mint a
   core alarm/deferred-pulse primitive) to the operator.

4. **force-stop — AUTHOR against `endpoint shutdown`** (graceful; runs graceful_signoff via daemon
   BrainLifecycle which owns the Psyche → tears down the LiveAgent's Psyche too) as primary; note
   `endpoint stop` (soft, spool kept) as the lighter variant. The hard/no-grace SIGKILL+immediate-
   teardown ($LIVE 3-step) equivalent is a **core GAP** → doyle's finding, deferred.

## Tasks (sequence; one commit + green gate each, or grouped)

1. **Research** the ready-vs-live authoring path (live mechanism OPEN above). Decide: profiles vs
   single manifest + listen-profile selection. Flag doc gap if unclear.
2. **Manifest:** add `[session].commune_dir` + `signoff_dir`; add `[session.psyche_init]` (+ maybe a
   `:live`/`:ready` profile split per task 1); keep `[session.self]` as-is.
3. **Skill bodies (file-backed):** `adapter/strings/skills/{live,commune,force-stop}.md`; flip the
   inline `commune`/`live` summaries → `{ file }` pointers; add `force-stop` pointer; refresh stubs.
4. **new-alarm:** explicit out-of-scope note (manifest + a REQ or doc line), not a `[strings.skills]`
   entry. Cross-ref doyle's parity finding.
5. **Tests:** extend `ci/manifest/registration-int.sh` (commune_dir/psyche_init accepted +
   file-backed live/commune/force-stop bodies resolve); any new REQ (e.g. REQ-SKILL-LIVE /
   REQ-DIST-SESSION-SEAMS) added to `traceable-reqs.toml` first, then satisfied.
6. **Gate:** `sh ci/run-gates.sh` PASS + `traceable-reqs check` green. Commit `Co-authored by: perri`.

## Findings doyle carries (not ours to author)
- alarm/deferred-pulse core primitive (blocks new-alarm parity).
- hard/no-grace force-stop core primitive (force-stop hard path).
- (pending) ready-vs-live authoring path doc clarity — confirm or flag in task 1.

## Done earlier this session (context)
- d1f14ab `[session.self]` + bind path (REQ-DIST-SHORTCUT-BASENAME [doc,impl,unit]).
- 39c05d1 digest extractor (Rust) (REQ-DIST-DIGEST-EXTRACTOR [impl,unit]; int F-004-blocked, doyle fixing).
- 8487ea0 large-drain cap/spill (ADR-0002 Open #2 resolved).
- 7/11 skills operative pre-slice; this slice targets live+commune+force-stop → 10/11 (new-alarm out-of-scope).
