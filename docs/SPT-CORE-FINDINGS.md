# spt-core public-surface findings

> Per the public-surface-only constraint (`AGENTS.md`, `HANDOFF.md` §1): if a capability needed
> to build the adapter is missing/ambiguous in spt-core's **published** surface (`spt-releases`
> releases + GH Pages docs), that is a **finding** — `spt-core`'s published contract has a gap.
> We report it to the spt-core owner (**doyle**) and do **not** reverse-engineer from legacy
> `claude_skill_owl` or reach into spt-core source. This file is the in-repo log of those findings.

| # | Date | Status | Summary |
|---|------|--------|---------|
| F-001 | 2026-06-14 | **re-scoped 2026-06-15** — most = adapter-authoring (closed); 1 residual spt-core docs item open | Hook-wiring for a CC adapter — boundary clarified |
| F-002 | 2026-06-15 | **RESOLVED-SHIPPED (v0.7.1)** — `<EVENT>` verified on the published `api poll` surface; F-002 dissolved; int flipped | `api poll` agent path has no inter-frame delimiter → multi-message drains are unsplittable |
| F-003 | 2026-06-15 | **RESOLVED + docs CLOSED (v0.7.1)** — capability shipped; the file-pointer syntax is now on the published surface | File-backed `[strings]` IS shipped (value-position table pointer `key = { file = "rel" }`) but was **undocumented** on the published surface |
| F-004 | 2026-06-15 | **CONFIRMED-IMPL-BUG (doyle); fix in progress** — `digest-proof` will fill `{id}`+`{session_id}` matching runtime; int deferred until the carrying release | `spt adapter digest-proof --sample` passes an empty substitution-key map → false-fails any extractor whose command uses `{session_id}` (incl. the published example) |
| F-005 | 2026-06-15 | **TRIAGED (doyle) — (a)+(b) mix, nothing unbuildable** — 2 of 3 sub-claims were docs-read misses; residuals = author Ed25519 key-provisioning doc + zero-touch auto-activation roadmap (REQ-UPD-1/M4). **Bridge that works today: `spt adapter add --release <repo>`** | End-user adapter activation step (`adapter add [--github/--release]`) was undocumented in install-on-demand/checklist; binary-present ≠ adapter-active |
| F-006 | 2026-06-15 | **RESOLVED + interim RETIRED (v0.8.1 dogfood 2026-06-16)** — install-dir resolution (REQ-INSTALL-11) dogfood-proven for BOTH binaries: digest-proof + daemon-hosted Psyche resolve straight from `…/adapters/_github/<safe>/` with nothing on PATH. Interim PATH-copy step dropped from both /sptc:setup bodies; interim copies deleted | `--release` bundles + extracts the adapter binaries beside the manifest, but bare-name `[digest]`/`[session]` templates resolve from PATH only → bundled binaries don't resolve (copy-mode) |
| F-007 | 2026-06-16 | **RESOLVED-SHIPPED (v0.8.0)** — `spt how-to live` topic is live; /sptc:live re-pointed at it; the int's relay leg is green on 0.8.0 (psyche-spawn moved to daemon-host = real-session, see v0.8.0 dogfood note) | `spt how-to live` was `NO_SUCH_TOPIC`; the non-interactive live-bringup was `--manifest` + persistent-child `api listen` (Monitor surrogate) |
| F-008 | 2026-06-16 | **OPEN — reported to doyle** — blocks SCOPE LOCKED v1 setup #5 (legacy migration); /sptc:setup can't author the step against the public surface | No published legacy-migration command (`spt` has no migrate/import/adopt/legacy/owl verb in any subcommand, no how-to) though spt-core CONTEXT.md commits to claude_skill_owl→spt migration as first-class |
| F-009 | 2026-06-16 | **RESOLVED-SHIPPED + RE-VALIDATED (spt v0.8.2, 2026-06-17)**. doyle's fix: command templating now fills each `{key}` as ONE argv element (tokenize-then-fill). Argv-capture confirmed the multi-line `{psyche_prompt}` arrives as a single element, newlines intact. Adapter keeps greedy `--prompt` as defensive | `[session.psyche_init]`/extractor command templating substitutes a `{key}` into the command STRING then WHITESPACE-SPLITS → ANY multi-word fill (e.g. `{psyche_prompt}`) explodes into stray argv tokens. Survived only by single-token fills |
| F-010 | 2026-06-16 | **RESOLVED-SHIPPED + RE-VALIDATED (spt v0.8.2, 2026-06-17)**. A spawn-then-exit psyche now stamps `psyche_host_error{reason:"host not resident within 5s ...", attempts:2}` on the parent perch (rendered `psyche-host: FAILED (...)` by `endpoint list`/`whoami`); status stays online (liveness authoritative). Forced fast-exit confirmed it | Silent-exit still maskable: `psyche_host_error` stays clear when the detached spawn() succeeds but the child exits IMMEDIATELY (e.g. arg-parse exit 2). A crash-on-startup host looks identical to a healthy one |
| F-013 | 2026-06-17 | **ROOT-CAUSED (perri) → RULED spt-core BUG (doyle 2026-06-17): fork (a)**. spt-core must honor `[env].value` substitution in endpoint-run (the schema already promises "with substitution"; not applying it is a silent correctness bug). **Adapter manifest is CORRECT as-is — no wrapper** (b rejected: a shim would dodge a bug every `[env]`-routing adapter hits). Dispatched **`REQ-HAZARD-ENV-SUBST` → todlando, v0.11.0-findings** (pairs with REQ-SEND-SPT-HOSTED). **VERIFIED FIXED + INT LANDED (spt v0.11.0, 2026-06-17)** — endpoint run → populated `SPT_ENDPOINT_ID` → bind → BOUND perch → `spt send` SENT (live PTY inject); missing int landed = `ci/launcher/bind-int.sh` (REQ-CC-LAUNCHER-BIND, 4/4 green); `<0.11.0` silent-seed = doc-noted KNOWN-MINOR (no floor-bump / no guard — env-indistinguishable, ruled); ghost-roster self-healed (REQ-HAZARD-ROSTER-GHOST). **CLOSED.** `spt endpoint run` threads the endpoint `{id}` to the `[session.self]` spawn **ONLY** via `{id}` substitution in the command **argv**; `[env.<VAR>].value = "{id}"` is **NOT** substituted (injects empty) — although the schema documents `value` as "Value to inject (**with substitution**)". A flagless harness (bare `claude`, no CLI flag for an id) cannot place `{id}` on argv → SessionStart sees empty `$SPT_ENDPOINT_ID` → `sptc_register_verb` returns **`seed` not `bind`** → endpoint-run yields **ZERO perch** (the operator's wall-b `NO_PERCH`). bind itself is fine (a direct `api bind` builds a fully reachable perch). Fix fork: (a) spt-core honors `[env].value` substitution → current manifest becomes correct, or (b) adapter ships a wrapper launcher that takes `{id}` on argv and exports `SPT_ENDPOINT_ID` before exec-ing claude |
| F-011 | 2026-06-17 | **CONFIRMED + ROOT-CAUSED (doyle, spt-core source) — case-3 robustness, NON-blocking**. doyle: `registry.rs` `manifest_dir` — Pointer/GhReleaseManaged adapters read the manifest LIVE from `source_dir`; a deferred install whose manifest isn't extracted yet → `load_manifest` fails → `registered()` `filter_map(...ok())` **SILENTLY DROPS** the adapter → zero host_binaries candidates (`ADAPTER_UNRESOLVED`) AND `resolve_option/set_active` reads the absent manifest → bare **os-error-2**. Fix shape (doyle minting REQ-HAZARD→todlando): clear diagnostic at resolver + `adapter use` instead of silent-drop/cryptic-os2, possibly eager manifest extract at register. Real `--release`/extracted-dir installs work (v0.3.0 dogfooded clean). **RECURRED 2026-06-22 via the `*-proof` commands (translate-proof/digest-proof) on a GhReleaseManaged dev adapter — acked + batched by doyle into v0.13.x adapter-DX (a `--dir`/`--manifest` override); see "F-011 (cont.)" below.** | A registered **Pointer**-mode adapter whose deferred install dir lacks the extracted manifest vanishes from the active set: bare resolution fails `ADAPTER_UNRESOLVED` (host_binaries never consulted) and `spt adapter use <adapter>` fails cryptic `os error 2` (no path/cause), even though the manifest declares everything needed |
| F-016 | 2026-06-22 | **RESOLVED — both fixes SHIPPED** (doyle, broker.rs-confirmed). The published `[message-idle-translation-binary]` doc omitted `{commit}` from the stdout vocabulary AND its degenerate baseline `{text}{key:enter}` would itself FAULT. `{commit:true}` is the MANDATORY inject-sequence terminator (`run_inject_worker` broker.rs:1075-1090; no-commit → 5s `INJECT_COMMIT_DEADLINE` FAULT, broker.rs:151-169; reference `{text}{key:enter}{commit:true}` translation.rs:74-78). **(i) adapter binary appends trailing `{commit:true}` — DONE (cc-spt-idle-translate, 11 tests); (ii) contract republished + LIVE on gh-pages 2026-06-22 — `{commit}` in the vocabulary + commit-deadline/inject-floor semantics + corrected degenerate; re-verified by re-fetch.** Residual: end-to-end `translate-proof` re-confirm pending v0.13.1 (counter 28+, runner-load delay, not code). Caught by the blind-build BEFORE a live FAULT | The published harness-contract documented the idle-translation binary's stdout vocabulary as `{key}`/`{delay_ms}`/`{text}` only, with a `{text}{key:enter}` degenerate example — but the broker requires a trailing `{commit:true}` terminator or every delivery FAULTs at the 5s commit deadline. A harness author building from the public surface alone ships a binary that faults live |
| F-017 | 2026-06-22 | **RESOLVED-SHIPPED (spt-core v0.14.0, counter 30) + VALIDATED on real claude-spt (perri, 2026-06-23)**. v0.14.0's endpoint-creation-flow milestone (REQ-RUN-MULTISUBNET-HOME, ADRs 0026/0027) closed it: `spt endpoint run` now HOMES at creation — multi-subnet node w/o `--subnet` → instant **`MULTI_SUBNET_HOME`** refuse + subnet list (0.058s, NOT the old ~25s silent `ENDPOINT_RUN_ONLINE_TIMEOUT`); `--subnet <name>` → homes + harness binds (UNBOUND → online), no HOME_REFUSED. Bonus W-state confirmed: the hollow **UNBOUND** pre-bind row shows in `endpoint list` between spawn and bind. My W6 seed `ci/subnet/multi-subnet-bringup-int.sh` FLIPPED from "gap reproduces" → "fix confirmed" (cases 1+2 green; case 3 E2E `--subnet` bringup homed+bound on-node). The home-assignment POLICY (`api bind` w/o home still HOME_REFUSEs) is unchanged + correct — it's WHY endpoint run needed `--subnet`. No claude-spt change: the adapter manifest/hooks were correct as-is throughout (no SPT_DEV workaround existed to revert — grep of adapter + plugin + my own bringup all clean). Originally reported QUEUED (ADRs 0026/0027, v0.13.3+). NOT a version regression — established home-assignment policy that only BITES once a node holds 2+ subnets (real trigger: this node gaining BIGNET as a 2nd subnet). On a multi-subnet node a NEW-endpoint bind must be told its home: `spt api bind <id> --set-session-id <sid>` → **`HOME_REFUSED: this node holds 2 subnets … pass --subnet`**; the same bind WITH `--subnet <name>` → BOUND. The spt-HOSTED bringup cannot supply it: `spt endpoint run` has **no `--subnet` flag** and the broker injects `$SPT_ENDPOINT_ID` but **no home-subnet**, so the plugin SessionStart `bind)` branch fires `api bind … --set-session-id …` (no `--subnet`) → HOME_REFUSED → the hook's `\|\| true` swallows it → zero perch → server `ENDPOINT_RUN_ONLINE_TIMEOUT` (~25s). Pinned HOME_REFUSED on 0.11.0/0.12.0/0.12.1/0.13.1/**0.13.2** (policy, not a code bug). **doyle's fix (ADRs 0026/0027): broker injects `$SPT_ENDPOINT_SUBNET` + `api bind` env-fallback → the SHIPPED hooks stay UNCHANGED.** Adapter manifest/hooks are CORRECT as-is; fix is spt-core-side. **Regression seed COMMITTED: `ci/subnet/multi-subnet-bringup-int.sh`** — 3 cases (Case 2 no-subnet→HOME_REFUSED, Case 3 --subnet→BOUND, Case 1 E2E endpoint-run→no-perch/timeout, gated SPTC_ACCEPTANCE=1); multi-subnet-gated (single-subnet auto-homes + hides it). Operator earlier DECLINED a temp `--subnet` hook band-aid (wait for the real fix). | On a node holding 2+ subnets, every NEW-endpoint bind needs `--subnet <home>` (else HOME_REFUSED), but the spt-hosted `endpoint run` path provides no way to pass it — the broker injects the id but not the home subnet, so the SessionStart self-bind HOME_REFUSEs and the spt-hosted bringup silently yields zero perch (ONLINE_TIMEOUT). Single-subnet nodes auto-home and never see it |
| F-018 | 2026-06-22 | **REPORTED to doyle (perri) — destructive footgun, os-2 family (F-011 sibling)**. Surfaced while constructing the F-015 brick repro on v0.13.2. `spt adapter add --github <user/repo>` on an **already-registered, already-extracted gh_release Pointer adapter** is destructive-then-cryptic: it git-clones the SOURCE repo over the extracted install dir (wiping the root `manifest.toml` + the 3 runtime `.exe` binaries the Pointer resolves), then the post-add first-`[update]` conduct fails bare **`ADAPTER_ADD_FAIL: io: ... (os error 2)`** — leaving the adapter `manifest-not-present` (same broken state as F-011, but operator-induced). No confirm prompt, no "already registered — did you mean `adapter update`?" guard, no rollback. Recovered by extracting `dist/adapter-windows-x86_64.spt` over the install dir (manifest+binaries restored, version 0.6.0, translate-proof OK). **Needs (doyle):** for an already-registered gh_release adapter, `add --github` should refuse/route to `adapter update` (or at least not wipe the working install before the avenue succeeds), and the `os error 2` should carry path+cause (the F-011 diagnostic ask, same resolver). | Re-running `spt adapter add --github user/repo` to "reinstall" a healthy gh_release Pointer adapter silently destroys the working install (clones raw source over the extracted runtime, drops manifest+binaries) and fails `os error 2`, requiring a manual `.spt` re-extract to recover |

> **F-012 (NOT logged as spt-core)** — legacy-owl 1.11.25 poll-loop exits 1 / orphans the Psyche across daemon churn (`/spt:revive` started gen-7 wrapper+psyche fine but the foreground poll died with a non-fatal `sessions log seal failed: git failed (continuing)` line). doyle ruled this is the **legacy owl listener** (a separate daemon from spt-core), NOT an spt-core public-surface finding; the seal line is non-fatal/continues so isn't the exit cause; it dies with legacy owl's retirement. Re-open as spt-core ONLY if repro'd clean-room (sptc listener, zero legacy owl). No spt-core action.

---

## F-001 — Harness hook-wiring contract incomplete for a Claude Code adapter

**Reported:** 2026-06-14 to doyle (owl). **Status:** awaiting ruling / docs fix.

**What IS published (sufficient):**
- `harness-contract/api.md` — the full `spt api` primitive surface: `seed`, `listen`, `bind`,
  `boundary`, `session-end`, `shutdown`, `state`, `echo-gate`, `presence`, `driven-by`, `poll`,
  `history-log`, `worker-start/poll/stop`, `bind-shell`, `emit`, `owner-shutdown`, `capability`.
- `harness-contract/install-on-demand.md` — install-on-demand bootstrap, exact `sh` + `ps1`
  snippets, canonical installer URLs, env-var customization. **Fully buildable.**
- `harness-contract/integration-checklist.md` + `manifest.md` map: SessionStart →
  `api seed --pid {parent_pid} --session-id {session_id}` then `api listen <id>`; Idle →
  `api state idle|busy`; PreCompact/clear → `api boundary clear|compact <id> --to-session-id <sid>`;
  teardown → `api session-end <id>` / `api shutdown <id>`.

**The gaps:**

1. **Hook-event → `spt api` mapping is incomplete.** No published mapping for **UserPromptSubmit**,
   **PreToolUse**, **SubagentStart**, **SubagentStop**. (`worker-start/stop` exist but are not tied
   to the Subagent hook events.)
2. **Manifest `[hooks.*]` vs harness-native hook config is unspecified.** `manifest.md` declares
   hooks as `[hooks.<event>] fires="api ..." reads=[...] can_inject=bool`, with spt-core performing
   `{key}` substitution from `reads`. It is **silent** on whether spt-core *materializes* the
   harness-native config (Claude Code `hooks.json`) from the manifest, or the adapter author
   hand-writes `hooks.json` that shells out to `spt api`. These imply different substitution models:
   Claude Code delivers hook data as JSON on **stdin**, but the manifest model is spt-core-side
   `{placeholder}` fill — so if `hooks.json` is hand-written, it is unclear who fills
   `--pid {parent_pid}`. (Also reframes the `SCOPE.md` assumption "the plugin ships a `hooks.json`
   calling `spt api`" — it may instead be manifest-declared + spt-materialized.)
3. **Injection mechanism is undocumented.** `can_inject` + an `[inject]` section (methods
   `pty`/`hook`/`relay`/`http`) exist, but there is **no technical detail** on how an adapter emits
   `additionalContext` back through the hook channel. Blocks (a) general mid-session message
   delivery on a prompt/tool hook, and (b) this project's **UPS-injection** skill-instruction design
   (`docs/adr/0001-*`) specifically — it cannot be validated against the public surface until this
   is documented.

**Impact (as first reported):** SessionStart / Stop(idle) / SessionEnd / boundary are buildable now.
UserPromptSubmit + PreToolUse + Subagent wiring + the entire injection path were *thought* blocked.

### Resolution (2026-06-15 — converged with doyle, grounded in `CONTEXT.md`)

The boundary canon (`CONTEXT.md` L52/L181/L112/L149/L137) re-frames F-001: **spt-core is
harness-independent and supplies the agnostic `spt api` primitives + their I/O format; the adapter
authors the harness-specific wiring + output-formatting.** So most of F-001 is **adapter-authoring
work (ours), not an spt-core gap**:

- **Gap 1 (CC-event → api mapping) — OURS, closed.** Which CC hook drives which `api` primitive is
  adapter glue (L181). Owned mappings: SessionStart → `api seed` (+ env aliases); `/sptc:ready|live`
  → `api listen <id>` (the blocking poll loop — *not* SessionStart, which must not block); Stop/Idle
  → `api state idle|busy`; PreCompact/clear → `api boundary`; SessionEnd → `api session-end` /
  signoff → `api shutdown`; SubagentStart/Stop → `api worker-start`/`worker-stop`; UserPromptSubmit
  → `api poll`; **PreToolUse out-of-scope v1** (UPS covers delivery). See `docs/adr/0002-*`.
- **Gap 2 (medium) — OURS, closed.** The `sptc` plugin **hand-writes** its CC `hooks.json` shelling
  `spt api`. spt-core materializing a CC `hooks.json` would violate L52/L181 — it correctly doesn't.
- **Gap 3 (injection HOW) — OURS, closed.** `api poll` emits message frames to **stdout** by design
  (L149) — that IS the hook-injection delivery path; routing/formatting that stdout into CC's
  `additionalContext` channel is adapter glue (L112). The earlier "`can_inject`/`[inject]`
  method-discard is dead code" alarm is **retracted** — it is M2a roadmap staging (stdout/hook only
  now; PTY at M3), and `can_inject` drives the *built* echo-gate/relay fallback (L137) for hooks that
  cannot inject (e.g. CC Stop).
- **CC param-sourcing** ({parent_pid}/{session_id}) — OURS: read off the CC hook-input schema
  (`session_id` is a common stdin field; pid via the hook process). Not an spt-core concern.

**Residual spt-core item (doyle owns; non-blocking):** publish the **agnostic primitives** to the
adapter-facing docs-site — specifically `api poll`'s **emit frame format** (the frame we parse +
format for CC) and the **substitution-key catalog** (currently code-only). doyle verifies against
`CONTEXT.md`/ADRs then propagates (no new design). We will report the **observed** `api poll` frame
format so the publish can confirm-match. Until published we may rely on observed behavior of the
public binary (observable behavior = public surface).

