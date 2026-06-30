# v0.9.1 bug sweep — live tracking doc

> Six bugs reported against claude-spt v0.9.0 / cplugs sptc 0.1.8. /diagnose discipline.
> Status legend: 🔴 open · 🔬 root-caused · 🛠 fixed · ✅ verified.

## Shared root cause suspect: SessionStart env-file cache writes a value with a SPACE

`dispatch.sh` caches `SPTC_HOOK_BIN=<dir>/claude-spt hook` (a space before `hook`) into
`$CLAUDE_ENV_FILE`. CC sources that file per Bash invocation → bash parses
`SPTC_HOOK_BIN=/path/claude-spt hook` as **"set SPTC_HOOK_BIN=/path/claude-spt, then run command
`hook`"** → `hook: command not found` (seen in images #2 & #4) AND the cached var loses the `hook`
token. Per-prompt hooks then `exec $SPTC_HOOK_BIN <Event>` = `claude-spt <Event>` (NO `hook`
subcommand) → unknown subcommand → no-op. This breaks the per-prompt drain → explains **#3 noise, #4,
#5** in one stroke. First SessionStart works (resolves fresh via get-string); everything after is broken.

---

## Bug 1 — adapter update doesn't refresh the marketplace 🔴
`spt adapter update claude-spt` → post-step `claude plugin install sptc@cplugs` fails:
`Plugin "sptc" not found in marketplace "cplugs" ... try claude plugin marketplace update cplugs`.
**Hypothesis:** post_update.rs installs without first refreshing the stale local marketplace cache.
**Fix:** run `claude plugin marketplace update cplugs` before `claude plugin install sptc@cplugs`.

## Bug 2 — update message wording 🔴
now: `✔ Plugin "sptc" updated from 0.1.3 to 0.1.8 for scope user. Restart to apply changes.`
want: `✔ Claude Code plugin "sptc" updated from 0.1.3 to 0.1.8. Active sessions need to run the /reload-plugins command.`
**Hypothesis:** that line is `claude plugin install`'s own stdout (CC), not ours → suppress it +
print our own wording from post_update.rs.

## Bug 3 — agents look up their ID instead of knowing it from SessionStart additionalContext 🔴
image #2: agent runs `spt whoami` to find its id; output polluted by `hook: command not found`.
**Hypothesis:** (a) the env-file space bug noise; (b) identity brief not emphatic that the agent
already knows its id and need not run `spt whoami`.

## Bug 4 — agent thinks it must arm a Monitor to get messages (1 of 2 runs) 🔴
image #3: agent arms a Monitor to watch for a reply, though its perch delivers automatically.
**Hypothesis:** (a) per-prompt drain broken by the env-file bug → replies don't arrive → agent
compensates; (b) messaging brief doesn't say "replies arrive on your perch automatically; never
arm a Monitor/poll".

## Bug 5 — PreToolUse hook broken (plugin 0.1.8) 🔴
image #4: `hook: command not found` + behaviour off.
**Hypothesis:** the env-file space bug → PreToolUse execs `claude-spt PreToolUse` (no `hook`
subcommand) → no-op/error. Fixed by the shared root-cause fix.

## Bug 6 — ccs profile missing recent manifest changes (name + rc settings) 🔴
`[profiles.ccs.session.self].command = "ccs --dangerously-skip-permissions"` leaf-replaces the base
`session.self` command, DROPPING the U6 `-n {id} --remote-control {id}` flags base now carries.
**Fix:** ccs override = `ccs -n {id} --remote-control {id} --dangerously-skip-permissions` (+ keys).

---

## Resolution log

**Shared root cause (env-file space) — 🔬 CONFIRMED + 🛠 fixed.** Reproduced exactly: sourcing
`SPTC_HOOK_BIN=/path/claude-spt hook` → `line 3: hook: command not found` (matches images #2/#4) and
`SPTC_HOOK_BIN` ends up EMPTY (`VAR=val cmd` scoping). Fix: manifest `hook_cmd` = bare binary path (no
` hook`); `dispatch.sh` caches it QUOTED + strips a legacy ` hook` suffix + execs `"$bin" hook <event>`.
Verified end-to-end: clean source, correct value, space-safe, per-prompt hook runs clean. → fixes #5,
the #3 noise, and the delivery half of #4.

- **#1 marketplace refresh — 🛠 ✅.** `post_update.rs`: on the already-registered path, run
  `claude plugin marketplace update cplugs` BEFORE `plugin install/update`. Dry-run confirms the new
  step order. Unit: `marketplace_update_refreshes_the_cplugs_cache`.
- **#2 update message — 🛠 ✅.** `post_update.rs` now CAPTURES the subprocess output (no leak onto the
  `[update.post]` arbiter stdout — that leak was making CC's line the "custom message"), parses the
  version transition, and prints the reworded `✔ Claude Code plugin "sptc" updated from X to Y. Active
  sessions need to run the /reload-plugins command.` to stderr; stdout stays the clean sentinel. Unit:
  `parse_version_transition_*`, `reworded_notice_*`.
- **#3 ID lookup — 🛠.** (a) env-file noise gone; (b) prose: `identity.md` now states `Your id is {id}
  … do NOT run spt whoami`; `live.md`/`live-ops.md` stop instructing `spt whoami`.
- **#4 redundant Monitor — 🛠.** prose: `identity.md` + `messaging-perch.md` + `live.md` now say replies
  arrive AUTOMATICALLY on the existing perch/relay — never arm a second Monitor/poll.
- **#5 PreToolUse broken — 🛠 ✅.** = the shared env-file fix (PreToolUse was exec'ing without the `hook`
  subcommand / drowning in the noise). Per-prompt hook verified clean via the cached var.
- **#6 ccs profile — 🛠 ✅.** manifest: `[profiles.ccs.session.self]` = `ccs -n {id} --remote-control
  {id} --dangerously-skip-permissions` + new `[profiles.ccs.session.resume]`; keys redeclared. Unit:
  manifest-shortcut.sh ccs -n/RC assertions.

**Gate:** all default gates PASS (91 crate tests). **SHIPPED v0.9.1** (adapter release + `adapter.spt`,
asset-verified: bare hook_cmd + ccs -n/RC self+resume) + cplugs **0.1.9**. main @ 252763d, tag v0.9.1.

## Post-mortem — what would have prevented the shared root cause
The v0.9.0 `tests/hooks-dispatch.sh` only grepped that dispatch *mentions* `SPTC_HOOK_BIN` — it never
SOURCED a cached line the way CC actually does, so a value-with-a-space sailed through every gate.
Closed by a regression at the real seam (`tests/hooks-dispatch.sh`): emulate the cached env line, source
it in-shell, and assert the v0.9.0 unquoted form breaks (`hook: command not found`) while the v0.9.1
quoted form sources clean + preserves the value (space-safe). No architectural change needed — a
test-coverage gap (assert-on-structure, not on-behaviour), now covered on-behaviour.


