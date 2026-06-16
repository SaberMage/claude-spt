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
| F-005 | 2026-06-15 | **TRIAGED (doyle) — (a)+(b) mix, nothing unbuildable** — 2 of 3 sub-claims were docs-read misses; residuals = author Ed25519 key-provisioning doc + zero-touch auto-activation roadmap (REQ-UPD-1/M4). **Bridge that works today: `spt adapter add --github <repo>`** | End-user adapter activation step (`adapter add [--github]`) was undocumented in install-on-demand/checklist; binary-present ≠ adapter-active |

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

**Resolution — RESOLVED-BY-DESIGN (ADR-0020, operator-ruled 2026-06-15):** the framing question is
settled, more cleanly than a delimiter patch. The **canonical format at every surface — including
`api poll` — is the `<EVENT type="msg" from="<sender>">body</EVENT>` envelope** (`spt-proto::event`,
the ADR-0001 grammar the live listener already emits). `__REPLY_TO__` was a **mis-elevated relic**
(wrongly frozen as the "stable wire format" during the clean-room port) and is being **deleted from
spt-core**. The `<EVENT>` envelope is **self-delimiting**, so multi-message drains split cleanly on
`</EVENT>` — no delimiter needed, and the F-002 multi-frame hold is **lifted**.

- **Our parser** now targets `<EVENT>` (the `from` attr → `<sptc_messages from="…">`, `<br>` →
  newline, entity unescape with `&amp;` last) — exactly the live-agent body-parsing rule. See
  `render_frames` in `plugin/sptc/hooks/_common.sh` + `tests/hooks-parse.sh` (multi-message covered).
- **VERIFIED ON THE PUBLISHED SURFACE (v0.7.1, 2026-06-15).** ADR-0020 shipped in **v0.7.1**
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
  ADR-0020 loop closed: design→impl→gate→ship→real-surface-verify.

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

**Surfaced:** 2026-06-15, authoring the claude-spt `[digest]` extractor (ADR-0019).

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
ADR-0019 engine (§diagnostics), so it must supply the same keys. It doesn't → it is infidelitous to
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
