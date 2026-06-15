# spt-core public-surface findings

> Per the public-surface-only constraint (`AGENTS.md`, `HANDOFF.md` §1): if a capability needed
> to build the adapter is missing/ambiguous in spt-core's **published** surface (`spt-releases`
> releases + GH Pages docs), that is a **finding** — `spt-core`'s published contract has a gap.
> We report it to the spt-core owner (**doyle**) and do **not** reverse-engineer from legacy
> `claude_skill_owl` or reach into spt-core source. This file is the in-repo log of those findings.

| # | Date | Status | Summary |
|---|------|--------|---------|
| F-001 | 2026-06-14 | **re-scoped 2026-06-15** — most = adapter-authoring (closed); 1 residual spt-core docs item open | Hook-wiring for a CC adapter — boundary clarified |
| F-002 | 2026-06-15 | **resolved-by-design** (ADR-0020) — envelope self-delimits; impl refactor pending | `api poll` agent path has no inter-frame delimiter → multi-message drains are unsplittable |
| F-003 | 2026-06-15 | **open** — M12/v0.7.0 published, but the file-backed `[strings]` capability ADR-0001 depends on is **absent** from the public surface | No mechanism to externalize large `[strings]` values to files — `[strings]` is inline-only |

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
- **Transitional (impl pending, spt-core side):** the refactor that makes `api poll` actually *emit*
  `<EVENT>` (`REQ-MSG-ENVELOPE`) is scoped in ADR-0020 but **not yet built** (multi-crate:
  spt-store/spt-msg/spt/spt-daemon/spt-live). The current 0.6.0 binary still emits the `__REPLY_TO__`
  relic at the poll surface. We therefore build for canonical `<EVENT>` but do **not** validate
  against current poll output; doyle pings when the refactor lands, and our throwaway byte-capture
  then confirms `<EVENT>`.

---

## F-003 — No file-backed `[strings]` mechanism on the M12/v0.7.0 public surface (ADR-0001 dependency unmet)

**Reported:** 2026-06-15 to doyle + todlando. **Status:** open — spt-core capability gap (M12 shipped
without the dependency ADR-0001 names).

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
