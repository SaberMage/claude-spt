# Building an SPT harness adapter — field tips

> Durable lessons from building `claude-spt` (the Claude Code adapter) against spt-core's
> **published public surface** (`spt-releases` binary + `manifest.schema.json` + the GH-Pages
> harness-contract docs). Everything below is behavior of the **existing public framework** —
> verified against a live `spt` binary, not aspirational. Harness-agnostic where it can be;
> Claude-Code-specific points are marked **[CC]**.

## Mental model: two publish layers, never one

An adapter ships to **two independent targets** — keep them straight:

| Layer | Carries | Where | Versioned by |
|---|---|---|---|
| **spt-core adapter registry** | the `*.toml` manifest, profiles, `[strings]`, `[digest]` extractor binary, any runner binaries | `spt adapter add <dir>` (node-local registry) | the adapter manifest/binary version — the **version-of-truth** (`spt adapter list`) |
| **Marketplace skeleton** (e.g. cplugs) | thin skill stubs, `hooks.json`, `plugin.json`, the SessionStart bootstrap | the marketplace repo / `<harness> plugin install` | the marketplace `plugin.json` version |

- **No binary, no manifest, no runtime state in the marketplace skeleton.** Those ride the
  registry layer. The skeleton is install-shaped glue only.
- **The two version numbers are independent** and move on separate schedules — never sync them
  reflexively. The marketplace version bumps rarely (only on *structural* skeleton change:
  new/removed skill stub, hook wiring, bootstrap, `plugin.json`). The manifest/binary version is
  the one users see via a `version` skill.

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
- Corollary for **requirement traceability**: a profile/string/hook expressed purely in `.toml`
  has **no `impl` code of its own** — its evidence is `doc` (the manifest/docs) + `int` (it
  resolves on the live binary). Real `impl`/`unit` evidence lives in the binaries. If you want a
  profile to carry `impl`, the impl must be runtime code (an extractor/runner change), not a
  `.toml` leaf.

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

## `[strings]`: inline or file-backed pointers

- A `[strings]` value is either an inline string or a **file pointer**:
  `key = { file = "relative/path" }`, resolved **lazily** by `spt adapter get-string` to the file
  contents (live edits reflect without re-registering).
- Pointer files live under the per-adapter aux dir (`adapter/strings/…`), copied into the registry
  on `adapter add`. **Containment is enforced at register time**: `..` or absolute paths escaping
  the `strings/` dir fail the add (manifest-first: nothing registers on an invalid manifest).
- Use this to keep skill-instruction bodies out of the manifest (`[strings.skills].<x> =
  { file = "skills/<x>.md" }`) — the body is the UPS-injection source, the manifest stays thin.

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

## Bringup / launcher seam

- `[session.self].command` is the spt-hosted bringup template (`spt endpoint run` spawns it into a
  broker PTY). For a harness with no native session-id flag, mint the id internally and pass the
  endpoint id via **`[env.<VAR>]`** (`direction = "inject"`, `value = "{id}"`); the SessionStart
  hook reads the env and self-registers (`api bind <id>`).
- `adapter.shortcut_basename` brands the `endpoint run` launcher shortcut (`<basename>-<id>`),
  **decoupled** from the marketplace plugin name.

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
- **Observable behavior of the public binary is itself public surface** — when prose docs lag, a
  byte-capture against the live `api`/`adapter` surface is a legitimate way to confirm a contract.

## Release mechanics

- The **CHANGELOG section is the public release body verbatim** — a release fails loudly without a
  `## [<version>] - <date>` section for the tagged version. Write **user-facing UX only** (name the
  actual commands/flags users touch); no requirement ids, module names, or commit hashes.
- Package the marketplace skeleton with a **dry-run-by-default** stager that validates first and
  copies only the skeleton subset; the marketplace commit/push + install stays the operator's step
  (credentials + pointer flip).
