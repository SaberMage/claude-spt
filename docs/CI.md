# CI model — agent-driven, autonomous, no-LLM-in-the-loop

> spt-claude-code's CI is **wholly agent-driven and autonomous** on the existing Windows +
> Linux fleet (hfenduleam + kitsubito). **GitHub-hosted runners are NOT used** — a stock
> hosted runner physically can't run Claude Code (auth + interactivity), so only a real
> harness on the fleet reaches the acceptance bar. **Deterministic gates** run by a fleet
> runner-agent, triggered by a git post-push hook, reporting over **spt messaging**. No LLM
> sits in the gate path — the gates are plain scripts; the "agent" is just the autonomous
> runner that fires them and reports.

## The gates (deterministic)
<!-- [doc->REQ-CI-GATES] -->
<!-- [doc->REQ-CI-OWL-DISCOVERY] -->
<!-- [doc->REQ-CI-MANUAL] -->
<!-- [doc->REQ-CI-TRIGGER] -->
<!-- [doc->REQ-CI-BUS] -->
<!-- [doc->REQ-CI-ACCEPTANCE] -->

Every gate is a script with a binary pass / fail — no judgment, no model:

1. **Build** — the project assembles clean.
2. **Unit tests** — the suite passes.
3. **`traceable-reqs check`** — requirement coverage gate; exit-1 fails the build (see
   `docs/TRACEABILITY.md`).
4. **Manifest-schema** — the CC adapter manifest validates against spt-core's **published**
   `manifest.schema.json` (from `SaberMage/spt-releases`).
5. **Docs-drift** — generated docs (API reference, `llms.txt`, schema, CLI help) are regenerated
   and must match what's checked in; a diff fails (see `docs/DOCS-STRATEGY.md`).

## Acceptance (the system-under-test is a real `claude` session)

Acceptance is **scripted orchestration that spawns real `claude` / headless sessions as the
system-under-test**, then asserts spt-state / `[digest]` output. The **LLM is the SUT, never
the runner** — the orchestration is deterministic; only the thing it drives is a real harness.
This is what a stock hosted runner can't do, and why the fleet is mandatory. (spt-core's
GH-runner justification — heavy multi-platform Rust + signed releases + two-host net — does
not carry here: the adapter binary is thin glue and delegates releases/signing to `spt`.)

## Reporting bus = spt messaging (dogfood)

The reporting bus is **legacy spt** (`$OWL send`): the runner reports gate/acceptance results
over spt messaging to the responsible agent / channel. This dogfoods the product as its own CI
nervous system.

## Trigger: git post-push hook → ping a runner-agent over spt

The trigger is **push-driven, not polling** (polling adds latency and wastes cycles):

1. A **git post-push hook** fires after a push.
2. The hook **`$OWL send`s a one-line "run gates for `<ref>`" message** to a fleet runner-agent
   over spt messaging.
3. The runner-agent **runs the deterministic gates** (and acceptance) on the fleet.
4. The runner **reports the result back over spt** to the responsible agent / channel.

### Discovering the `$OWL send` (spt messaging) binary robustly

The bus binary's path **changes between versions** — legacy spt lives in a per-version
`~/.claude/` or `~/.ccs/` plugins folder whose path moves each release. No further
legacy-spt changes are anticipated, but the hook and runner **must locate it robustly**:
resolve it at run time (search the known plugins/install roots / a configured path / `PATH`)
rather than hard-coding a versioned location. A stale hard-coded path is the most likely cause
of a silently dead trigger.

## Manual fallback

A **manual "run gates" command** must always exist — the same gate scripts, runnable by hand on
any fleet host. Use it when the hook didn't fire, when reproducing a failure, or before a hook is
wired at all.

## Hosted-runner workflow (not used here)

A hosted CI workflow (e.g. GitHub Actions) is **explicitly dropped** for this project: it can't
run the real-harness acceptance bar. `docs/TRACEABILITY.md` carries a ready GitHub Actions
snippet for the pure-deterministic `traceable-reqs check` gate if a hosted fallback is ever
wanted, but the agent-driven fleet pattern is the primary and intended path.
