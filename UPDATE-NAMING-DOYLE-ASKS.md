# spt-core asks — one-command update, binary consolidation, name unification

> **STATUS: RESOLVED (doyle, 2026-06-25, grill-with-docs w/ operator) — see the Resolution section
> below.** Design locked in spt-core `docs/design/v0.8.0-update-arc-and-cli.md` + **ADR-0029** (8 REQs
> seeded). The ask prose below is preserved as the record of what was asked; outcomes are tagged
> `RESOLVED:` under each ask. doyle builds **spt-core v0.16.0** next; the adapter wiring follows on ship.

> A grill prompt to take to doyle. Three capability asks + one heads-up, each framed as a
> proposal with the contract shape we want and the open questions for doyle to rule on. Context:
> ADR-0005 (name unification) and ADR-0006 (one-command update + consolidated binary) in this
> repo. Goal: a casual user keeps **all** of the adapter current with `spt adapter update claude-spt`
> (the only manual residual being `/reload-plugins`, which is an unavoidable Claude Code TUI action).
>
> Public-surface-only stance: these are capabilities we believe are missing from the published
> surface; we're asking, not reaching into spt-core. Each should land as an F-0xx finding once shaped.

## Framing for doyle

The adapter ships in two homes (ADR-0001): the spt-conducted **adapter** (`spt adapter update` — manifest
+ binaries + strings) and the low-churn **cplugs plugin skeleton** (`claude plugin update` — hooks.json,
hook wrapper logic, skill skeletons, `plugin.json`, bootstrap). The operator wants one lever. The wall:
**hook *logic* must physically live in the CC plugin dir** (CC loads hooks there), outside `spt adapter
update`'s reach. We re-checked raw-skills/commands as an escape and re-rejected them (CC subdir
command-namespacing is broken — anthropics/claude-code#2422; user-scope skills are flat). So the plugin
stays, and closing the gap needs the asks below.

---

## Resolution (2026-06-25 — ADR-0029, spt-core `docs/design/v0.8.0-update-arc-and-cli.md`)

**Version model (correcting a project-wide conflation).** "v0.8.0" in this whole arc = the **claude-spt
ADAPTER** version. spt-core is at v0.15.0 (counter 34); its next minor is **v0.16.0** (counter 35) — there
is **no** upcoming "spt-core v0.8.0" (v0.8.x already happened, historically). Sequence: doyle ships
**spt-core v0.16.0** → pings → we cut **claude-spt adapter v0.8.0** wiring the seams below + bump
`min_spt_core_version` **0.15.0 → 0.16.0** (the honest floor for the new seams).

