Live-agent upkeep — commune across resets, sign off cleanly (you `spt whoami` for your `<id>`):

- **Commune** after a significant body of work, before a `/clear` or `/compact`: write
  `.claude/<id>-commune.md` in ONE atomic write — a concise context DELTA (current task + status,
  decisions since last commune, immediate next steps), NOT a transcript. spt's daemon ingests it into
  your tracked mind and deletes the file; the file disappearing is the success signal. This is what
  rebuilds you after a reset, so make it complete. (Live agents only — a ready agent has no Psyche.)
- **Checkpoint** = a commune that ALSO wipes + rebuilds your context from that commune (the
  agent-driven `/clear`, no operator). Embed the literal `!!checkpoint!!` trigger in the commune body:
  one marker ⇒ default wake (`Proceed with next steps`); a PAIR of markers ⇒ the text between them is
  your custom wake directive, e.g. `!!checkpoint!! Resume T2c: wire the branch. !!checkpoint!!`. Author
  it INLINE this turn (you are the pre-clear author). The idle-mark, self-send, and clear+wake fire
  automatically once the file lands. spt-hosted live sessions only.
- **Sign off** gracefully when done: `spt endpoint shutdown` (your own perch) — stops the listener,
  fires the final context save, and takes your Psyche down with it. `/sptc:ready` or `/sptc:live`
  brings you back. Lighter no-save stop: `spt endpoint stop`.
