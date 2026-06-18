//! claude-spt-psyche — the `[session.psyche_init]` Psyche runner for the claude-spt LiveAgent.
//!
//! WHAT A PSYCHE IS (doyle 2026-06-15, traced spt-core): a LiveAgent's detached companion. The
//! spt-core daemon's livehost hosts it — only when the resolved manifest declares
//! `[session.psyche_init]` AND the perch came up as state=live_agent (the live `api listen` path;
//! Option A 2026-06-17 — psyche_init lives in the BASE claude-spt manifest, no `:live` profile; a
//! ready/poll perch is skipped regardless, livehost.rs:282). The Psyche owns its OWN perch
//! (`<parent>-psyche`), receives daemon PULSES
//! on that perch, and on each pulse authors a COMMUNE delta (a context brief for the parent's
//! resume across `/clear`/compact) — it NEVER replies/notifies (the echo-commune is a distinct,
//! cheaper actor). It exits at session end. The Psyche is daemon-MANAGED by contract (decoupled
//! from message delivery); this runner does NOT orchestrate its own lifecycle — it is the dumb
//! resident wrapper the daemon launches and the daemon tears down (perch close = our exit signal).
//!
//! WHY A RESIDENT WRAPPER (not bare `claude -p`): `claude -p` is ONE-SHOT (one turn, then exits;
//! Stop hooks cannot re-loop it), and CC is migrating off `-p` billing-wise. So the Psyche-as-an-
//! LLM is a headless `claude` session in `{psyche_dir}` that we KEEP ALIVE: seed it once with the
//! daemon-supplied `{psyche_prompt}` (which tells that claude its Psyche role + the commune-on-pulse
//! contract), then drive one `claude --continue` turn per pulse. The COMMUNE authoring lives in
//! that claude (driven by the prompt) — this runner stays pure orchestration glue.
//!
//! Invoked by the daemon (detached, cwd=`{psyche_dir}`, stdio null):
//!   claude-spt-psyche --id <parent>-psyche --session-id <session_id> --prompt <psyche_prompt…>
//! ({id} is the daemon-OVERRIDDEN `<parent>-psyche`, NOT the parent endpoint id — see spawn_psyche.)
//! NOTE on `--prompt` parsing: spt-core **<0.8.2** substituted `{psyche_prompt}` into the command
//! STRING then whitespace-split it, so the multi-word prompt reached us as many trailing argv tokens.
//! spt-core **0.8.2+** fills each `{key}` as exactly ONE argv element (tokenize-then-fill — re-validated
//! 2026-06-17: the prompt arrives as a single element, newlines intact). We parse `--prompt` GREEDILY
//! (slurp the rest) anyway — defensive: it reconstructs a split prompt on <0.8.2 AND passes the single
//! 0.8.2 element through unchanged. Keep `--prompt` LAST in the command template. [impl->REQ-SKILL-LIVE]
//!
//! Loop:  seed `claude -p <prompt>`  ->  forever { `spt ready <id> --once` (blocks for one pulse;
//! its stdout is the pulse body) ; perch-closed => exit ; empty drain => next ; else feed the pulse
//! to `claude --continue -p <pulse>` }. The perch register + backlog drain are the `spt ready`
//! command's own job (ready.md), so no separate establish step.
//! [impl->REQ-SKILL-LIVE]

#[cfg(not(test))]
use std::process::{Command, ExitCode, Stdio};

/// Parsed launch args. Only the three daemon-filled `psyche_init.keys` we template
/// (`{id, session_id, psyche_prompt}`; `{psyche_dir}` is consumed as cwd by the daemon, not argv).
#[derive(Debug, PartialEq)]
struct Args {
    id: String,
    session_id: String,
    prompt: String,
}

