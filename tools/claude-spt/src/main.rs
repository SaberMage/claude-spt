//! claude-spt — consolidated tool binary for the claude-spt adapter (ADR-0006, U2).
//!
//! ONE binary, one set of subcommands (was three crates → fewer artifacts per triple in adapter.spt):
//!   claude-spt digest      — the [digest] extractor (was claude-spt-digest)
//!   claude-spt psyche      — the [session.psyche_init] Psyche runner (was claude-spt-psyche)
//!   claude-spt post-update — reconcile the cplugs plugin after `spt adapter update` (ADR-0006)
//!   claude-spt translate   — the [message-idle-translation-binary] idle filter (was cc-spt-idle-translate)
//!   claude-spt hook <ev>   — the CC hook handler (D1: hook logic moved off the plugin shell so it
//!                            rides `spt adapter update`; was the eight plugin hook .sh wrappers)
//!   claude-spt launch      — the [session.self]/[session.resume] CC spawn shim (node-named
//!                            sessions: -n "<id> @ <node>" + --remote-control <id>--<node>)
//!
//! Dispatch is a bare `argv[1]` match (no clap — keep the dependency-light ethos the predecessor
//! crates were built on). Each subcommand owns its remaining argv via `std::env::args().skip(2)`
//! (skip the binary name + the subcommand token) and its own hand-written flag parser. `translate`
//! reads no argv (pure stdin/stdout protocol).
//!
//! `translate` folded in at the v0.8.0 cut once spt-core v0.16.0 gave `[message-idle-translation-
//! binary]` a `command` field (D3) — so claude-spt is now the SINGLE tool binary (one artifact per
//! triple in adapter.spt). [impl->REQ-DIST-BINARY-CONSOLIDATE] [impl->REQ-DIST-IDLE-TRANSLATE]

mod digest;
mod hook;
mod launch;
mod post_update;
mod psyche;
mod translate;

use std::process::ExitCode;

/// The resolved subcommand. Pure classification of `argv[1]` so dispatch routing is unit-testable
/// without spawning the binary. [impl->REQ-DIST-BINARY-CONSOLIDATE]
#[derive(Debug, PartialEq)]
enum Sub {
    Digest,
    Psyche,
    PostUpdate,
    Translate,
    Hook,
    Launch,
    Help,
    Unknown(String),
}

fn classify(sub: Option<&str>) -> Sub {
    match sub {
        Some("digest") => Sub::Digest,
        Some("psyche") => Sub::Psyche,
        Some("post-update") => Sub::PostUpdate,
        Some("translate") => Sub::Translate,
        Some("hook") => Sub::Hook,
        Some("launch") => Sub::Launch,
        None | Some("-h") | Some("--help") => Sub::Help,
        Some(other) => Sub::Unknown(other.to_string()),
    }
}

fn usage() {
    eprintln!(
        "claude-spt <subcommand> [args]\n\
         \n\
         subcommands:\n\
         \x20 digest       map a Claude Code JSONL transcript to digest NDJSON ([digest] extractor)\n\
         \x20 psyche       run the LiveAgent Psyche companion ([session.psyche_init] runner)\n\
         \x20 post-update  reconcile the cplugs plugin after `spt adapter update`\n\
         \x20 translate    idle-message translation filter (stdin->stdout JSON lines)\n\
         \x20 hook <event> handle a Claude Code hook event (stdin = the CC hook payload)\n\
         \x20 launch       spawn the CC session with node-named display/RC ([session.self]/[session.resume])"
    );
}

fn main() -> ExitCode {
    let sub = std::env::args().nth(1);
    match classify(sub.as_deref()) {
        Sub::Digest => digest::run(),
        Sub::Psyche => psyche::run(),
        Sub::PostUpdate => post_update::run(),
        Sub::Translate => translate::run(),
        Sub::Hook => hook::run(),
        Sub::Launch => launch::run(),
        Sub::Help => {
            usage();
            ExitCode::SUCCESS
        }
        Sub::Unknown(other) => {
            // DEGRADE, NEVER BRICK (REQ-HAZARD-HOOKCMD-DISPATCH-LOCKSTEP). A stale plugin
            // dispatch.sh (old 0.1.8 shape) execs `claude-spt <CCEvent>` WITHOUT the `hook` token —
            // e.g. `claude-spt UserPromptSubmit`. Exiting nonzero here made CC treat every hook as a
            // blocking failure (all tools blocked + a looping Stop hook) with zero self-repair. So
            // when the unknown subcommand is actually a CC hook event, route it through as a hook
            // (the perch keeps working) and emit a NON-blocking stderr note about the skew. A genuine
            // typo (not a hook event) still exits loud so real misinvocations are not masked.
            if hook::is_cc_hook_event(&other) {
                eprintln!(
                    "claude-spt: received CC hook event '{other}' as a bare subcommand — the sptc \
                     plugin dispatch is stale (dropped the `hook` token). Handling it anyway; run \
                     /reload-plugins to refresh the plugin. [REQ-HAZARD-HOOKCMD-DISPATCH-LOCKSTEP]"
                );
                hook::run_event(&other)
            } else {
                eprintln!("claude-spt: unknown subcommand: {other}");
                usage();
                ExitCode::from(2)
            }
        }
    }
}

// [unit->REQ-DIST-BINARY-CONSOLIDATE]
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn classifies_each_real_subcommand() {
        assert_eq!(classify(Some("digest")), Sub::Digest);
        assert_eq!(classify(Some("psyche")), Sub::Psyche);
        assert_eq!(classify(Some("post-update")), Sub::PostUpdate);
        assert_eq!(classify(Some("translate")), Sub::Translate);
        assert_eq!(classify(Some("hook")), Sub::Hook);
        assert_eq!(classify(Some("launch")), Sub::Launch);
    }

    #[test]
    fn no_subcommand_and_help_flags_are_help() {
        assert_eq!(classify(None), Sub::Help);
        assert_eq!(classify(Some("-h")), Sub::Help);
        assert_eq!(classify(Some("--help")), Sub::Help);
    }

    #[test]
    fn unrecognized_subcommand_is_unknown_not_misrouted() {
        // A typo must NOT silently fall through to a real subcommand (it exits 2 in main).
        assert_eq!(classify(Some("digset")), Sub::Unknown("digset".into()));
    }

    // [unit->REQ-HAZARD-HOOKCMD-DISPATCH-LOCKSTEP]
    #[test]
    fn stale_dispatch_cc_event_degrades_typo_stays_loud() {
        // The stale-dispatch signature: `claude-spt <CCEvent>` (the `hook` token dropped) classifies
        // as Unknown, but main routes it through hook::run_event (exit 0, pass-through) BECAUSE the
        // token is a CC hook event. A genuine typo is NOT a hook event → stays the loud exit-2 path.
        for ev in hook::CC_HOOK_EVENTS {
            assert_eq!(classify(Some(ev)), Sub::Unknown((*ev).to_string()));
            assert!(hook::is_cc_hook_event(ev), "{ev} must be recognised as a CC hook event");
        }
        assert!(!hook::is_cc_hook_event("digset")); // typo → loud exit-2 branch, not degrade
        assert!(!hook::is_cc_hook_event("digest")); // a real subcommand is never a hook event
    }
}