| Ask | Outcome | What we get |
|---|---|---|
| **1 — generic hook dispatch** | **REJECTED → RESOLVE-NOT-EXECUTE** | spt-core stays a pure resolver (executes nothing new). Two primitives instead: (a) `{adapter_dir}` (= install `source_dir`) + `{adapter_name}` substitution keys; (b) **lazy substitution inside `[strings]` values at `get-string` read time**, adapter-static keys only. Pattern: the CC hook dispatcher `get-string`s `{adapter_dir}/claude-spt hook` ONCE per session into an env var, then runs it per-hook. Hook *logic* rides `spt adapter update` (it's in our binary); `hooks.json` + a thin static per-OS dispatch wrapper go **static-forever**. Session-scoped keys (`{session_id}`) are NOT available via `get-string` (deferred) — hooks still read those from CC stdin. |
| **2 — composite `[update]`** | **GRANTED** | Avenue-agnostic **`[update.post] = {command, self_verifies}`**, runs AFTER `gh_release`, **unconditionally**. Published stdin JSON: `{adapter_applied, adapter_name, profile_name, version, previous_version, adapter_dir}`. Our **stdout arbitrates the notice**: custom text SUPERSEDES `[update].message`; a reserved sentinel fires the static message; empty = nothing. Exit code orthogonal. **Failure-isolated** (a committed pull never rolls back on a post-step fail). |
| **3 — translate takes a command** | **GRANTED** | `[message-idle-translation-binary]` gains **`command`** (args + `{adapter_dir}` subst, install-dir resolved). `path` DEPRECATED (still parses, warns). Exactly one of `{path, command}`. Protocol unchanged. → fold `cc-spt-idle-translate` into `claude-spt translate`. |
| **4 — `{node}` key** | (operator-owned; not in cluster A) | Tracked below; ships `{id}`-only until a `{node}` fill key lands. |

**Our wiring at the adapter v0.8.0 cut (post spt-core v0.16.0 ship):**
- **D2** ← `claude-spt post-update` (already built standalone, U2) → declare `[update.post]`, parse the
  stdin JSON, arbitrate the notice via stdout, honor failure-isolation.
- **D3** ← fold `cc-spt-idle-translate` → `claude-spt translate`; switch the seam from `path` to `command`.
- **D1** ← `claude-spt hook <event>` subcommand + the `{adapter_dir}/claude-spt hook` get-string resolve
  pattern; thin static per-OS dispatch wrapper; `hooks.json` static-forever.
- Bump `min_spt_core_version` → **0.16.0**.

---

## Ask 1 — generic hook dispatch: `spt api run-hook <adapter> <event>`

**RESOLVED:** REJECTED as `run-hook` → **resolve-not-execute** (`{adapter_dir}`/`{adapter_name}` keys +
lazy `[strings]` substitution at `get-string`; binary carries `claude-spt hook <event>`; `hooks.json`
+ thin per-OS dispatch static-forever). See the Resolution table above.


**Problem.** Every hook the adapter adds (this cycle's `PostToolUse` checkpoint detector) forces a cplugs
republish + `claude plugin update` + `/reload-plugins`, because the wrapper *logic* lives in the plugin.
The manifest `[hooks.<event>]` table is declaration-only today — the plugin's `hooks.json` + wrapper `.sh`
are what actually run.

**Proposal.** spt-core executes the adapter's handler for a hook event. The plugin's `hooks.json` pre-wires
**all** CC hook events to one generic stub:

```
# hooks.json (static-forever — every event, one line each)
<event> -> spt api run-hook claude-spt <event>      # stdin = the CC hook payload, verbatim
```

spt-core resolves the adapter's handler for that event and runs it, passing the hook stdin through and
surfacing any `additionalContext` back. The handler is adapter-conducted — ideally a subcommand of our
consolidated binary (`claude-spt hook <event>`, see Ask 3 / ADR-0006), so hook *logic* then rides
`spt adapter update` and `hooks.json` never changes again.

**Open questions for doyle:**
- Where does the handler live — the manifest `[hooks.<event>].fires` command (made executable, not just
  declarative), or a declared binary/subcommand spt-core invokes? Our preference: a binary subcommand.
- What's passed in (the raw CC hook JSON on stdin?) and how does `additionalContext` / the `can_inject`
  contract flow back out through `api run-hook`?
- Auth/session threading — same shape as the other id-scoped `api` calls (`--session-id`)?
- Does spt-core stay harness-agnostic here (it runs an opaque adapter-declared handler; it needn't know
  the event semantics)?

---

## Ask 2 — composite `[update]`: `gh_release` pull **+** a delegated post-step

**RESOLVED:** GRANTED as avenue-agnostic `[update.post] = {command, self_verifies}` — runs after
`gh_release` unconditionally; stdin JSON published; our stdout arbitrates the notice; failure-isolated.
(Answers 2a/2b: the post-step runs even on an adapter no-op, and its stdout — not just a "changed"
flag — drives the message.) See the Resolution table above.

**Problem.** `[update]` takes one `avenue` (`gh_release` XOR `delegated`). We need `gh_release` (to pull the
`.spt` = manifest + binaries + strings) **and** a delegated step (to run our cross-platform plugin-sync:
`claude plugin add|update <plugin>`) in the **same** `spt adapter update`. Today they're mutually exclusive.

**Proposal.** Let `gh_release` carry a post-update delegated command spt-core runs after the pull/re-register,
in the same invocation. Two sub-requirements:

- **2a — runs unconditionally.** The post-step must run **even when the adapter `.spt` version did not
  change** — the cplugs plugin can have a new version when the adapter didn't, and the user still wants one
  command to reconcile it.
- **2b — a "changed" return signals the message.** The post-step's return value can flag *applied/changed*
  so `spt adapter update` still prints `[update].message` (the `/reload-plugins` notice) even on an adapter
  no-op. (`message` today prints only when a new adapter version is applied — we need the post-step able to
  trigger it too.)

**Already confirmed (no ask):** `[update].message` exists (markdown, prints only on a real apply, no `{key}`
subst) and *"install is the first update"* — so this same flow makes `spt adapter add` bootstrap the plugin.

**Open questions for doyle:**
- Field shape — a `post_update` command on `gh_release`? a `[update.post]` sub-table? an ordered avenue list?
- The "changed" return convention — exit code? a sentinel on stdout? 
- No-op suppression — if *neither* the adapter nor the post-step changed, `message` still suppresses?
- Trust — does the post-step inherit the `self_verifies`/attest model the `delegated` avenue already uses?

---

## Ask 3 — `[message-idle-translation-binary]` accepts a command/subcommand (not a bare `path`)

**RESOLVED:** GRANTED — the seam gains `command` (args + `{adapter_dir}` subst); `path` deprecated
(parses + warns); exactly one of `{path, command}`; protocol unchanged. → `claude-spt translate`.

**Problem.** `[digest]`, `[session.*]`, and `[update]` take **command strings** (so they consolidate trivially
into `claude-spt <subcommand>`). `[message-idle-translation-binary]` takes a bare **`path`** — `path =
"claude-spt"` would spawn the binary with no args, so it can't tell it's in translate mode. This is the one
seam blocking us from folding the translation filter into the single consolidated binary (ADR-0006).

**Proposal.** Let the seam take a command (with args / `{key}` substitution) like the other seams — e.g.
`command = "claude-spt translate"` — keeping the existing stdin JSON-lines protocol unchanged. (A documented
"invoked with no args ⇒ translate mode" convention would also unblock us, but an explicit command is cleaner
and consistent with the other seams.)

**Open questions for doyle:**
- Preferred shape — promote `path` to an optional `command`, or add a sibling `command` field?
- Backward-compat for existing bare-`path` adapters (keep `path` working)?
- Does the spawn/stdin-protocol contract change at all, or is it purely how the executable is located?

---

## Ask 4 — a `{node}` substitution key for `[session.<role>]` roles  *(operator raising directly)*

**STATUS:** operator-owned, NOT in the cluster-A (ADR-0029) resolution. U6 shipped `{id}`-only
(`-n {id}` + `--remote-control {id}` on both bringup paths); upgrades to `{id}@{node}` if/when a
`{node}` fill key lands.

**Problem.** We want the spawned CC session's display name and RC channel to be `{id}@{node}` (so a same-id
endpoint on different machines is distinguishable) — `claude -n {id}@{node} --remote-control {id}@{node}`.
The substitution-key catalog is now **published**
([harness-contract/manifest.html#substitution-keys](https://sabermage.github.io/spt-releases/harness-contract/manifest.html#substitution-keys)),
and **`{node}` is confirmed absent.** Closest existing keys: `{id}`, `{session_id}`, `{session_name}`
(the *supplied* display name — circular for our use), `{adapter_name}`, `{agent_type}`, `{agents_json}`.

**Proposal.** Expose the current node name as a `{node}` (or `{node_name}` / `{host}`) fill key for the
`[session.<role>]` templates, declarable in `keys`. *(The operator is raising this in their ongoing
spt-core conversation with doyle — tracked here for completeness, not a separate filing.)*

**Open questions for doyle:**
- Key name — `{node}`, `{node_name}`, or `{host}`? Match the internal model's term.
- Available to `[session.<role>]` (where we need it), and optionally the SessionStart hooks / `[session.notif]`?

---

## Heads-up (not an ask) — name unification

We're collapsing three names to two (ADR-0005): **`claude-spt`** = the spt-core-facing identity (we're
renaming the GitHub repo `spt-claude-code` → `claude-spt`, so `--release SaberMage/claude-spt` matches
`spt adapter update claude-spt`, and the consolidated binary is `claude-spt`); **`spt`** = the Claude-Code
plugin + skills (`/spt:*`, via the planned `sptc`→`spt` succession). The repo rename changes the derived
install dir (`adapters/_github/SaberMage-claude-spt`), so the `[update].repo` and any path assumptions on
your side should expect the new repo slug. One end user today, so the re-add cost is a non-issue.

---

## Dependency map (what unblocks what)

- **Ask 1** [RESOLVED→resolve-not-execute] → hook logic rides `spt adapter update` via `claude-spt hook`;
  `hooks.json` + thin per-OS dispatch static-forever (no `run-hook`; `{adapter_dir}` + lazy `[strings]`).
- **Ask 2** [GRANTED `[update.post]`] → the plugin update is automated; only manual residual is `/reload-plugins`.
- **Ask 3** [GRANTED `command`] → `translate` folds into the one `claude-spt` binary (1 artifact/triple).
- **Ask 4** [operator-owned] → display name + RC channel become `{id}@{node}` if a `{node}` key lands; else `{id}` only.
- Shipped **without** any ask (DONE, on `main`): `gh_release` + `[update].message`, partial binary
  consolidation (digest/psyche/post-update), and the name unification (repo renamed `SaberMage/claude-spt`).
- **Trigger:** doyle ships **spt-core v0.16.0** → adapter **v0.8.0** cut wires Asks 1–3 + bumps `min_spt_core` → 0.16.0.
