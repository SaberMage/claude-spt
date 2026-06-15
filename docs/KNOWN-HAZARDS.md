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