impl Args {
    /// Parse `--id V --session-id V --prompt <rest…>`. `--id`/`--session-id` are single-value and
    /// order-independent; `--prompt` is TERMINAL and GREEDY — it slurps every remaining token as the
    /// prompt (rejoined with single spaces). History: spt-core **<0.8.2** substituted `{psyche_prompt}`
    /// into the `[session.psyche_init]` command STRING then whitespace-split it, so a multi-word prompt
    /// (it always is — "PSYCHE REVIVAL time: … incoming event: …") arrived as many tokens, NOT one; a
    /// non-greedy `--prompt` read only the first word and rejected the second as "unknown arg" → instant
    /// exit 2 → the daemon recorded a phantom hosted Psyche (diagnosed v0.8.1, 2026-06-16). spt-core
    /// **0.8.2** fixed it (fills each `{key}` as ONE argv element; re-validated 2026-06-17). Greedy is
    /// KEPT as defensive: with one element, `collect().join(" ")` returns it unchanged; with the old
    /// split, it reconstructs. Our manifest places `--prompt` last. Returns the offending flag on a
    /// missing value or an unknown arg seen BEFORE `--prompt`, so a real misfire is still loud.
    fn parse<I: IntoIterator<Item = String>>(argv: I) -> Result<Args, String> {
        let (mut id, mut session_id, mut prompt) = (None, None, None);
        let mut it = argv.into_iter();
        while let Some(flag) = it.next() {
            let want = |it: &mut dyn Iterator<Item = String>| {
                it.next().ok_or_else(|| format!("{flag} expects a value"))
            };
            match flag.as_str() {
                "--id" => id = Some(want(&mut it)?),
                "--session-id" => session_id = Some(want(&mut it)?),
                // Terminal + greedy: consume ALL remaining tokens (spt-core whitespace-split the prompt).
                "--prompt" => {
                    prompt = Some(it.by_ref().collect::<Vec<_>>().join(" "));
                }
                other => return Err(format!("unknown arg: {other}")),
            }
        }
        Ok(Args {
            id: id.ok_or("missing --id")?,
            session_id: session_id.ok_or("missing --session-id")?,
            prompt: prompt.ok_or("missing --prompt")?,
        })
    }
}

/// Tool/permission SANDBOX flags applied to EVERY psyche claude turn (seed + each pulse) — legacy
/// owl parity (claude_skill_owl `src/live/wrapper/claude.rs`, init/resume/final all carry this exact
/// set). The Psyche is a CONSTRAINED companion, not a general agent:
///   * `--tools Read,Edit,Write` — the commune authoring needs file IO only; NO Bash/network/etc.
///     (legacy ALSO scopes an `--agents owl-psyche` subagent to the same three; the session-level
///     `--tools` cap is the effective gate, and our role-prompt arrives via `-p`, not an embedded
///     `--agents` template, so we apply the cap directly rather than recreating the subagent).
///   * `--disable-slash-commands` — the Psyche drives itself from the prompt; no slash surface.
///   * `--dangerously-skip-permissions` — REQUIRED, not cosmetic: the daemon spawns this runner
///     DETACHED with `Stdio::null` (see run()), so an interactive permission prompt would have no
///     operator/stdin to approve it and would HANG the turn. Auto-approve within the Read/Edit/Write
///     sandbox is the safe combination (bounded surface + no deadlock).
///   * model pin (`sonnet` primary, `opus` fallback, `medium` effort) — mirrors legacy so the cheap
///     companion does not silently ride the parent's heavier model.
/// [impl->REQ-SKILL-LIVE]
fn sandbox_flags() -> Vec<String> {
    [
        "--model",
        "sonnet",
        "--fallback-model",
        "opus",
        "--effort",
        "medium",
        "--dangerously-skip-permissions",
        "--disable-slash-commands",
        "--tools",
        "Read,Edit,Write",
    ]
    .iter()
    .map(|s| (*s).to_string())
    .collect()
}