### Validation note (2026-06-15, against live v0.7.0 `spt adapter add` + the shipped mock-adapter)

Authored + registered `adapter/claude-spt.toml` against the real v0.7.0 binary
(`REQ-DIST-MANIFEST-SCHEMA` int — `ci/manifest/registration-int.sh`, 6/6 green). Confirms the
residual: the **published docs still omit** two things a manifest author needs, both learnable only
from the **shipped mock-adapter source** (which IS public surface) + live `adapter add` errors:

1. **Substitution-key catalog.** `{parent_pid}` and `{adapter_name}` are spt-filled SessionStart
   keys (mock `api seed --pid {parent_pid} … --adapter {adapter_name}`); the docs-site lists only a
   partial set. The full catalog is still code-only.
2. **`[digest]` cross-field rule.** The JSON schema accepts `[digest]` with just `extractor`, but
   `spt adapter add` **rejects** it: `[digest] needs source (own-source) or a [history]
   locate_template`. Not documented prose-side; surfaced only at registration. (Worked around with
   `source = "{home}/.claude/projects"` — CC's cwd-slug subdir is not expressible as a flat
   `locate_template`, so `source` names the per-project root and the extractor finds
   `{session_id}.jsonl` within. A CC-shaped extractor is the right design vs the mock's log-less
   `[history] native`.) **Non-blocking** (resolved by reading the shipped mock + the error text);
   logged so doyle can publish the key catalog + the digest source-requirement to the docs-site.

