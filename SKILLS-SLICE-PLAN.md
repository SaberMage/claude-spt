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
   - **GROUNDED by doyle 2026-06-15 (traced spt-core code) — TWO-PROFILE design CONFIRMED, author it:**
     base `claude-spt` = ReadyAgent (no `psyche_init`); `[profiles.live.session.psyche_init]` overlay =
     LiveAgent. `/sptc:ready` seeds `--adapter claude-spt`; `/sptc:live` activates `--adapter claude-spt:live`.
     - **Q1 propagation CONFIRMED:** `api seed` stores the full `<adapter>:<profile>` → `establish_perch`
       writes it verbatim to info.json `adapter` → daemon `resolve_option_in` SPLITS the composite +
       applies the overlay → BrainLifecycle checks `psyche_init` on the MERGED manifest → Psyche spawns.
       (Empirically `spt api --adapter claude-spt:deep seed` → `SEEDED`.)
     - **Q2 psyche_init keys = EXACTLY `{id, session_id, psyche_dir, psyche_prompt}`.** NOT `{session_name}`
       (that's a `[session.self]` fill — the published manifest.md example wrongly uses it and HARD-FAILS;
       doyle fixed the example). NOT `{psyche_context}` on first spawn (that's the resume/preload seam key).
       In spawn_psyche `{id}` is OVERRIDDEN to `<parent>-psyche`. Template only the four; `keys` a subset.
     - **Q3 Psyche process contract:** FIRE-AND-FORGET DETACHED — spawned with Stdio::null on all three
       fds, handle dropped, NOT supervised (liveness is daemon-authoritative via the perch, not pid).
       Command is adapter-authored + opaque. The Psyche has its OWN perch (`<parent>-psyche`), communicates
       via perch/commune drops (NOT stdin/stdout), authors COMMUNE deltas only (never reply/notify — the
       echo-commune is a DISTINCT cheaper actor/model), exits at session end. → `detach = true`,
       `cwd = "{psyche_dir}"`.
   - **DOC GAPS (doyle's, fixes on a branch/PR):** (a) api.md never stated `--adapter` accepts
     `<adapter>:<profile>` / that the bound profile drives runtime resolution incl psyche_init (the
     WebFetch "not runtime dispatch" wording was the fetch model's paraphrase of the MISSING positive
     contract, not a literal stale line); (b) manifest.md psyche_init example used the never-filled
     `{session_name}`. Both fixed by doyle.
   - **OPEN (impl HOW — the live body/activation is its own sub-slice, NEXT):**
     - **Q-A — RESOLVED 2026-06-15 (doyle, corrected): RELAY PATH works NOW on the interim; Psyche is
       daemon-managed by CONTRACT.** Activation = `/sptc:live` launches `spt api --adapter claude-spt:live
       listen <id>` as a RESIDENT blocking relay **via CC's Monitor tool** (persistent background task;
       stdout streams in) — CC's equivalent of owl's "$LIVE start behind Monitor" (perri runs exactly this
       live). DELIVERY MODEL: READY = UPS api-poll hook; LIVE = the Monitor relay stream IS the pipe → the
       live body/hook RECONCILES (UPS poll no-ops while the relay is up, else double-delivery).
       - **MENTAL-MODEL CORRECTION (doyle, grounded in CONTEXT.md + REQ-DAEMON-1):** the Psyche is
         **spt-core/daemon-managed**, keyed to the LiveAgent endpoint, **DECOUPLED from message delivery**
         — the relay is a dumb pipe (CONTEXT:30,34,38,194). "listen spawns the Psyche" (startup.rs) is the
         **INTERIM** impl, NOT the contract. The daemon-hosted Psyche loop is built + E2E-tested
         (lifecycle.rs run_pulse_loop), but its activation is STAGED behind "the live-agent adapter landing"
         (brainproc.rs no-op today). **claude-spt IS that live-agent adapter** → completing REQ-DAEMON-1
         (M11, doyle/todlando core) coordinates with this slice. **For the build:** declare
         `[session.psyche_init]` (done, the seam); run the Monitor relay (pipe + today's interim Psyche
         trigger); **treat the Psyche as spt-core-managed — do NOT orchestrate its lifecycle in the live
         body**; do NOT hard-code "listen spawns the Psyche" as permanent (post-REQ-DAEMON-1 the daemon
         spawns it for the live endpoint regardless of listen-vs-poll). doyle fixed api.md to the contract.
     - **Q-B — RESOLVED (claude-code-guide agent + doyle boundary ruling): the Psyche RUNNER is MINE to
       build** (spt-core never dictates harness invocation; psyche_init.command is adapter-authored/opaque).
       `claude -p {psyche_prompt}` is **one-shot** (one turn → exits; Stop hooks can't re-loop it) — and
       doyle says migrate OFF `claude -p` anyway (imminent CC billing change). So the runner is a small
       **resident artifact** (like the digest extractor): a detached headless `claude` companion that stays
       alive for the session — a wrapper loop re-invoking `claude --continue` driven by its own
       `<parent>-psyche` perch (poll for turns), authoring commune drops; or the Agent SDK. Build it
       (`tools/claude-spt-psyche` or a wrapper script), then `psyche_init.command` launches it with
       `{psyche_prompt}`/`{psyche_dir}`/`{id}`/`{session_id}`, `cwd={psyche_dir}`, `detach=true`.
   - **SAFE TO AUTHOR NOW (doyle confirmed):** the `[profiles.live.session.psyche_init]` overlay skeleton +
     the four-key contract. Defer wiring it until the runner exists + Q-A resolves, so the live sub-slice
     lands coherent (profile + runner + activation + body together).

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