/// argv for the one-shot SEED turn: establishes the Psyche's headless `claude` session in the cwd
/// (`{psyche_dir}`) from the daemon-supplied psyche prompt. `-p` is the headless/print mode; the
/// sandbox flags (see [`sandbox_flags`]) constrain it to the legacy Read/Edit/Write companion box.
fn seed_cmd(prompt: &str) -> Vec<String> {
    let mut v = vec!["-p".into(), prompt.into()];
    v.extend(sandbox_flags());
    v
}

/// argv for a per-PULSE turn: resume the seeded session (`--continue` picks the most-recent session
/// in the cwd) and feed the pulse body as the turn's prompt. The seeded role-prompt makes that
/// claude author a commune delta for this pulse. Carries the SAME sandbox flags as the seed so the
/// constraint holds for every turn, not just the first (legacy applies them to resume too).
fn pulse_cmd(pulse: &str) -> Vec<String> {
    let mut v = vec!["--continue".into(), "-p".into(), pulse.into()];
    v.extend(sandbox_flags());
    v
}

/// argv for one perch poll: `spt ready <id> --once` registers the perch (first call), drains the
/// spooled backlog, blocks for exactly one delivery, then exits — re-run to stay reachable
/// (ready.md). Non-zero exit = perch gone (session end) = our cue to stop.
fn poll_cmd(id: &str) -> Vec<String> {
    vec!["ready".into(), id.into(), "--once".into()]
}

/// A pulse body is actionable only if non-blank: `spt ready` may print just its `READY:<id>` online
/// signal (on stderr) or an empty drain, which must NOT trigger a (billed) claude turn.
fn is_actionable(pulse: &str) -> bool {
    !pulse.trim().is_empty()
}

#[cfg(not(test))]
fn run() -> ExitCode {
    let args = match Args::parse(std::env::args().skip(1)) {
        Ok(a) => a,
        Err(e) => {
            eprintln!("claude-spt-psyche: {e}");
            return ExitCode::from(2);
        }
    };

    // Seed the resident Psyche claude session (best-effort: if claude is absent the daemon's perch
    // poll still defines our lifetime; we don't abort the runner over one failed turn).
    let _ = Command::new("claude")
        .args(seed_cmd(&args.prompt))
        .stdin(Stdio::null())
        .status();

    // Resident pulse loop. The perch IS the lifecycle: when the daemon tears the LiveAgent down at
    // session end the perch closes, `spt ready --once` exits non-zero, and we return.
    loop {
        let out = match Command::new("spt").args(poll_cmd(&args.id)).output() {
            Ok(o) => o,
            Err(_) => return ExitCode::SUCCESS, // spt vanished — nothing left to serve
        };
        if !out.status.success() {
            return ExitCode::SUCCESS; // perch gone => session ended
        }
        let pulse = String::from_utf8_lossy(&out.stdout);
        if !is_actionable(&pulse) {
            continue; // online signal / empty drain — no turn
        }
        let _ = Command::new("claude")
            .args(pulse_cmd(&pulse))
            .stdin(Stdio::null())
            .status();
    }
}

#[cfg(not(test))]
fn main() -> ExitCode {
    run()
}

#[cfg(test)]
fn main() {}

// [unit->REQ-SKILL-LIVE]
#[cfg(test)]
mod tests {
    use super::*;

    fn argv(parts: &[&str]) -> Vec<String> {
        parts.iter().map(|s| s.to_string()).collect()
    }

    #[test]
    fn id_and_session_are_order_independent_prompt_is_terminal() {
        // --id/--session-id may precede --prompt in any order; --prompt is last and slurps the rest.
        let a = Args::parse(argv(&[
            "--session-id", "sess-9", "--id", "perri-psyche", "--prompt", "be the psyche",
        ]))
        .unwrap();
        assert_eq!(
            a,
            Args {
                id: "perri-psyche".into(),
                session_id: "sess-9".into(),
                prompt: "be the psyche".into(),
            }
        );
    }

