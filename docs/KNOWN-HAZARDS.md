# Known Hazards

> A **conformance checklist, not advice.** Each hazard below is a first-class
> `REQ-HAZARD-*` requirement in `traceable-reqs.toml`, and is **not "covered" until a test tags
> it** (`unit`, plus `int` where the failure is cross-process / cross-node). This file exists to
> make "we won't re-break X" mechanical: an entry without a passing tagged test is an open risk,
> and `traceable-reqs check` will say so once the hazard is activated.

A hazard earns a place here when it is an invariant you have *paid for once* (a real bug, an
incident) or one you have *committed never to introduce*. State it so a test can prove it.

## Entry format

Each entry is one numbered subsection with these fields:

- **Failure** — the concrete bad behavior: what goes wrong, under what sequence / timing / input.
- **Invariant** — the property that MUST hold, phrased so a test can assert it (the thing the
  `REQ-HAZARD-*` requires).
- **Mapping / notes** — where this lives in *this* project, and anything that changes the shape
  of the test (e.g. "in-process now, so use a lock instead of racing on disk").
- **cite** — where the failure / fix is evidenced (an incident, a prior commit, a source path);
  reference only — the binding evidence is the tagged test.

Mirror each entry as a requirement:

```toml
[[requirements]]
id = "REQ-HAZARD-EXAMPLE"
title = "The invariant, stated so a test can prove it"
required_stages = []   # activate (["unit"] or ["unit","int"]) when you cover it
```

---

## 1. Windows / MSYS shell environment

### 1.1 MSYS `/`-prefix path conversion mangles slash-leading arguments

- **Failure:** On Windows under Git-Bash / MSYS, any **command-line argument** beginning with `/`
  is silently rewritten to an absolute Windows path before the target binary sees it. Observed
  2026-06-15 during the UPS-fires validation: invoking `claude -p "/send hi"` from Git-Bash
  delivered the prompt to Claude Code as `C:/Program Files/Git/send hi` — the `/send` token was
  path-converted. Anything that passes a `/sptc:…` (or other `/`-leading) token as a **positional
  argument** through a Git-Bash layer is corrupted the same way. (Legacy `claude_skill_owl`
  documents the identical hazard in `new-alarm`.)
- **Invariant:** sptc adapter glue MUST NOT depend on receiving `/`-leading content as a
  Git-Bash positional argument. Message/prompt content is read from the **hook stdin JSON**
  (`prompt`, message bodies), never reconstructed from a `/`-prefixed argv; any helper that must
  take such an argument uses a stdin/`--message-file` transport or `MSYS_NO_PATHCONV=1`.
- **Mapping / notes:** the hook wrappers (`plugin/sptc/hooks/*.sh`) are immune by construction —
  they parse the CC hook payload from stdin (`json_str`), not from argv. The invariant is the
  *commitment* to keep it that way (and to apply it to any future `/sptc:*` arg-taking surface).
  A test asserts the stdin path is honored (no argv `/`-token dependency).
- **cite:** UPS-fires validation 2026-06-15 (`ups.log`, run A); legacy `new-alarm` SKILL.md
  MSYS note. Reference only — binding evidence is the tagged test under `REQ-HAZARD-MSYS-PATHCONV`.

---

## 2. Live-agent perch / CI orchestration

### 2.1 Nested-`claude` perch collision tears down the live agent's poll stream

<!-- [doc->REQ-HAZARD-PERCH-COLLISION] -->

- **Failure:** The CI acceptance harness spawns a real `claude` session as the system-under-test.
  If that nested session loads the spt plugin (whose SessionStart establishes a perch) and resolves
  the **same perch id as the live operator agent** (e.g. `perri`), the nested establish **displaces
  the operator's perch** — perches are name-keyed, last-establish-wins — killing the operator's
  `api poll` / live stream. Observed 2026-06-15 as the live poll Monitor exiting `exit-1` plus a
  `sessions log seal failed: git failed` on revive (the collision teardown). Diagnosed by the
  operator as self-inflicted, NOT a legacy-substrate bug.
- **Invariant:** Every nested SUT the acceptance harness spawns MUST run under a **disposable
  identity** distinct from any live agent — `SPT_AGENT_ID=sptc-ci-<n>` (and the matching
  `OWL_SESSION_ID`), never a live agent name. The harness MUST set this for every spawn; it MUST
  NOT inherit the operator's `SPT_AGENT_ID`/`OWL_SESSION_ID`. A test asserts the harness always
  overrides both to a `sptc-ci-` id and never emits a live id.
- **Mapping / notes:** `ci/acceptance/lib.sh` `sptc_ci_identity` mints the disposable id and
  exports it into the SUT env; `ci/acceptance/run-acceptance.sh` spawns `claude -p` only through
  that env. The deterministic guard lives in `tests/acceptance-harness.sh` (no real `claude`
  needed — it asserts the env the harness would hand a spawn). Identity is the documented
  name-keyed knob (`spt whoami` resolves from `$OWL_SESSION_ID`/`$SPT_AGENT_ID`); a separate data
  dir is not part of the public surface, so isolation rides on identity.
- **cite:** Operator diagnosis 2026-06-15 (perch collision, self-inflicted via nested `claude -p`
  loading the spt plugin). Reference only — binding evidence is the tagged test under
  `REQ-HAZARD-PERCH-COLLISION`.
