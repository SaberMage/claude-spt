# Building an SPT harness adapter — field tips

> Durable lessons from building `claude-spt` (the Claude Code adapter) against spt-core's
> **published public surface** (`spt-releases` binary + `manifest.schema.json` + the GH-Pages
> harness-contract docs). Everything below is behavior of the **existing public framework** —
> verified against a live `spt` binary, not aspirational. Harness-agnostic where it can be;
> Claude-Code-specific points are marked **[CC]**.

## The adapter lives in the spt-core registry

An adapter — its `*.toml` manifest, profiles, `[strings]`, the `[digest]` extractor binary, any
runner binaries — is registered with **`spt adapter add <dir>`** into the node-local adapter
registry. The manifest/binary version tracked there (`spt adapter list`) is the **version-of-truth**
for what the adapter actually does. That is the whole, universal delivery mechanism: every spt
adapter ships this way.

> **Project-specific aside (not framework):** `claude-spt` *also* publishes a thin harness plugin to
> a marketplace (skill stubs + `hooks.json` + `plugin.json` + bootstrap) so casual users can install
> it. That is one project's distribution choice — an adapter does **not** have to ship a plugin. If
> you do: keep no binary/manifest/runtime-state in the plugin (those ride the registry), and treat
> the plugin's version as independent of the manifest/binary version (separate schedules).

## The manifest is static templates — runtime logic lives in binaries

The single most important design rule:

- **Manifest fields are static, spt-filled templates.** They cannot express env vars, runtime
  values, or conditionals. `{key}` placeholders are substituted by spt-core from a fixed catalog
  (`{session_id}`, `{parent_pid}`, `{adapter_name}`, `{id}`, digest/psyche keys, …); `~` expands
  home (there is no `{home}` key).
- **Any behavior that depends on runtime state belongs in a binary the manifest points at** — the
  `[digest]` extractor, a `[session.*]` runner, etc. Example: if the harness can relocate its
  state directory at runtime, the manifest `source` is only the *fallback* root; the extractor
  must resolve the real location itself.
- Corollary: a profile/string/hook expressed purely in `.toml` has **no executable code of its
  own** — you can only verify it by registering and resolving it on the live binary, not by
  unit-testing it. Anything you want to cover with real tests must live in a binary (an
  extractor/runner change), not a `.toml` leaf.

## Profiles: sparse leaf-replace overlays

- A profile is selected as the composite `<adapter>:<profile>` (e.g. `claude-spt:deep`). It
  **leaf-replaces only the leaves you declare**; everything else inherits from base.
- Override exactly what differs:
  - `[profiles.<name>.session.self].command` — retarget the spawn/bringup command.
  - `[profiles.<name>.digest].<key>` — e.g. widen `window_turns`.
  - `[profiles.<name>.session.psyche_init]` — add the LiveAgent companion seam (presence of
    `psyche_init` on the merged view is what flips an endpoint to a live agent).
- **Make an overlay observable** by also leaf-replacing one `[strings]` key (e.g.
  `adapter_label`). Then `spt adapter get-string <adapter>:<profile> <key>` differs from base —
  that diff is your proof the overlay resolved. This is the cheapest profile acceptance assertion.
- A profile that wraps the launch in another binary works **iff** that binary is a drop-in for the
  base harness binary on the same argv, and inherited env passes through it. **[CC]** Routing CC
  through a launcher wrapper (e.g. a model/billing multiplexer) is exactly this: replace
  `[profiles.<name>.session.self].command` and let `SPT_ENDPOINT_ID` ride inherited env unchanged.

## Hooks: the adapter wires the harness, spt-core stays agnostic

- spt-core supplies the harness-**independent** `spt api` primitives + their I/O format. The
  adapter authors all harness-specific wiring. spt-core does **not** materialize a harness-native
  hook config — the plugin **hand-writes** its `hooks.json` shelling out to `spt api`.
- Canonical CC-hook → `api` mapping that works on the public surface:
  - **SessionStart** → `api seed --pid {parent_pid} --session-id {session_id} --adapter {adapter_name}`
    (seed the endpoint — **not** a blocking listen).
  - **UserPromptSubmit** → `api poll {session_id}` (drain inbox to stdout) + keyword hints.
  - **Stop/idle** → `api state idle|busy` (Stop cannot inject → relay/echo-gate fallback).
  - **SessionEnd** → `api session-end {session_id}`; graceful shutdown → `api shutdown <id>`.
  - **SubagentStart/Stop** → `api worker-start`/`worker-stop`.
  - The **blocking listen/poll loop is a `/ready` or `/live` skill, never SessionStart** — a hook
    that blocks would hang session bringup.
- **Message delivery is stdout framing.** `api poll` emits the self-delimiting envelope
  `<EVENT type="msg" from="<sender>">body</EVENT>` (also used for the live listener stream).
  Multi-message drains split cleanly on `</EVENT>`. Body decode rule: split on `<br>` → newline,
  then HTML-unescape `&lt; &gt; &quot;` and `&amp;` **last**. Route that stdout into the harness's
  injection channel (**[CC]** `additionalContext`) — that routing is adapter glue.