    #[test]
    fn prompt_slurps_whitespace_split_tokens() {
        // spt-core whitespace-splits the substituted {psyche_prompt}; we must rejoin every trailing
        // token, not reject the second word as "unknown arg" (the v0.8.1 phantom-Psyche bug).
        let a = Args::parse(argv(&[
            "--id", "p-psyche", "--session-id", "s",
            "--prompt", "PSYCHE", "REVIVAL", "time:", "epoch-ms:123", "incoming", "event:", "(none)",
        ]))
        .unwrap();
        assert_eq!(a.id, "p-psyche");
        assert_eq!(a.session_id, "s");
        assert_eq!(a.prompt, "PSYCHE REVIVAL time: epoch-ms:123 incoming event: (none)");
    }

    #[test]
    fn missing_flag_is_an_error_not_a_default() {
        let e = Args::parse(argv(&["--id", "x", "--session-id", "s"])).unwrap_err();
        assert!(e.contains("--prompt"), "got: {e}");
    }

    #[test]
    fn unknown_arg_before_prompt_still_rejected() {
        // Greedy --prompt must not mask a genuine misfire earlier in argv.
        let e = Args::parse(argv(&["--id", "x", "--bogus", "v", "--prompt", "hi"])).unwrap_err();
        assert!(e.contains("unknown arg: --bogus"), "got: {e}");
    }

    #[test]
    fn flag_without_value_errors() {
        let e = Args::parse(argv(&["--id"])).unwrap_err();
        assert!(e.contains("--id expects a value"), "got: {e}");
    }

    #[test]
    fn unknown_arg_rejected() {
        let e = Args::parse(argv(&["--bogus", "v"])).unwrap_err();
        assert!(e.contains("unknown arg: --bogus"), "got: {e}");
    }

    #[test]
    fn seed_is_headless_print_of_the_prompt() {
        // -p <prompt> leads; sandbox flags follow.
        let c = seed_cmd("hello psyche");
        assert_eq!(&c[..2], &["-p", "hello psyche"]);
        assert_eq!(&c[2..], &sandbox_flags()[..]);
    }

    #[test]
    fn pulse_resumes_then_prints() {
        // --continue MUST precede -p so the turn resumes the seeded session rather than starting fresh.
        let c = pulse_cmd("commune now");
        assert_eq!(&c[..3], &["--continue", "-p", "commune now"]);
        assert_eq!(&c[3..], &sandbox_flags()[..]);
    }

    #[test]
    fn every_turn_is_sandboxed_to_legacy_owl_parity() {
        // The Psyche is a constrained companion (claude_skill_owl parity): Read/Edit/Write only,
        // slash-commands off, and skip-permissions because the daemon spawns it detached/null-stdin
        // (an interactive prompt would deadlock). Both seed AND pulse must carry the full set.
        for cmd in [seed_cmd("seed"), pulse_cmd("pulse")] {
            assert!(cmd.windows(2).any(|w| w == ["--tools", "Read,Edit,Write"]), "tools cap missing: {cmd:?}");
            assert!(cmd.iter().any(|a| a == "--disable-slash-commands"), "slash-commands not disabled: {cmd:?}");
            assert!(cmd.iter().any(|a| a == "--dangerously-skip-permissions"), "skip-permissions missing (detached spawn would hang): {cmd:?}");
            assert!(cmd.windows(2).any(|w| w == ["--model", "sonnet"]), "model not pinned: {cmd:?}");
        }
    }

    #[test]
    fn poll_is_ready_once_on_the_psyche_perch() {
        assert_eq!(
            poll_cmd("perri-psyche"),
            vec!["ready", "perri-psyche", "--once"]
        );
    }

    #[test]
    fn blank_pulses_do_not_trigger_a_turn() {
        assert!(!is_actionable(""));
        assert!(!is_actionable("   \n\t "));
        assert!(is_actionable("READY backlog: resume the build"));
    }
}
