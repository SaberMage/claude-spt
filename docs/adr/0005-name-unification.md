<!-- [doc->REQ-DIST-NAME-UNIFY] -->
# Name unification: `claude-spt` (spt-core side) + `spt` (Claude Code side)

## Status

accepted (2026-06-24); repo rename executed 2026-06-25 (U3 — `SaberMage/spt-claude-code` →
`SaberMage/claude-spt` via `gh repo rename`; all owner-qualified refs flipped).

## Context

The project carried **three** names for one thing, plus a launcher shortcut:

| Identifier | Value | Where it shows |
|---|---|---|
| GitHub repo | `spt-claude-code` | `spt adapter add --release SaberMage/spt-claude-code`, `[update].repo`, install dir derivation |
| spt-core adapter | `claude-spt` | every `api --adapter claude-spt`, `[adapter].name`, `spt adapter update claude-spt` |
| cplugs plugin | `sptc` | `/sptc:*` skill prefix, `claude plugin … sptc@cplugs`, marketplace path |
| launcher shortcut | `cc` | `cc-<id>` (`spt endpoint run` brand) |

Three names for one adapter is friction — a user reads `--release SaberMage/spt-claude-code` to install but `spt adapter update claude-spt` to update, and `/sptc:*` to invoke. The hard constraint that prevents collapsing to **one** token: the adapter **cannot** be named `spt` (that is spt-core's own CLI/identity — `spt adapter update spt` reads as "spt updates spt"), yet the user-facing skill prefix **wants** `/spt:*` (the legacy-parity goal, already planned as the `sptc`→`spt` succession). The skill prefix and the adapter id genuinely want different tokens.

## Decision

Collapse three names to **two**, by domain:

- **spt-core-facing identity = `claude-spt`** — the **repo** (rename `spt-claude-code` → `claude-spt`), the **adapter** (unchanged), and the **consolidated binary** (see ADR-0006). After the rename, install and update both read `claude-spt`: `spt adapter add --release SaberMage/claude-spt` ↔ `spt adapter update claude-spt`.
- **Claude-Code-facing identity = `spt`** — the **plugin** and its **skills** (`/spt:*`), reached via the already-planned `sptc`→`spt` succession (a single `s/sptc/spt/` substitution), gated on retiring legacy owl's cplugs `spt` plugin (two plugins cannot share the name). Until owl retires, the plugin stays `sptc` / `/sptc:*`.
- **launcher shortcut stays `cc`** (`cc-<id>`) — decoupled from the plugin name, unchanged (per ADR-0001).

End state: `claude-spt` everywhere spt-core sees it; `spt` everywhere the Claude Code user types a skill; `cc` for the spawned-endpoint launcher.

## Considered and rejected

- **One token everywhere = `claude-spt`** (incl. `/claude-spt:*` skills). Maximally consistent and dependency-free, but makes the most-typed surface (the skill prefix) long. Rejected — the skill prefix should head to `/spt:*`.
- **One token everywhere = `sptc`** (`/sptc:*` unchanged). Shortest and dependency-free, but `sptc` is cryptic to a newcomer and abandons the cleaner `/spt:*` succession the project already committed to. Rejected.

## Consequences

- **The repo rename changes the adapter install dir** (`adapters/_github/SaberMage-spt-claude-code` → `…SaberMage-claude-spt`, derived from the repo path), so existing `--release` installs must be re-added. Acceptable: one end user today. GitHub redirects old links; `[update].repo`, the README install chains, CI, and the package scripts must be updated in the same move.
- Two names is the floor, not a failure to unify — it reflects a real constraint (adapter ≠ `spt`), recorded here so a future reader does not "simplify" the adapter to `spt` and collide with spt-core.
- The `spt` plugin succession keeps its existing gate (owl retirement); this ADR does not change that timing, only commits the target token split.