Also observed (not a gap, a roadmap fact): `spt endpoint run` notes the **interactive picker that
emits the `<basename>-<id>` shortcut "lands in a later wave"** — so the `sptc-<id>` *emission* int
(`REQ-DIST-SHORTCUT-BASENAME`) stays held on that wave (and on authoring `[session.self]`, which
`endpoint run` spawns). `shortcut_basename = "sptc"` is confirmed to round-trip into the stored
resolved manifest, so the declaration side is proven.

---

## F-002 — `api poll` (agent path) has no inter-frame delimiter — multi-message drains unsplittable

**Reported:** 2026-06-15 to doyle. **Status:** open — **spt-core CODE gap** (not docs); doyle has
raised the framing as a contract decision to the operator.

**The gap (confirmed from source by doyle):** the **agent** `api poll` path emits each drained
message with `print!("{msg}")` (`delivery.rs:192`) and `format_row` adds **no trailing newline**
(`spool.rs:91-97`). So a multi-message drain **concatenates frames with nothing between them**.
Combined with the frame format (anonymous senders emit a **bare body**, and bodies may be
multiline), a multi-message `poll` stdout is **genuinely unsplittable** — there is no delimiter to
parse on. Tell that this is a rough edge, not intent: the **shell** drain (`cmd_poll_shell`,
`delivery.rs:169`) uses `println!` (newline-framed); only the agent path omits it. The framing is
unspecified in `CONTEXT.md` / `docs/api.md`.

**Impact / our handling:**
- **Single-message poll = unambiguous, works now** — `__REPLY_TO__:<id>\n<body>` or bare body.
- **Multi-frame splitter is HELD** — we do not assume a delimiter that does not exist. The
  UserPromptSubmit wrapper surfaces whatever `poll` returns: a single frame is cleanly per-sender
  formatted; a (rare) concatenated multi-drain degrades to a surfaced-but-unattributed blob rather
  than a parser guessing boundaries.

**Resolution — RESOLVED-BY-DESIGN (operator-ruled 2026-06-15):** the framing question is
settled, more cleanly than a delimiter patch. The **canonical format at every surface — including
`api poll` — is the `<EVENT type="msg" from="<sender>">body</EVENT>` envelope** (`spt-proto::event`,
the ADR-0001 grammar the live listener already emits). `__REPLY_TO__` was a **mis-elevated relic**
(wrongly frozen as the "stable wire format" during the clean-room port) and is being **deleted from
spt-core**. The `<EVENT>` envelope is **self-delimiting**, so multi-message drains split cleanly on
`</EVENT>` — no delimiter needed, and the F-002 multi-frame hold is **lifted**.

- **Our parser** now targets `<EVENT>` (the `from` attr → `<sptc_messages from="…">`, `<br>` →
  newline, entity unescape with `&amp;` last) — exactly the live-agent body-parsing rule. See
  `render_frames` in `plugin/sptc/hooks/_common.sh` + `tests/hooks-parse.sh` (multi-message covered).
- **VERIFIED ON THE PUBLISHED SURFACE (v0.7.1, 2026-06-15).** The canonical poll envelope shipped in **v0.7.1**
  (counter 13); `__REPLY_TO__` relic gone. A throwaway byte-capture against the live 0.7.1 `spt api
  poll` drain (`od`-verified) confirms the canonical envelope end-to-end:
  - single msg: `<EVENT type="msg" from="probe-sender">hello from probe<br>second &lt;line&gt;
    &amp; &quot;stuff&quot;</EVENT>\n` — body escaping (`<br>` + `&lt;/&gt;/&quot;` + `&amp;` last)
    is the **exact** `render_frames` decode rule.
  - whole envelopes, self-delimiting **and** `\n`-framed; **no `<EVENT-PART>`** on a normal hook
    drain; **no `__REPLY_TO__`**. Multi-drain splits cleanly on `</EVENT>` → **F-002 dissolved on the
    published binary**.
  - raw drain piped through our `render_frames` → correct `<sptc_messages from=…>` (parser
    confirm-match PASS). `notify` events ride the same envelope.
  Locked in by `ci/hooks/poll-int.sh` (SPTC_ACCEPTANCE-gated, ≥0.7.1, 5/5): bind→send→`api
  poll`→`render_frames` assert. **`REQ-DIST-HOOKS-API` + `REQ-UPS-INJECTION` `int` flipped GREEN.**
  Canonical poll envelope loop closed: design→impl→gate→ship→real-surface-verify.

---

## F-003 — No file-backed `[strings]` mechanism on the M12/v0.7.0 public surface (ADR-0001 dependency unmet)

**Reported:** 2026-06-15 to doyle + todlando. **Status:** **RESOLVED 2026-06-15** — the capability
is **shipped** in v0.7.0; the residual is a **docs-visibility** gap (doyle is publishing the syntax).
The text below records the original (wrong) "absent" framing for provenance; see **Resolution**.

**The dependency (ours, ADR-0001):** UPS-injection delivers `/sptc:X` skill bodies from the adapter
`[strings]` tree, explicitly **"file-backed, so the manifest doesn't bloat"** (`REQ-UPS-INJECTION`).
ADR-0001's own Open/to-confirm names it: *"File-backed `[strings]` is an M12 spt-core dependency —
until M12 publishes, instruction bodies cannot be externalized."* M12 is now public (`spt 0.7.0`).

**The gap (confirmed against the live binary AND the published docs):** v0.7.0 exposes **no** way to
externalize a `[strings]` value to a file. Every avenue is inline-only:

- **Schema** (`adapter/manifest.schema.json`, vendored from the docs-site): `[strings]` is a plain
  `object`, `additionalProperties: true` — no `$file`/`include`/`@file` value convention.
- **`spt adapter get-string <opt> <key>`**: "prints the value (strings raw, else JSON)" — reads the
  merged inline view; no file-reference resolution.
- **`spt adapter set-string <opt> <key> <VALUE>`**: takes a **literal** `<VALUE>` positional — no
  `--from-file`/stdin path for an individual value.
- **`spt adapter create-profile --from <file>`**: ingests a *whole overlay TOML* whose values are
  still inline — not a per-value file backing.
- **Published docs** (`llms-full.txt`, manifest + CLI reference): no `@file`/include/external-ref
  syntax documented anywhere; strings are described purely as inline manifest-resident data.

(`[update] file_pull` ships adapter *files*, but it needs an Ed25519 signing key + a registry repo
target we do not hold — already a finding-class gap, see manifest header — and it does not make a
`[strings]` *value* resolve from a shipped file. Not a substitute.)

**Impact / our handling:** non-blocking, by ADR-0001's own fallback — *"skeleton SKILL.md files may
carry interim inline instructions."* So:
- The `/sptc:whoami` + `/sptc:setup` skeletons keep **interim inline bodies** in the cplugs skeleton;
  the manifest does **not** carry (and does not externalize) skill bodies in v0.7.0.