- **The injection channel can have a size cap — pre-empt it.** **[CC]** CC truncates
  `additionalContext` over ~10k chars by spilling it to a file, which *evicts it from the inline
  context the agent sees* — a large drain (or a big skill body + drain together) silently loses
  messages. Cap the combined hook output adapter-side under the threshold: under it pass through
  verbatim; over it spill the **full** text to an agent-readable file and inject only a short
  pointer. Never a mid-`<EVENT>`/mid-record head-cut — that splits an envelope and drops a message.
  (Any harness injection channel with a size limit wants the same pattern.)
- **Skill-instruction injection rides the same prompt hook — but inject BEFORE the perch gate.**
  **[CC]** The UserPromptSubmit hook also detects `/<plugin>:<skill>` in the prompt (leading-token
  match, so prose merely mentioning it mid-sentence does not fire) and injects that skill's `[strings]`
  body. Run the injection **before** the perch/listen check, then drain: skills like `whoami`/`setup`
  are valid with **no readied perch**, so gating injection on a bound perch silently breaks them. The
  message-drain stays perch-gated; the skill-body inject does not.
- **The installer/`setup` skill must be self-contained in its stub — it cannot depend on injection.**
  Injection resolves a body via `spt adapter get-string`, but the setup skill runs precisely when the
  binary may be **absent** (installing it is the whole job) — a skill whose precondition is "spt
  missing" cannot source its instructions from spt. Carry its operative steps in the harness-native
  skill stub (the floor); let the file-backed body only **mirror** them for the present-binary repair
  path. (The bootstrap paradox: the one skill that most needs delivery is the one delivery can't reach.)

## `[strings]`: inline or file-backed pointers

- A `[strings]` value is either an inline string or a **file pointer**:
  `key = { file = "relative/path" }`, resolved **lazily** by `spt adapter get-string` to the file
  contents (live edits reflect without re-registering).
- Pointer files live under the per-adapter aux dir (`adapter/strings/…`), copied into the registry
  on `adapter add`. **Containment is enforced at register time**: `..` or absolute paths escaping
  the `strings/` dir fail the add (manifest-first: nothing registers on an invalid manifest).
- Use this to keep skill-instruction bodies out of the manifest (`[strings.skills].<x> =
  { file = "skills/<x>.md" }`) — the body is the UPS-injection source, the manifest stays thin.
- **Delegate volatile guidance to `spt how-to <topic>` rather than hand-copying it.** spt-core ships
  task-oriented agent guidance as a first-class surface: `spt how-to` lists topics (`ready` + `send`
  exist today), each a canonical write-up of the verbs, flags, and result codes. A messaging skill
  body that says "run `spt how-to send` and follow it" tracks the published contract automatically
  instead of drifting from a copied summary. (`how-to` is also a fast way to learn the surface while
  authoring — the binary self-documents.)

## `[digest]`: the transcript→record extractor seam

- `[digest]` **must** name where it reads: either `source` or a `[history].locate_template`. The
  JSON schema alone accepts `[digest]` with just `extractor`, but `spt adapter add` rejects it —
  this cross-field rule only surfaces at registration. Validate against the live binary.
- The extractor is invoked `--session {session_id} --in {source}`. `{source}` is a **root**; the
  extractor locates `<session_id>.jsonl` within (the harness's internal subdir scheme is the
  harness's business — spt-core stays agnostic and bakes no harness directory scheme into the key
  catalog). Handle both shapes: `--in` a directory (locate the session) and `--in` a direct file
  (a `digest-proof --sample` log).
- **[CC]** Claude Code stores transcripts at `<root>/<cwd-slug>/<session_id>.jsonl`, and can
  **relocate its whole state tree via `CLAUDE_CONFIG_DIR`** (set by launcher wrappers / isolated
  profiles). Because that value is runtime, not static, the extractor must prefer
  `$CLAUDE_CONFIG_DIR/projects` over the manifest `--in` root on its directory branch — the
  manifest cannot express it. Leave the explicit `--sample` file path untouched.
- Emit **raw** records (`{role∈input|agent|tool, text?, tool?, ts?}`, one NDJSON line each);
  spt-core's renderer applies the presentation defaults (`window_turns`, `arg_truncation`,
  `sprint_collapse`). Don't pre-render.
- **Emit UTF-8 stdout.** The NDJSON contract is UTF-8; a binary that defaults stdout to the platform
  locale (e.g. cp1252 on Windows) mangles non-ASCII (em-dashes, smart quotes) into bytes spt-core
  can't decode — and spt-core reads the stream as UTF-8. Pin it explicitly (native-UTF-8 languages
  sidestep the whole class). This cross-platform encoding trap is exactly why the seam is a binary,
  not a shell pipeline.

