# One-command-ish update + a single consolidated adapter binary

## Status

accepted (2026-06-24) — extends ADR-0001 (distribution splits by volatility). Some pieces depend on spt-core capabilities not yet shipped (the "doyle asks" below); those parts are decided in shape but gated on delivery.

## Context

ADR-0001 split distribution into a low-churn **cplugs skeleton** (hooks, skill skeletons, `plugin.json`, bootstrap — updated by `claude plugin update`) and an spt-conducted **adapter** (manifest + binaries + strings — updated by `spt adapter update`). The operator wants the whole thing kept current with effectively **one lever**, and wants install and update to feel **harmonious** (no hunting for the update command after install) and to work from the **CLI** (not only inside an endpoint session).

Two facts bound the design:

1. **Hook *logic* must live in the CC plugin dir** (CC loads hooks from there), outside `spt adapter update`'s reach. So "one command updates everything" is unreachable purely inside this repo — it needs spt-core capabilities → findings, not workarounds (public-surface-only).
2. **Raw skills/commands can't reliably replace the plugin.** Reopened and re-rejected: user-scope skills are flat (no namespace), and CC slash-command subdirectory namespacing is broken ([anthropics/claude-code#2422] — subdirs show in the description but don't namespace the invocation). The plugin is the only reliable `/spt:*` + the only clean hooks bundle. The eloquent thing to borrow from suite installers (e.g. gsd-core) is their **installer/onboarding UX**, not going raw.

## Decision

**Keep the plugin** (reaffirms ADR-0001). Make the update path one-lever-shaped and consolidate the adapter's binaries.

### Update mechanics

- **`avenue = "gh_release"`** pulls the adapter `.spt` (manifest + binaries + strings — all the high-churn). Ships against the published surface today.
- **`[update].message`** carries the residual manual step. This is a real, docs-confirmed field: a markdown-rendered notice `spt adapter update` prints to stdout **only when a new version is actually applied** (never on a no-op), no `{key}` substitution. It tells the user to run **`/reload-plugins`** — which is a **Claude Code TUI action and cannot be automated** — and mentions the `spt` CLI (alias for `spt endpoint run`) as the more powerful way to create an endpoint, alongside `/spt:live`.
- **"Install is the first update"** is docs-confirmed, so `spt adapter add` conducts the same `[update]` flow — one acquisition bootstraps the adapter.
- **Symmetric levers:** install = `spt adapter add --release SaberMage/claude-spt`, update = `spt adapter update claude-spt` (the verbs mirror). A README **copy-paste agent prompt** is an optional skin over the install command (the casual-user onboarding), with **platform-specific chains** (cmd / PowerShell / bash) that check-for / install spt-core (claude-spt may be a user's first exposure to spt-core) then `adapter add`.

### Binary consolidation

Collapse the adapter's executables into **one `claude-spt <subcommand>`** binary (name per ADR-0005), **partially now, fully later**:

- **Now** (no spt-core dependency — these seams take a command string): `claude-spt digest` (`[digest].extractor`), `claude-spt psyche` (`[session.psyche_init]`), `claude-spt post-update` (the delegated update step). Drops the fat `.spt` from 3 binaries/triple toward 1, dedupes deps, and retires the odd-one-out `cc-spt-idle-translate` name.
- **Later** (gated on doyle ask #3): fold in `claude-spt translate` once `[message-idle-translation-binary]` accepts a command/subcommand rather than a bare `path`; and `claude-spt hook <event>` if generic hook dispatch (ask #1) lands.

The **post-update step is cross-platform** because it is a compiled subcommand of this binary, **not** a `.sh` (Windows has no bash; a stray script would also stress spt-core's archive handling). It runs `claude plugin add|update <plugin>` + prints the notice; it cannot run `/reload-plugins` (TUI).

### The spt-core asks (findings to doyle — decided in shape, gated on delivery)

1. **Generic hook dispatch** — `spt api run-hook <adapter> <event>`: spt-core executes the adapter's handler for a hook event (from the manifest), so the plugin's `hooks.json` can pre-wire all events to one generic stub and hook *logic* rides `spt adapter update`. Eliminates the plugin-channel churn that adding this wave's PostToolUse hook forced.
2. **Composite `[update]`** — `gh_release` (pull the `.spt`) **plus** a delegated post-step in the same `spt adapter update`, so the plugin update is automated (the only manual residual becomes `/reload-plugins`). Two sub-requirements: the post-step must run **unconditionally** (the plugin can change when the adapter version did not), and its return value must be able to flag **"changed"** so `spt adapter update` still prints `[update].message` even on an adapter no-op.
3. **Translation seam takes a command** — `[message-idle-translation-binary]` accept a command/subcommand (or a default-on-no-args convention) instead of a bare `path`, so `translate` can fold into the consolidated binary.

## Consequences

- The thin-skeleton goal advances even before the asks land: skill bodies already ride strings; the **reactive skills** (`commune`/`send`/`signoff`, full-fat in the plugin because they are invoked without a typed slash-command) can be thinned to stubs by moving their bodies into the perched SessionStart brief (adapter strings) plus the `/spt:live` UPS body — with a known **delivery-timing wrinkle** (the perched brief fires on bind|boundary, not the instant a seed session goes live), tracked as a plan item, not blocking.
- Until asks #1/#3 land, hook logic and the translate binary stay on their current channels; the design degrades gracefully (the `message` field bridges the manual steps).
- One artifact per OS simplifies packaging but couples all seams' build/release — acceptable, they already ship in one `.spt`.