- `REQ-UPS-INJECTION` stays at `[doc, impl, unit]` (activate-don't-pre-fail) — the externalization
  half is held on this capability, not failed.
- The manifest-bloat avoidance ADR-0001 promised is **unachievable on the published surface** until
  spt-core adds a file-backed string mechanism (or rules that large bodies belong in another layer).

**Ask for doyle/todlando:** does M12 intend file-backed `[strings]` and it is unpublished/unshipped,
or has the design moved (e.g. bodies belong in a file-pull-shipped layer, not `[strings]`)? Either a
docs+binary capability or an ADR-0001 amendment closes this.

### Resolution (2026-06-15 — capability-confirmed-shipped; residual is docs-only)

The "absent" framing was **wrong**: the avenue search probed CLI verbs (`set-string --from-file`,
`create-profile --from`) and value-prefix syntax (`@file`/include), but the shipped mechanism is a
**value-position inline-table FILE POINTER** authored directly in `[strings]` — a shape an open
`additionalProperties` schema accepts and a verb-search cannot surface. doyle + todlando both ruled it
shipped (spt-core `REQ-MANIFEST-5`, M12-W3 @ `e08cea0`: `profile.rs::as_file_pointer` +
`registry.rs` lazy `get_string`). Confirmed by **live byte-test** against `spt 0.7.0`:

```toml
[strings]
inline_key  = "INLINE-VALUE"            # inline string — get-string prints as-is
filebacked  = { file = "probe.txt" }     # pointer — get-string RESOLVES to file contents (lazy)
```
```text
$ spt adapter add <dir>                            # ADAPTER_ADD:<name>:Harness:Copy (registered)
$ spt adapter get-string <name> inline_key         # INLINE-VALUE
$ spt adapter get-string <name> filebacked         # RESOLVED-FROM-FILE-OK   (file body, not the table)
# containment (negative): escape = { file = "../outside.txt" }
$ spt adapter add <dir>
#   ADAPTER_ADD_FAIL: invalid [strings] file pointer: pointer ../outside.txt must be a relative
#   path inside the strings/ dir (no absolute paths, no `..` traversal)   ← manifest-first: nothing registered
```

**Confirmed behavior (now the basis of our authoring + doyle's doc):**
- Pointer files live in the per-adapter aux dir `adapters/<adapter>/strings/`; `file = "x"` is a bare
  relative path **inside** that dir. On `adapter add` the whole adapter dir (incl. `strings/`) is
  **copied** into the registry.
- `get-string` **resolves the pointer lazily at read time** (live edits to the shipped file reflect
  without re-register) and prints the **file contents**; inline string values print as-is.
- **Containment** is enforced at register: `..`/absolute escaping `strings/` → `ADAPTER_ADD_FAIL`,
  manifest-first (nothing registers). Missing-at-read is skip-diagnostic (mirrors `[digest]`), not a crash.
- **Update-safe (todlando):** a **local profile's** pointers resolve to the *user-owned local-profile
  dir*, not adapter-shipped `strings/` (adapter updates won't stomp user overrides). A value-table
  carrying a `file` key is **reserved** as the pointer form — it cannot double as inline data.

**Disposition:** ADR-0001's "file-backed `[strings]`" dependency is **SATISFIED** — no ADR amendment,
no spt-core build change. We author UPS-injection skill bodies as `[strings.skills].<x> = { file =
"skills/<x>.md" }` over `adapter/strings/skills/<x>.md`. **Residual = published-docs visibility only:**
the pointer syntax was undocumented on the GH-Pages surface (it lived in spt-core-internal
`CONTEXT.md §adapter strings`) — same class as the `{key}` catalog + `[digest]` cross-field rule.
**CLOSED in v0.7.1 (2026-06-15):** doyle published the `[strings]` file-pointer syntax (plus the
`{key}` substitution catalog and the `[digest]` register rule) to the docs-site manifest reference +
`MANIFEST.md`. The next adapter author discovers the pointer form from the published surface alone —
F-003 fully resolved.

---

## F-004 — `spt adapter digest-proof --sample` does not fill `{session_id}` (false-fails the published extractor shape)

**Surfaced:** 2026-06-15, authoring the claude-spt `[digest]` extractor.

**Symptom.** `spt adapter digest-proof --sample <log>` substitutes only `{source}` (= the sample
path) into the extractor command and hard-fails on any other key. The claude-spt extractor command
is the production-correct, published-example shape:

```
extractor = "claude-spt-digest --session {session_id} --in {source}"
```

→ `DIGEST_PROOF_EXTRACT_FAIL:claude-spt: digest extractor failed: no value for substitution key {session_id}`.

**Isolation (same adapter, only the command line differs):**
- **Variant A** — `<exe> --in {source}` (source-only) → `DIGEST_PROOF_OK`, **parsed 5 / dropped 0**,
  rendered digest correct (incl. sprint-collapse `used: Write(src/a.rs), Bash(cargo build)`). Proves
  the extractor + the digest-proof render pipeline are correct.
- **Variant B** — `<exe> --session {session_id} --in {source}` → fails on the unfilled `{session_id}`.

**Why claude-spt needs `{session_id}` on the command (not a workaround — the only correct shape).**
CC's transcript path is `~/.claude/projects/<cwd-slug>/<session_id>.jsonl`. The `<cwd-slug>` subdir
is CC-internal and has **no published key** — and per doyle, *should* not (spt-core stays
harness-agnostic; it must not bake a harness's directory scheme into the key catalog). So `source`
must be the projects **root** and the extractor receives `{session_id}` on the command, resolving
`<slug>/<session_id>.jsonl` itself (the slug is the harness's business). This matches the published
example and what `spt endpoint digest` fills at runtime.

**Root cause (doyle, spt-core).** `digest-proof --sample` builds an **empty** substitution-key map
(`cli.rs:5135`, `let keys = BTreeMap::new()` — comment admits "placeholders like `{session_id}`
will fail"), whereas the runtime daemon path fills `{id}`+`{session_id}` before running the same
extractor (`digest.rs:208-210`). digest-proof is meant to be the author-time half of the *same*
spt-core digest engine (§diagnostics), so it must supply the same keys. It doesn't → it is infidelitous to
runtime and false-fails any `{session_id}`-templated extractor, including the published example.

Aside: `{home}` is **not** a catalog key — hard-failing on it is correct. Use `~` for home
expansion in `source` (we switched `source` to `~/.claude/projects`; the extractor also expands a
leading `~/` defensively).

**Status — CONFIRMED-IMPL-BUG; fix in progress (doyle's worktree).** digest-proof will fill
`{id}`+`{session_id}` matching runtime exactly (fidelity: *"passes proof" ⟺ "works at runtime"*),
plus an optional `--session <id>` override (default placeholder). The published contract is right;
the tool is catching up. **Our posture:** the extractor is built to the published contract and
proven (cargo unit tests + Variant A `DIGEST_PROOF_OK`); the digest-proof `int`
(`ci/digest/digest-proof-int.sh`, `REQ-DIST-DIGEST-EXTRACTOR`) **skips on the exact substitution
error** until doyle's fix ships, then flips green on the carrying release.

---

## Finding: no `spt how-to subnet` topic (published-guidance gap, minor)

**Surface:** `spt how-to <topic>` ships canonical, always-current guidance for `ready` and `send`
(the messaging hot path) — the claude-spt `ready`/`send` skills lean on it (`spt how-to ready`).
But there is **no `subnet` topic** (`spt how-to subnet` → `NO_SUCH_TOPIC`), despite `spt subnet`
being a multi-verb, pairing-flow-heavy command (create/show-code/join, 6-digit codes, QR) — exactly
the kind of thing a how-to topic serves well.

**Impact (low):** the `/sptc:subnet` skill wraps `spt subnet --help` as its canonical reference
instead. Works, but inconsistent with ready/send (which get richer how-to prose), and a casual user
running `spt how-to subnet` hits a dead end. **Disposition:** mint a `how-to subnet` topic in
spt-core (cross-machine pairing is the highest-value first-run flow; it deserves the same guided
prose as messaging). Carried as a parity finding — NOT a blocker for `/sptc:subnet`.

**Reported:** 2026-06-15 to doyle (explicit `$OWL send`). **Status:** **ACCEPTED 2026-06-15
(doyle).** Confirmed against spt-core source: `HOW_TO_TOPICS` (cli.rs:4692) ships exactly
`["ready","send"]` (v1 topics, M7 plan decision 12, test-locked) → `spt how-to subnet` →
`NO_SUCH_TOPIC` (exit 2). Classified as a genuine spt-core **content gap under existing REQ-DOCS-6**
(in-binary agent guidance, single-source) — NOT a published-docs gap, NOT a docs-read miss.
**Disposition (doyle):** mint a `how-to subnet` topic (HOW_TO_SUBNET text + registry entry + bump
the v1-lock test); **scheduled into M11-W5** (the rig + docs wave). No new REQ (REQ-DOCS-6 owns it).
Tracked, not a mid-flight interrupt. NOT a blocker for `/sptc:subnet` (wraps `spt subnet --help`).

---

## F-005 — End-user adapter distribution/activation is undocumented on the public surface

**Surfaced:** 2026-06-15, dogfooding the first cplugs publish (an agent ran `/sptc:setup` on a fresh
install). The binary was present (`spt 0.7.2`), setup reported "No install needed" and stopped — but
`spt adapter list` showed **`claude-spt: ... deregistered`**. The harness adapter surface
(profiles / strings / hints / `[digest]`) was inert; `/sptc:*` skill-body UPS-injection had nothing
to source from. Binary present ≠ adapter active.

**The gap (public surface).** The published `harness-contract/integration-checklist` documents only
the **local single-machine** registration verb:
> `spt adapter add <dir>` — "Parses + schema-validates + records the manifest; a bad field is
> rejected here, nothing half-registers."
It documents **no distribution/activation path** for the medium-churn manifest layer the whole
distribution split (ADR-0001) leans on — i.e. how an **end-user machine that installed only the
plugin + binary** ever acquires and registers the `claude-spt` manifest. After the bootstrap installs
the binary, there is no published "… → adapter registered & active" step. Concretely undocumented:

1. **`[update] file_pull`** — the spt-core-conducted "file-pull / adapter registry" channel
   (ADR-0001's medium-churn delivery) has **no published adapter-registry repo-target shape** and
   **no documented path to obtain/provision the Ed25519 content-signing key** an author needs to
   publish a signed adapter. Author-side it is currently un-buildable from the public surface.
2. **`[update] delegated`** — whether the `claude plugin update` fallback requires CC to attest
   signature verification (`self_verifies`) is **unconfirmed** on the public surface.
3. **No end-user activation step is documented at all.** The plugin ships **no manifest** (ADR-0001:
   "no binary, no manifest, no embedded logic"), so the registry/file-pull channel is the *only* way
   the manifest can reach a user — yet that channel is undocumented. Net: the "install the plugin,
   get spt-core **and the adapter** for free" invisible-installer story has an undocumented hole at
   the adapter-activation step.

**Note — this is the finding the manifest header already promised but was never filed.**
`adapter/claude-spt.toml` header (lines 20-24) says `[update] file_pull` needs "(a) a published
adapter-registry repo target and (b) an Ed25519 content-signing key we do not yet hold … Tracked as
a finding (docs/SPT-CORE-FINDINGS.md)" — but no entry existed until now. F-005 makes it real.

**Impact / our handling (non-blocking, dev-side).** For local dev + this session, re-activate with
`spt adapter add ./adapter` (the adapter dir is known to the registry; it reads `deregistered`
because the Phase-D int tests register→clean-up by design). This does **not** solve the *end-user*
flow, which has no published path.

**Ask for doyle.** Is end-user adapter distribution (a) an undocumented-but-shipped capability
(publish the `[update] file_pull` registry-target + signing-key provisioning + the post-install
"adapter add/activate" step to the docs-site), (b) a roadmap item not yet shipped, or (c) a deliberate
design where the adapter is expected to ride a different layer for casual users? Any of the three
closes F-005 — but the public contract currently leaves the casual-end-user activation step blank.

**Reported:** 2026-06-15 to doyle (explicit `$OWL send`).

### Triage (2026-06-15, doyle — against spt-core source). NET: (a)+(b) mix, **nothing unbuildable**; the activation step is just undocumented. Two of my three sub-claims were **docs-read misses** — recorded honestly:

1. **`self_verifies` (my #2) — READ MISS, already public.** `manifest.md [update]` documents
   `self_verifies = true`: "attests the updater verifies its content; an unattested `delegated`
   update is SKIPPED as unverifiable." So `delegated` does **not** require CC to silently attest —
   the *author* sets `self_verifies=true` to assert CC verifies its own content; absent ⇒ the update
   is **skipped (not failed)**. It is in the `[update]` section; I missed it.
2. **`file_pull` shape + signing (my #1) — MOSTLY documented; one real residual.** `manifest.md`
   documents `file_pull = repo + signing_key` (Ed25519, 64 hex) + "you sign your releases with your
   own key; spt-core release keys never extend to adapter content." **GENUINE GAP:** author-side key
   **provisioning** (how you *generate* that Ed25519 key) is undocumented → doyle: doc add.
3. **Zero-touch auto-activation via file_pull network-pull (my #3, the substantive one) — ROADMAP,
   not shipped (b).** `adapter_update.rs` is the DECISION+VERIFICATION layer only — "the actual byte
   transport for `file_pull` (the network pull) is REQ-UPD-1/M4; v1 receives the payload via
   self-fetch / out-of-band … does not itself fetch." Install-conduct emits
   `ADAPTER_INSTALL_DEFERRED "(rides the update engine)"`. The invisible-installer's last leg is
   genuine future work.

**THE PATH THAT WORKS TODAY (the missing post-install step F-005 found).** A fresh machine registers
the manifest via **`spt adapter add --github <author>/<repo>`** (clones under `adapters/_github/`,
manifest-first, then conducts the `[update]` avenue once). Shipped (REQ-INSTALL-4 impl/unit; only the
real-repo E2E is deferred, spt-core DEFERRED.md). So **`/sptc:setup`, after confirming the binary is
present, must run `spt adapter add --github <our-adapter-repo>`** (or a local dir) to ACTIVATE — that
is the bridge. "Binary present ≠ adapter active" confirmed correct.

**doyle's doc actions (docs-site):** publish the post-install ACTIVATION step (`adapter add
[--github]`) in `install-on-demand` + the integration checklist · author Ed25519 signing-key
provisioning · an explicit "zero-touch `file_pull` auto-distribution is roadmap (REQ-UPD-1)" note so
no author builds expecting it.

**Follow-up doc-gap (doyle, 2026-06-15) — `adapter add` is ROOT-ONLY, code-confirmed.**
`source_manifest_file` resolves a dir source to `<dir>/manifest.toml` **exactly** (exact filename,
no scan, no subpath); `--github user/repo` reads `<clone-root>/manifest.toml`. Undocumented (in
source, not published) → doyle adding the distribution-repo topology to the activation docs (root
`manifest.toml` requirement, `--github` root-only, copy-vs-pointer by `[update]` avenue, where the
manifest-referenced **binaries** live — NOT auto-copied, only `strings/` is). **Our consequence:**
the end-user `--github` target must be a **dedicated repo** (root = `manifest.toml` + `strings/` +
binaries), distinct from the monorepo; local dev uses the file-form `adapter add
./adapter/claude-spt.toml`. Drives `SETUP-SLICE-PLAN.md` Wave C.

**Our action items (ours, not doyle's):** (i) wire `spt adapter add --github <repo>` into
`/sptc:setup`'s binary-present branch (the activation bridge — folds into the setup-slice below);
(ii) the manifest needs its own **published github repo target** for the `--github` end-user path
(distinct from the cplugs skeleton repo); local dev uses `spt adapter add ./adapter`.

**Status:** **TRIAGED — accepted as (a)+(b) mix.** doyle patches docs; we wire the activation step.

### Resolution (2026-06-15 — doyle shipped `--release`, distribution leg CLOSED)

doyle shipped + published a new acquisition source that closes F-005's end-user distribution leg
without a dedicated repo: **`spt adapter add --release <user/repo> [--tag <ver>]`** fetches a
published **`adapter.spt`** release asset (a tar whose **root** holds `manifest.toml` + `strings/` +
the binaries) from the repo's GitHub release, extracts to the durable home, and registers the root.
**We ship straight from the monorepo as a release asset — no dedicated root-manifest repo** (the old
`--github` root-only constraint, code-confirmed + since doc-patched, is routed around). First
acquisition trusts HTTPS+GitHub like the install one-liner; signing rides the `file_pull` `[update]`
avenue later (this is **acquisition only** — re-running `--release --tag <newer>` is a manual
re-acquire, it does not change the `[update]` route). Docs (revised):
`harness-contract/install-on-demand.html#activate-the-adapter--register-your-manifest`;
`--release` is now the **recommended** distribution, `--github` + local-dir the alternatives.

**Our wiring:** `/sptc:setup` end-user branch → `spt adapter add --release SaberMage/spt-claude-code`
(local dev stays the file-form). **Version gate:** local spt 0.7.2 has only `--github` + local path;
`--release` lands in a newer spt release — int/dogfood waits on the upgrade. The remaining build is
the `adapter.spt` release-asset packer (`SETUP-SLICE-PLAN.md` Wave C′) + OQ2 (binary resolution: bare
-name templates resolve from PATH, so either ship binaries on PATH via the installer or use
home-relative paths). **The `[update]`/self-update channel itself stays unauthored** (our manifest
declares no `[update]` → COPY-mode registration; the signed file_pull self-update is the later,
separate concern — REQ-UPD-1/M4 roadmap + the Ed25519 provisioning doc).

---

## F-006 — `--release` bundles adapter binaries but bare-name templates don't resolve them (copy-mode)

**Surfaced:** 2026-06-15, the first real end-to-end `--release` dogfood (spt v0.7.3, counter 15).

**Chain proven first (all green on the win node):** `spt update fetch` → `apply` (0.7.2→0.7.3, exe
hash flipped to the signed `d867…0794`, seamless no-bounce) → `spt adapter add --release
SaberMage/spt-claude-code --tag v0.1.0` → fetched `adapter.spt` from the release →
`ADAPTER_ADD:claude-spt:Harness:Copy (registered)` + `ADAPTER_INSTALL_SKIP: no [update] avenue
(manifest-only adapter)` → `claude-spt` **ACTIVE**. The end-user activation path works.

**The gap (doyle predicted it; dogfood confirmed).** `--release` extracts the bundled binaries to the
adapter install dir —
`C:\Users\decid\AppData\Local\spt-core\adapters\_github\SaberMage-spt-claude-code\claude-spt-digest.exe`
+ `…\claude-spt-psyche.exe` (note: the `_github/<safe>` dir even for `--release`). But the registered
manifest's command templates invoke them **by bare name**:

```
extractor = "claude-spt-digest --session {session_id} --in {source}"
command   = "claude-spt-psyche --id {id} --session-id {session_id} --prompt {psyche_prompt}"
```

Bare names resolve from **PATH** only, and the extract dir is **not** on PATH → `command -v
claude-spt-digest` / `-psyche` both **MISS**. Registration/activation succeed, but runtime
session-digest + LiveAgent Psyche can't find the bundled binaries. Copy-mode copies `manifest.toml` +
`strings/` only — the binaries extract but aren't placed on PATH.

**Interim (shipped, adapter-side).** `/sptc:setup` now, after an `--release` activation, copies the
two binaries from the extract dir (the `from …` path in `spt adapter list`) onto a PATH dir (the
`spt` bin dir — already on PATH). Verified: copying them there makes `command -v` resolve both and
`claude-spt-digest --help` run. Unblocks runtime today.

**Proper (doyle, REQ-INSTALL-11).** spt-core resolves `[digest]`/`[session]` program paths against the
adapter's own install dir (the `_github/<safe>` extract home / `adapters/<name>/`) **before** PATH —
so a bundled `.spt` binary resolves with zero PATH placement (truly self-contained `--release`
delivery). Shipped in **v0.8.0 / counter 16** (Feature B).

**Status:** **RESOLVED + interim RETIRED (v0.8.1 dogfood, 2026-06-16).** Install-dir resolution is now
dogfood-proven for BOTH binaries with nothing on PATH:
- **digest** — `spt adapter digest-proof claude-spt --sample …` ran the extractor from the install dir
  (`parsed 5 record(s), dropped 0`) after the interim PATH copies were moved aside and `RELDIR` was
  off PATH.
- **psyche** — the daemon-hosted Psyche resolved + spawned `claude-spt-psyche` from the install dir
  (resident runner, `procs=1`), again with the interim off PATH. (This only became provable once the
  Psyche actually stayed resident — see **F-009**, the prompt-split bug that was masking it.)
The interim PATH-copy step is **dropped** from both `/sptc:setup` bodies and the interim copies under
`…/spt-core/bin/` are deleted. Reported to doyle + deployah 2026-06-15; resolution dogfood-confirmed.

---

## F-007 — no `spt how-to live` topic, though live-agent lifecycle is a first-class advertised concern

**Surfaced:** 2026-06-16, building the REQ-SKILL-LIVE relay int (spt v0.7.3, counter 15).

**The gap.** `spt --help` lists "live-agent lifecycle" among the core concerns, and the task-oriented
`spt how-to <topic>` surface is the contract's canonical, always-current agent guidance. But only two
topics exist:

```
$ spt how-to
Topics (`spt how-to <topic>`):
  ready  receive messages: listener guidance + the --once fallback loop
  send   deliver messages: send vs ring, replies, SENT vs QUEUED

$ spt how-to live
NO_SUCH_TOPIC:live — topics:
  ready  ...
  send   ...
```

`ready` (becoming reachable) has a how-to; `live` (becoming a LiveAgent — a strictly larger, more
hazard-laden lifecycle: `[session.psyche_init]`, daemon-spawned Psyche, the `:live` composite, the
Monitor relay-vs-poll reconcile) does **not**. There is no published, canonical bringup recipe for a
live agent to defer to.

**Why it matters for the adapter.** Our `/sptc:live` body (`adapter/strings/skills/live.md`) was
written to *defer* to `spt how-to live` as "the canonical, always-current guidance" and follow it —
the same pattern `/sptc:ready` uses for `spt how-to ready`. With no such topic, that step dangles on
a dead command, and the adapter must instead **inline** the live-bringup recipe (perch id → seed the
`:live` composite so the daemon resolves `[session.psyche_init]` → run `spt api --adapter
claude-spt:live listen <id>` as the resident relay → poll/relay reconcile). Inlined steps can **drift**
from spt-core's actual live contract with no canonical source to reconcile against — exactly the
divergence the how-to surface exists to prevent.

**Adapter-side hardening (shipped this session).** `live.md` no longer instructs `spt how-to live`
unconditionally; it carries the inline operative recipe as the floor and references `spt how-to live`
only as "if/when the topic lands." So the skill never points at a dead command.

**Empirical addendum (2026-06-16, same session) — no non-interactive live-bringup for acceptance.**
Building the REQ-SKILL-LIVE relay int surfaced a concrete consequence. A live agent was brought up
under a disposable id:

```
$ spt endpoint run --adapter claude-spt:live --id sptc-ci-liveprobe --create --start
ENDPOINT_RUN:sptc-ci-liveprobe adapter=claude-spt:live pid=Some(155916) session=… (harness binds its perch on startup)
ENDPOINT_RUN_STARTED:sptc-ci-liveprobe (attach with `spt rc sptc-ci-liveprobe`)
```

The `claude` SUT spawns and is alive in the broker PTY (`spt rc sptc-ci-liveprobe` attaches), **but it
never binds a live perch** — `spt endpoint list` / `spt daemon status` never show it, and teardown
confirms it never registered (`STOPPED:… no ready marker; address unregistered`). This is **by
design**: `SessionStart` *seeds* but must not *listen* (a listen blocks — F-001 resolution); a live
perch is bound only when the session explicitly runs `/sptc:live`, whose body runs the **blocking**
`spt api --adapter claude-spt:live listen <id>`. So a deterministic live-relay acceptance test cannot
just `endpoint run --start` and assert — it must **drive a persistent session** (submit `/sptc:live`,
keep it alive while a probe is sent + the relay EVENT is asserted, then tear the Psyche+perch down).
That heavier harness has no published non-interactive entrypoint to build against (the missing
`how-to live` would be where such an "acceptance/headless live bringup" path is documented).

**RESOLUTION (2026-06-16, doyle ruling + perri validated).** Both items = docs gap (Bucket 2), NOT a
missing feature.
- **Item 1 (`how-to live`):** accepted = REQ-DOCS-6; doyle adds the topic as a post-M11 fast-follow
  (mechanism exists — the twin `how-to subnet` just landed). live.md hardened meanwhile (inline floor).
- **Item 2 (non-interactive bringup):** the primitive EXISTS and is public — it's NOT `endpoint run`
  and NOT `--once`. CC has the Monitor tool, so the live bringup is a **persistent** `spt api
  --adapter claude-spt:live --manifest <manifest> listen <id>` run as a **child process** (the Monitor
  surrogate; heir to legacy `$LIVE start <id>`). The earlier dead-ends were two omissions, both mine:
  - `endpoint run --start` only brings up the harness PTY; the *session inside* must fire the listen.
  - the Psyche spawns ONLY when the manifest is loaded, and the manifest loads ONLY via **`--manifest`**
    (`--adapter <name>` is just a name string → `LiveHost` None → no spawn). With `--manifest`, spt's
    in-process listen path spawns the Psyche (startup.rs `spawn_psyche`, *before* the once/loop split —
    so `--once` was a red herring). Proven 2026-06-16: `BOUND` / `PSYCHE_SPAWNED:{id}-psyche pid=…` /
    `READY` / the probe relayed as `<EVENT>`. Shipped as `ci/psyche/live-relay-int.sh`
    (REQ-SKILL-LIVE int green).
  - Binary resolution: the psyche_init command's bare `claude-spt-psyche` resolves via the F-006 PATH
    interim on 0.7.3; on **v0.8.0 (Feature B / REQ-INSTALL-11)** spt resolves it against the
    `--manifest` file's dir → still `PSYCHE_SPAWNED` after the interim is dropped. Independent confirm
    Feature B was the right call.
- **Two acceptance gotchas** (doyle folding into the how-to-live docs): anchor on the **Windows** pid,
  not git-bash `$$` (else `STALE_SEED`); `bind <id>` before `send` (else `NO_PERCH`, no queue).

**v0.8.0 marker-model change (doyle heads-up 2026-06-16, M11 restructure).** At v0.8.0 the Psyche is
no longer spawned in-process by `api listen` (which then emits only `BOUND`/`READY` + marks the perch
online); the **daemon livehost** hosts it off that online status (`LIVEHOST_PSYCHE:{id}` on the daemon
+ the `{id}-psyche` perch comes online). `live-relay-int.sh` now version-branches the psyche assertion
(<0.8.0 = `PSYCHE_SPAWNED` off the child; >=0.8.0 = the `{id}-psyche` perch online, **provisional** —
finalized at the v0.8.0 publish ping). Relay leg unchanged. The `how-to live` topic ships in v0.8.0
(todlando @672b928) → re-point `/sptc:live` step 2 at `spt how-to live` then.

**Status:** **RESOLVED to a docs gap (Bucket 2). Live int SHIPPED (0.7.3 green; v0.8.0 psyche-marker
branch pre-staged provisionally). Awaiting the v0.8.0 publish ping to finalize the >=0.8.0 leg +
re-point /sptc:live step 2 at the shipped how-to-live topic.**

---

## F-008 — no published legacy-migration command, though it's a LOCKED v1 setup item

**Surfaced:** 2026-06-16, scoping the LOCKED v1 `/sptc:setup` feature paths {1..7} (SCOPE.md §"/spt:setup skill").

**The gap.** SCOPE item **#5** (LOCKED v1) is: *"Legacy migration — detect claude_skill_owl/owl →
migrate identity+agents+psyche (spt-core CONTEXT.md first-class commitment)."* But there is **no
published command** to drive it. None of `spt --help` (top-level) nor any subcommand
(`adapter`/`daemon`/`grant`/`subnet`/`update`/`endpoint`/`api`/`notif`) exposes a
migrate/import/adopt/legacy/owl verb, and there is no `spt how-to` topic for it:

```
$ spt --help | grep -iE 'migrat|legacy|owl|import|adopt'   # (and every subcommand) → nothing
```

**Why it matters for the adapter.** `/sptc:setup` #5 is supposed to *detect a legacy
claude_skill_owl/owl install and migrate identity + agents + psyche into spt-core*. With no published
command, the adapter cannot author that step against the public surface (and per the
public-surface-only constraint we will not reverse-engineer the legacy on-disk layout or reach into
spt-core source to hand-roll a migration). So setup #5 is **blocked**, distinct from the buildable
items (#7 ccs — shipped; #3/#4 subnet — delegate to `spt subnet`; #6 OS-service — installer-registers
the at-logon daemon task; #1 cc-launcher — gated on full-fat M12).

**Ask (doyle).** Is legacy migration (a) a planned `spt migrate`/identity-import command (then setup
#5 wraps it when it lands), (b) installer-handled (the install bootstrap detects + migrates, so setup
just verifies), or (c) out of v1 scope (then SCOPE #5 should be re-marked defer)? Until a published
surface exists, setup #5 stays unbuilt and SCOPE #5 should note the dependency.

**Status:** **OPEN — reported to doyle 2026-06-16. Setup #5 unbuilt pending a published migration
surface (or a scope re-mark).**

---

## v0.8.0 dogfood results (2026-06-16) — relay/API green; daemon-hosted psyche-spawn open

Upgraded spt 0.7.3 → **0.8.0** (hash `10ff8166…`, daemon restarted). Results against the published build:

- **REQ-API-4 ✓** — `spt api --adapter claude-spt:live <verb>` (capability, listen) resolves the
  registered manifest + install-dir WITHOUT `--manifest`. The require-both-flags wart is gone.
- **F-007 ✓ (shipped)** — `spt how-to live` is a full topic; `/sptc:live` step 2 re-pointed at it.
- **`[update]` gh_release ✓ (declared)** — `adapter/claude-spt.toml` now declares `[update] avenue =
  "gh_release", repo = "SaberMage/spt-claude-code"`; validates against the re-vendored v0.8.0
  `manifest.schema.json`. Live `spt adapter update` test rides the per-OS re-release (the registered
  adapter is still the published v0.1.0 sans `[update]`).
  - **LIVE-TESTED 2026-06-20 (v0.5.0 release) — surfaced TWO gh_release-update gaps (F-014, F-015).**
    First real exercise of the avenue (`0.4.0 -> 0.5.0`). Both flagged to doyle; v0.5.0 unblocked
    via stopgaps, adapter is functionally on 0.5.0 (briefs resolve; up-to-date, no retry-loop).

## F-014 — gh_release update fetches a single fixed `asset` (default `adapter.spt`); no per-OS resolution

**Surfaced:** 2026-06-20 — `spt adapter update claude-spt` →
`ADAPTER_UPDATE_FAIL: fetch: HTTP 404 Not Found` fetching `adapter.spt`. The release ships **per-OS**
assets (`adapter-<os>-<arch>.spt`, REQ-DIST-ADAPTER-PEROS) but the update avenue fetches one fixed
name — `asset` omitted ⇒ default `adapter.spt`, which we deliberately do NOT publish (the manifest
comment pre-flagged exactly this). `spt adapter update --help` exposes no `--asset` override and the
manifest `[update]` has no `{os}`/`{arch}` placeholder. So the avenue cannot target a per-OS asset.
**Stopgap (applied):** published `adapter.spt` = the windows build to the v0.5.0 release (this node's
OS; the active fleet is windows). **Needs (doyle):** per-OS resolution in the gh_release update avenue
— an `asset = "adapter-{os}-{arch}.spt"` placeholder, or host-derive like `--release` acquisition.

- **RESOLVED-SHIPPED (spt-core v0.13.2, ADR-0024 W1) — applied to claude-spt 2026-06-22 (perri, C).**
  doyle's fix took the third path: NOT a per-OS asset placeholder, but **one host-agnostic
  multi-platform fat `.spt`** — a single archive bundles each recognized target-triple's binaries
  under a `<triple>/` dir beside the SHARED `manifest.toml` + `strings/` at root; install classifies
  the triple dirs and flattens this node's triple into the install dir (bare-name resolution
  preserved). So the `[update]` avenue's single fixed `asset = adapter.spt` is now correct on every
  host — no `{os}/{arch}` placeholder needed. **Adapter change (C):** `ci/publish/package-adapter.sh`
  now emits the single fat `dist/adapter.spt` (win `x86_64-pc-windows-msvc/` + linux
  `x86_64-unknown-linux-gnu/`), `min_spt_core_version` → 0.13.2 (mandatory for a fat archive), the
  F-014 windows-copy `adapter.spt` stopgap DROPPED. Win-triple flatten LOCAL-dogfooded (extract →
  flatten → translate-proof + digest-proof OK). **Layout was a published-docs GAP** (only in spt-core
  internal CONTEXT.md; not on docs-site/llms — confirmed with doyle, who is adding it to
  harness-contract + llms; not separately logged per his call). Constraint: only the two x86_64 triples
  are recognized in a fat archive today (an unrecognized dir silently flattens as a shared-root entry —
  the packer guards it); platforms beyond those ship a separate single-triple asset via `--asset`.

## F-015 — Windows update-extract fails (`tar exit 1`) when a live agent locks a bundled binary; whole update reported failed despite manifest+strings applying

**Surfaced:** 2026-06-20 — after the F-014 stopgap, update got past fetch but →
`ADAPTER_UPDATE_FAIL: extract: tar exit Some(1)`. The `.spt` archive is valid (local `tar xvzf` exits
0). Root cause: `claude-spt-psyche.exe` was **running** (pid for the live `wall-a` agent's Psyche), so
Windows locked it and tar could not overwrite the binary → exit 1. The non-binary entries DID extract
(install-dir `manifest.toml` = 0.5.0, `strings/briefs/` present + resolving, `claude-spt-digest.exe`
swapped); only the locked `claude-spt-psyche.exe` stayed the old build. spt-core reports the whole
update FAILED yet still records 0.5.0 (re-run → `UPTODATE installed 0.5.0`), leaving a **partial,
silently-inconsistent** state: a future release that DID change the psyche binary would believe it's
up-to-date with a stale binary. (v0.5.0 is unaffected — it changed no binaries, so the old psyche is
identical.) **Needs (doyle):** graceful locked-binary handling on Windows update — extract-to-temp +
atomic swap when free, or skip-locked + "restart the live agent to finish" semantics, and do NOT
record the new version until the binary swap actually succeeds.

- **W3 FIX VALIDATED on spt-core v0.13.2 (perri, 2026-06-22).** doyle's ADR-0025 W3 fix
  (psyche runs from a `<perch>/.live-bin` own-copy so the shared install binary stays lock-free
  + orphan-reap guard + CRC-swap live-update) is LIVE and correct. Acceptance run on real
  claude-spt 0.6.0 (my F-010×F-015 repro = the W3 acceptance test):
  - **(1a) ✓ psyche runs from `.live-bin`.** Brought up a live endpoint (`api seed` + persistent
    `api listen w3accept --subnet SPT_DEV`; the hook-path `listen` takes `--subnet` where the
    spt-hosted `endpoint run` does not — the F-017 asymmetry, exercised here on a multi-subnet
    node SPT_DEV+BIGNET). Daemon hosted the Psyche; running `claude-spt-psyche.exe`
    ExecutablePath = `…\spt-core\owlery\w3accept\.live-bin\claude-spt-psyche.exe` — the perch
    own-copy, NOT the install dir.
  - **(1b) ✓ install-dir binary stays lock-free.** With the psyche live, an exclusive ReadWrite
    open of `…\adapters\_github\…\claude-spt-psyche.exe` SUCCEEDED — the install copy is unlocked,
    so the `tar exit Some(1)` precondition no longer exists. The lock-brick is eliminated by the
    `.live-bin` design.
  - **(2) ✓ orphan psyche reaps on `spt endpoint stop`.** `spt endpoint stop w3accept` →
    `claude-spt-psyche.exe` process count went 1 → 0. No brain-less orphan left behind.
  - Test scaffold (`w3accept`) purged afterward; node clean, adapter healthy (0.6.0,
    translate-proof OK). **F-010×F-015 psyche-lock: validated CLOSED on v0.13.2.** (A destructive
    `adapter add --github` footgun surfaced while constructing the brick repro — logged as F-018;
    the lock-brick itself did NOT recur.)
- **Relay leg ✓** — `ci/psyche/live-relay-int.sh` green on 0.8.0: BOUND/READY + a probe relayed as the
  escaped `<EVENT>` off the listen child + live_agent kind. No `--manifest` needed.

- **RESOLVED (v0.8.1 dogfood, 2026-06-16) — daemon-hosted psyche-spawn.** Two layered bugs, not the
  net-race we first suspected. (1) spt-core v0.8.0 livehost did not reconcile/host at all (doyle's
  v0.8.1 fix addressed this — the daemon now reaches the spawn). (2) The spawn then SILENTLY failed:
  the daemon spawned `claude-spt-psyche` but it exited instantly (phantom pid, `status=online`, no
  `psyche_host_error`). Root cause = **F-009** (spt-core whitespace-splits the substituted
  `{psyche_prompt}`, so the runner's non-greedy `--prompt` rejected the 2nd word and exited 2).
  **Confirmed via argv-capture instrumentation:** the daemon passed `--prompt PSYCHE REVIVAL time:
  epoch-ms:… incoming event: (none)` as 7 separate argv tokens. Fixed adapter-side (greedy `--prompt`,
  commit ddf1965); the Psyche now stays resident, `ci/psyche/live-relay-int.sh` psyche leg flips
  skip→ASSERT green, and **REQ-INSTALL-11 / F-006** is proven in the same run. The "peer pump STALLED"
  correlate recurs ~7-8 min after every daemon start but did NOT block hosting (a Psyche hosted fine
  with the pump stalled) — flagged to doyle as **F-010**-adjacent, separate from the host path.

---

## F-013 — `spt endpoint run` does not substitute `[env.<VAR>].value = "{id}"` (the spt-hosted bind-path never gets its endpoint id)

**Surfaced:** 2026-06-17, root-causing the operator's wall-b zero-perch (`spt endpoint run claude-spt
wall-b` → CC PTY came up but `spt send wall-b` → `NO_PERCH` and **zero perch on disk**). This is the
M12 cc-launcher path — impl+UNIT only, **never int-proven E2E** — and wall-b was its first real
exercise. (Build orientation: `CC-LAUNCHER-BIND-PLAN.md`.)

**How the adapter intends the spt-hosted bind path to work.** `endpoint run` spawns
`[session.self].command = "claude"` (bare — CC has no CLI flag for an externally-chosen id; it mints
its own session id post-spawn). To tell the spawned CC *which* endpoint it is, the manifest declares:

```toml
[session.self]
command = "claude"
keys = ["id"]

[env.SPT_ENDPOINT_ID]
direction = "inject"
value = "{id}"
```

The `plugin/sptc/hooks/session-start.sh` `bind)` branch then reads `$SPT_ENDPOINT_ID` and self-binds
(`api bind "$SPT_ENDPOINT_ID" --set-session-id "$sid"`). `sptc_register_verb` selects `bind` **iff
`$SPT_ENDPOINT_ID` is set**, else `seed`.

**Root cause (hard repro, probe-adapter — public-surface only, no spt-core source).** Registered a
throwaway clone adapter whose `[session.self].command` was a no-op env/argv-dumping `cmd` probe, then
ran `spt endpoint run --adapter probe-spt --id <ID> --start` and captured exactly what spt-core spawns:

- With `command = "cmd /c probe.cmd"` + `[env.SPT_ENDPOINT_ID] value = "{id}"`:
  `ARGV: ` *(empty)* and **`SPT_ENDPOINT_ID=[]`** — the env inject is **not substituted** (empty, not
  the id). The id appears in **no** env var (grepped full `set` for the literal id → zero hits). spt
  injected only **inherited** daemon env (`OWL_SESSION_ID` = a static inherited UUID, `SPT_RELEASE_SEED`,
  legacy `OWL`) — nothing endpoint-specific.
- With `command = "cmd /c probe.cmd {id}"` (placeholder **in the command**): `ARGV-WITH-ID:[<ID>]` —
  the `{id}` fills **on argv**. ✅

So on spt **0.9.1** the endpoint id is threaded to the `[session.self]` spawn **only** via `{id}`
substitution **in the command argv** (matching `endpoint run --help`: *"The endpoint id rides argv so
the harness binds to exactly it"*). The `[env.<VAR>].value = "{id}"` route the adapter relies on is a
**no-op** — even though `manifest.schema.json` `EnvVar.value` is documented as *"Value to inject (with
substitution); required for `inject`."* (the schema does not enumerate which keys are available to the
env-value substitution context; `[session.<role>].keys` only governs the command-string fills).

**Consequence (the wall-b zero-perch, fully explained).** In the real spawn, `$SPT_ENDPOINT_ID` is
empty → `sptc_register_verb` returns **`seed`**, not `bind` → the hook runs the harness-hosted seed
branch (records an ephemeral seed by PPID) instead of binding the endpoint perch → **no perch on disk
for the endpoint id** → `spt send <id>` → `NO_PERCH`. **bind itself is not broken**: a direct
`spt api --adapter claude-spt bind <id> --set-session-id <sid>` from an ordinary (non-broker) shell
returns `BOUND` and builds a complete, reachable perch (owlery dir + `info.json` + `api.token` +
`spool.db`); `spt send <id>` → `QUEUED` and `api poll <id> --token` drains it. So the **only** broken
link is endpoint-run's failure to deliver the id to the flagless harness. (Also note: `bind` does
**not** require broker parentage — the "broker-parentage IS the credential" comment in session-start.sh
is not load-bearing for the success path; bind succeeded with neither `--token` nor a proof
`--session-id`.)

**Fix fork (reported to doyle; his call on the spt-core half):**
- **(a) spt-core honors `[env.<VAR>].value` substitution** for `endpoint run` (fill `{id}` — and
  presumably the same key set as the spawning role's `keys`). Then the **current manifest is already
  correct** and no adapter binary ships. Cleanest if `[env].value`-with-substitution is intended per
  the schema text.
- **(b) adapter ships a wrapper launcher** — `command = "claude-spt-launch {id}"`, a tiny per-OS shim
  (mirrors the existing `claude-spt-psyche` runner) that captures `$1` as the endpoint id, exports
  `SPT_ENDPOINT_ID`, then exec's `claude`. Works **today** on the proven argv-`{id}` mechanism with no
  spt-core change; cost is a new shipped cross-OS binary in the spt-core-conducted layer.

**Then (regardless of fork): add the missing int** — `endpoint run <id> --start` → assert a **bound
perch** exists on disk under `owlery/` **and** is reachable (a queued `spt send <id>` drains via the
next `api poll`). Gated `SPTC_ACCEPTANCE=1`, disposable id (REQ-HAZARD-PERCH-COLLISION), full teardown.
This int would have caught the wall-b zero-perch.

**Secondary observation (cleanup gap, flagged to doyle, NOT yet a separate finding).** During teardown
of the disposable probe perch: a proper `spt api session-end <id> --erase` wiped the perch (owlery dir
gone, no process) **but the endpoint stayed in the subnet roster** (`identity/registry/SPT_DEV.json`)
listed `Active` with no perch behind it; `spt endpoint stop <id>` reported "address unregistered" yet
the roster line persisted; there is **no CLI verb to forget a roster entry**, and hand-editing the
registry JSON is **immediately overwritten by the single-writer daemon** (which re-adds the entry). A
daemon bounce (the likely reconcile) was declined as too disruptive to the operator's live perches
(F-012). Net: a ghost `Active` roster line can outlive an erased endpoint with no supported way to
evict it. (Also noted: `bind` defaults `--type live_agent`, so a bare disposable `bind` triggers the
livehost to spawn a `<id>-psyche` — bind disposables with `--type gateway` to avoid it.)

**Status:** **ROOT-CAUSED (perri) → RULED (doyle 2026-06-17): fork (a) — spt-core BUG.** doyle: the
schema already promises `value` "with substitution", so spt-core not applying it in endpoint-run is a
silent correctness bug (empty inject → seeds-not-binds → zero perch, no error). **The adapter manifest
is CORRECT as authored — no wrapper binary** (fork b rejected: a shim would mask a bug every adapter
routing an id via `[env]` would hit). Dispatched as **`REQ-HAZARD-ENV-SUBST` to todlando on the
v0.11.0-findings line** (pairs with `REQ-SEND-SPT-HOSTED` — the two spt-core halves that make
`endpoint run` fully reachable). **Our adapter int is HELD** until the env-subst fix gates+releases;
doyle pings when ready, then the int asserts: `endpoint run <id>` → `SPT_ENDPOINT_ID` populated →
SessionStart **binds** → bound perch on disk + reachable via next `api poll`. Ghost-roster (secondary)
= a separate **daemon-side finding doyle is minting** (a local roster entry whose backing perch is
erased should self-heal/epoch-lease-evict); leave it, harmless, no supported evict today. All probe
artifacts torn down; box at the X/help/wall-a/doyle baseline (modulo the harmless ghost). pid 60824
(doyle's original wall-b orphan) — he reaps it pid-scoped.

**VERIFIED FIXED + INT LANDED (2026-06-17, spt v0.11.0 / counter 24).** Updated 0.9.1→0.11.0 and
re-ran the operator's exact flow under a disposable id: `spt endpoint run --adapter claude-spt --id
<disp> --start` → SessionStart saw a **populated** `$SPT_ENDPOINT_ID` → `bind` → **BOUND perch on disk**
in ~4s → `spt send <disp>` → **`SENT`** (live PTY inject, REQ-SEND-SPT-HOSTED). The missing int is
landed: `ci/launcher/bind-int.sh` (**REQ-CC-LAUNCHER-BIND**, int-only — impl/unit/doc stay under
REQ-DIST-SHORTCUT-BASENAME), 4/4 green, SPTC_ACCEPTANCE-gated, disposable id, full teardown,
self-gates SKIP on < 0.11.0. Incidental 0.11.0 confirms: rc/daemon-bounce survives clean; the F-013
ghost-roster (erased endpoint stuck `Active`) **self-healed** — doyle's `REQ-HAZARD-ROSTER-GHOST`.

**KNOWN-MINOR — `< 0.11.0` silent-seed (doyle-ruled 2026-06-17, NON-blocking).** On spt-core
< 0.11.0 the `[env.SPT_ENDPOINT_ID]` inject is not substituted → endpoint-run silently SEEDS instead of
binding (no perch, no error). Ruling: **no min_spt_core floor-bump** (ready/live work on 0.9.0; a
blanket floor is too broad) and **no runtime guard** — a `< 0.11.0` endpoint-run spawn is
**env-indistinguishable** from a normal user-launched seed (both: `SPT_RELEASE_SEED` + `OWL_SESSION_ID`
set, `SPT_ENDPOINT_ID` empty — empirically verified on this node's own session), so any guard would
false-positive "update spt" on every normal seed (worse than the narrow, self-healing miss). Handled by
the doc-note in `adapter/claude-spt.toml` `[env.SPT_ENDPOINT_ID]`. Narrow + transient (only a node
still on < 0.11.0 running `endpoint run`; the fleet updates forward). **F-013 fully closed.**

---

## F-009 — command templating substitutes a `{key}` into the command STRING then whitespace-splits

**Surfaced:** 2026-06-16, v0.8.1 dogfood of the daemon-hosted Psyche (the F-006/REQ-INSTALL-11 proof).

**The gap.** The `[session.psyche_init]` (and `[digest]`) command is authored as a single template
string with `{key}` placeholders:

```
command = "claude-spt-psyche --id {id} --session-id {session_id} --prompt {psyche_prompt}"
```

spt-core substitutes the daemon-filled values **into the string** and then **splits the result on
whitespace** to build argv. So a multi-word fill does not arrive as one argument — it explodes.
`{psyche_prompt}` is always a sentence; argv-capture (instrumented `claude-spt-psyche` dumping its raw
argv to a file when daemon-spawned) showed exactly this:

```
--id  sptc-argv-cap-psyche
--session-id  sptc-argv-cap-sess
--prompt  PSYCHE  REVIVAL  time:  epoch-ms:1781652607426  incoming  event:  (none)   <- 7 tokens
```

**Consequence.** Any adapter whose command has a multi-word fill is broken unless its receiving binary
slurps the stray tokens. The published `[digest]` extractor survives only by accident — its fills
(`{session_id}`, `{source}`) are single-token. The Psyche runner's strict `--prompt` parser took
`PSYCHE`, rejected `REVIVAL` as "unknown arg", and exited 2 — which the detached host masked (F-010).

**Adapter workaround (shipped, ddf1965).** `claude-spt-psyche` parses `--prompt` **greedily/terminally**
— it consumes every remaining token and rejoins with spaces (the manifest keeps `--prompt` last).
Robust whether spt-core splits or passes one arg.

**Recommended spt-core fix.** Split the command template into argv **first**, then fill each
placeholder slot as exactly **one** argv element (no post-substitution whitespace split). This makes
multi-word fills usable without every adapter hand-rolling a slurp. Alternatively, document the
constraint loudly (fills must be single-token) — but that effectively forbids prompt-like keys.

**Status:** **RESOLVED-SHIPPED + RE-VALIDATED (spt v0.8.2 / counter 18, 2026-06-17).** doyle's fix:
command-template substitution now fills each `{key}` as ONE argv element (tokenize-then-fill), applied
to every `[session.<role>]` template. Re-validated by argv-capture on the daemon-spawned psyche with a
STRICT single-value `--prompt` parser (greedy workaround removed so spt-core's fill is what is tested):
the psyche HOSTED, and the raw argv had exactly 7 elements with the `--prompt` value = the entire
multi-line prompt as ONE element (newlines intact). The shipped adapter keeps greedy `--prompt` as
defensive (a single element passes `join(" ")` unchanged; a pre-0.8.2 split is still reconstructed).

---

## F-010 — `psyche_host_error` still masks a host that spawns then exits immediately

**Surfaced:** 2026-06-16, same v0.8.1 dogfood. **Builds on** doyle's v0.8.1 `psyche_host_error`
surface (the additive `info.json` field + `spt endpoint list`/`whoami` rendering).

**The gap.** v0.8.1 makes a *spawn* failure harness-reachable, but the failure mode we actually hit
was a spawn *success* followed by an immediate child exit. Because the daemon's detached `spawn()`
returned `Ok`, `psyche_host_error` stayed **clear** while the hosted process was already gone — nested
`{id}-psyche` `info.json` read `status=online` with a real-looking (already-dead) pid, and `spt
endpoint list`/`whoami` showed no error line. A crash-on-startup host is indistinguishable from a
healthy one. (Here the child exited 2 from F-009; arg-parse is just one way a host can die fast.)

**Recommended spt-core fix.** Treat a non-resident host as a host failure: e.g. confirm the child is
still alive a short interval after spawn (or that the `{id}-psyche` perch actually re-registers /
comes online) before clearing/omitting `psyche_host_error`, and record `{reason: "host exited <code>
within <n>s"}` otherwise. This closes the last masking gap so "online + no Psyche + no cause" cannot
recur.

**Status:** **RESOLVED-SHIPPED + RE-VALIDATED (spt v0.8.2 / counter 18, 2026-06-17).** A daemon-hosted
psyche that spawns then exits immediately is now reported a FAILED host: the daemon stamps the
harness-reachable `psyche_host_error { reason, ts, attempts }` on the PARENT perch, de-onlines the
phantom nested `{id}-psyche` perch, un-hosts, and arms a cooldown. Re-validated by deploying a
psyche that `exit(2)`s at startup: the parent perch got
`psyche_host_error{reason:"host not resident within 5s (psyche perch missing/dead pid)", attempts:2}`,
and both `spt endpoint list` and `spt whoami` rendered `psyche-host: FAILED (...)` after the liveness
line (status itself stays `online` — liveness remains authoritative). No more silent phantom.

---

## F-016 — published `[message-idle-translation-binary]` contract omits the mandatory `{commit}` terminator

**Surfaced:** 2026-06-22, building the `[message-idle-translation-binary]` seam (v0.13.0 harness
contract) public-surface-only. This is the flagship case for the blind-build: a binary authored
strictly from the published contract would FAULT live, because the contract is incomplete.

**The gap.** The published harness-contract
(`sabermage.github.io/spt-releases/harness-contract/manifest.html`, `[message-idle-translation-binary]`)
documents the translation binary's stdout command vocabulary as exactly `{"key":…}` / `{"delay_ms":…}`
/ `{"text":…}`, and gives the degenerate baseline verbatim as `{"text":payload}{"key":"enter"}`. It
makes **no mention** of `{"commit":true}`, an `InjectFloor`, or a commit deadline. But the broker
requires a trailing `{commit}` to terminate an inject sequence — so a binary built faithfully from the
published vocabulary (including the doc's own degenerate example) emits no terminator and **faults on
every delivery**.

**Confirmed from source (doyle, 2026-06-22).** `run_inject_worker` (broker.rs:1075-1090) ends an
inject sequence ONLY on an explicit `{commit}`; `Text`/`Key`/`Delay` just enqueue. With no `{commit}`,
the sequence hits `INJECT_COMMIT_DEADLINE` (5s, broker.rs:151-169) and FAULTs (broker.rs:832-846;
Layer-G "no-commit FAULT test"). On the fault the broker flushes + releases anyway (1015-1022) so
input is not lost, but every delivery faults and stalls to the 5s deadline. The reference response IS
`{text:payload}{key:enter}{commit:true}` (translation.rs:74-78) — `{commit}` is separate from, and
after, the submit. Two distinct signals: the trailing `\r` (or `{key:enter}`) submits the PTY *line*
(verbatim — broker.rs:1066); `{commit}` terminates the *sequence* and releases the InjectFloor that
buffers the live controller's input during emission.

**Resolution — two fixes:**
- **(i) Adapter binary — DONE.** `tools/cc-spt-idle-translate` now appends a trailing `{"commit":true}`
  after the `\r`-submit (sequence: `ctrl+s` · 50ms · `{text:"<envelope>\r"}` · `{commit:true}`). 11
  cargo tests, incl. `sequence_terminates_with_a_mandatory_commit`. The `\r`-in-text submit is
  unchanged (correct + verbatim); `{commit}` is the additive terminator.
- **(ii) spt-core contract — SHIPPED 2026-06-22.** `manifest.md` republished + live on gh-pages
  (`harness-contract/manifest.html`): the stdout vocabulary now lists `{"commit":true}`, documents it
  as the mandatory sequence terminator (inject-floor release + 5s commit-deadline + raw-inject
  fallback), and the degenerate example is corrected to `{text}{key:enter}{commit:true}`. Re-verified
  by re-fetch; the binary's module doc now cites the corrected published contract.

**Status:** **RESOLVED — both fixes shipped** (adapter binary appends `{commit}`; published contract
corrected + live). The only residual is an end-to-end re-confirm via `translate-proof`, pending the
v0.13.1 cut (counter 28+) — not a code wait. Also spawned the sibling DX win (no `translate-proof`):
doyle triaged the missing author-time proof (`spt adapter translate-proof`, the EMIT-half mirror of
`digest-proof`) → todlando built it (PR #28). Its no-commit gate would have caught this same defect at
author time; runs post-release to confirm the fixed binary green. Caught here BEFORE any live FAULT —
exactly what the blind-build exists to surface.

---

## F-011 (cont.) — the `*-proof` commands can't resolve a GhReleaseManaged dev adapter (author-time-loop friction)

**Surfaced:** 2026-06-22, running `spt adapter translate-proof` (v0.13.1) against `claude-spt` in
local dev. Same root class as F-011 (a Pointer/GhReleaseManaged adapter whose manifest isn't at the
resolver's expected install path → resolution fails), now hit via the author-time proof commands.
doyle acked it 2026-06-22 and is folding the fix into the v0.13.x adapter-DX batch.

**The friction.** `claude-spt` declares `[update] avenue = "gh_release"`, so `spt adapter add
<dev-manifest-file>` registers it **GhReleaseManaged**. The `*-proof` resolvers (`translate-proof`,
and the same path `digest-proof` uses) then want the **extracted install shape** — `manifest.toml`
plus the binary **co-located** in the install dir — not the dev source file. With a bare-file add the
proof fails:

```
$ spt adapter add "$PWD/adapter/claude-spt.toml"          # registers a GhReleaseManaged pointer
$ spt adapter translate-proof claude-spt --event '<EVENT…>'
TRANSLATE_PROOF_FAIL:claude-spt: adapter 'claude-spt' is registered as a pointer but its manifest is
not present yet at <dir> — the adapter's binary/manifest has not been extracted/downloaded …
```

…even though the dev manifest is right there (just named `claude-spt.toml`, not `manifest.toml`, and
the binary lives under `tools/…/target/release/`, not co-located).

**Workaround (in `ci/idle-translate/translate-proof-int.sh`).** Stage a disposable install dir that
mirrors the extracted shape — `manifest.toml` (the renamed manifest) + `strings/` + the built binary
co-located — and `adapter add` *that dir*. Then the proof resolves and passes (TRANSLATE_PROOF_OK,
commit: yes). **Knock-on:** the older `ci/digest/digest-proof-int.sh` uses the bare-file form and so is
now **stale on 0.13.x** (would hit the same error); it needs the same install-dir staging.

**Suggested fix (doyle agreed, batched into v0.13.x adapter-DX).** Add a `--dir <path>` / `--manifest
<file>` override to the `*-proof` family — mirroring `digest-proof`'s `--sample` pointing straight at a
file — so an author can proof a DEV binary against a DEV manifest without staging a full extracted
install. Tiny, and it un-stales `digest-proof-int.sh` too.

**Status:** **acked + tracked by doyle (2026-06-22), batched into the v0.13.x adapter-DX scope.**
Non-blocking — the disposable-install-dir staging is a clean workaround and the int is GREEN with it.