## Bringup / launcher seam

- `[session.self].command` is the spt-hosted bringup template (`spt endpoint run` spawns it into a
  broker PTY). For a harness with no native session-id flag, mint the id internally and pass the
  endpoint id via **`[env.<VAR>]`** (`direction = "inject"`, `value = "{id}"`); the SessionStart
  hook reads the env and self-registers (`api bind <id>`). The bind needs **no credential token** —
  for a broker-spawned session **auth is intrinsic** (the broker parentage is the proof), so
  `api bind <id> --set-session-id <discovered>` alone establishes it; later mutating calls prove
  association with the session id the bind recorded.
- `adapter.shortcut_basename` brands the `endpoint run` launcher shortcut (`<basename>-<id>`),
  **decoupled** from the adapter name.

## Live-agent seam: `[session.psyche_init]` + the companion runner

- An endpoint is a **live agent** iff the *resolved* manifest declares `[session.psyche_init]` (no
  go-live verb exists). Base manifest without it = ready agent; a `:live` profile overlay that adds
  it = live agent. The daemon checks this on the **merged** view, so a profile selected at **seed
  time** (`spt api --adapter <adapter>:live seed`) propagates all the way to the spawn decision —
  the bound profile drives runtime lifecycle, not just bringup argv.
- `psyche_init` fills exactly four keys: **`{id, session_id, psyche_dir, psyche_prompt}`**. `{id}`
  is **overridden** by spt-core to `<parent>-psyche` before substitution — the companion gets its
  own derived perch id, not the parent's. (`{session_name}` is a `[session.self]` fill, not a psyche
  key; a first spawn has no `{psyche_context}` — that is the resume/preload key, a different seam.)
- The companion is launched **detached, fire-and-forget**: `detach = true`, `cwd = "{psyche_dir}"`,
  stdio null, handle dropped, **unsupervised** — liveness is daemon-authoritative via the companion's
  perch, not its pid. It owns the `<parent>-psyche` perch, communicates by perch + commune file-drops
  (never stdin/stdout), and exits at session end.
- **`psyche_init.command` is adapter-authored and opaque to spt-core** — the companion runner is the
  *harness's* to build (spt-core never dictates harness invocation). Treat the Psyche as
  **daemon-managed**: declare the seam and build the runner, but do **not** orchestrate the
  companion's lifecycle from the adapter — the daemon owns spawn + teardown (a graceful
  `endpoint shutdown` tears the companion down together with the perch).
- **[CC]** A bare one-shot headless invocation (`claude -p <prompt>`) exits after a single turn and
  can't be re-looped by Stop hooks, so the runner is a small **resident wrapper**: seed the companion
  session once from `{psyche_prompt}`, then drive one resume-turn per perch pulse (poll the
  `<parent>-psyche` perch; `claude --continue -p <pulse>`), the companion authoring commune drops.
  Build it like the `[digest]` extractor — a compiled, dependency-light binary the daemon can spawn
  bare on any platform — not a shell script (the daemon execs the command directly, cross-platform).

## Lifecycle file-drops (not api verbs)

- commune / signoff are **file-drops**, not `spt api` calls: the agent writes
  `<endpoint_id>-commune.md` / `<endpoint_id>-signoff.md` into the manifest-declared
  `[session].commune_dir` / `signoff_dir`; spt-core's daemon watcher ingests then deletes it
  (daemon is the single writer). The filenames are contract-fixed; only the dir is adapter-declared.

## Validate against the live binary — registration is a second gate

- JSON-schema validity is necessary but **not sufficient**. `spt adapter add` runs cross-field
  registration validation that the schema can't express (e.g. the `[digest]` source rule). Build a
  registration integration check that does: `adapter add` → `adapter list` (assert the adapter +
  each shipped profile composite resolves) → `get-string` (base value + each overlay diff +
  file-backed pointers resolve to body) → soft `adapter remove` (leave the registry clean). Gate it
  behind an opt-in env flag + a minimum `spt` version; it mutates the node-local registry.
- Two more author-time acceptance tools on the public surface, no live session required:
  - `spt api --adapter <a> --manifest <file> capability` reports the manifest's hostable types
    **without** a full registry `add` — assert it advertises the hostable harness the bringup spawns.
    (`adapter add` is manifest-first: an invalid manifest registers nothing, so a clean `add` already
    proves the cross-field shape; `capability` is the lighter, non-mutating check.)
  - `spt adapter digest-proof <a> --sample <file>` runs the real `[digest]` extractor through the
    registry and renders the result — proving the transcript→record→render path end-to-end on a fixed
    sample log. It fills the same runtime substitution keys the daemon does, so "passes proof" ⟺
    "works at runtime" (confirm against a recent `spt` — older binaries passed an empty key map).
- **Observable behavior of the public binary is itself public surface** — when prose docs lag, a
  byte-capture against the live `api`/`adapter` surface is a legitimate way to confirm a contract.
