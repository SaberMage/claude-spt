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

## 1. `<Category — e.g. Race conditions & ordering>`

### 1.1 `<Short hazard name>` — PLACEHOLDER (replace with a real hazard)

- **Failure:** `<the concrete bad behavior and the exact sequence that triggers it>`.
- **Invariant:** `<the property that must hold, phrased for a test>`.
- **Mapping / notes:** `<where this lives in this project; what changes the test's shape>`.
- **cite:** `<incident / commit / source path — reference only>`.
