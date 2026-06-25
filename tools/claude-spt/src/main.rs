//! claude-spt — consolidated tool binary for the claude-spt adapter (ADR-0006, U2).
//!
//! ONE binary, three subcommands (was three crates → fewer artifacts per triple in adapter.spt):
//!   claude-spt digest      — the [digest] extractor (was claude-spt-digest)
//!   claude-spt psyche      — the [session.psyche_init] Psyche runner (was claude-spt-psyche)
//!   claude-spt post-update — reconcile the cplugs plugin after `spt adapter update` (NEW, ADR-0006)
//!
//! Dispatch is a bare `argv[1]` match (no clap — keep the dependency-light ethos both predecessor
//! crates were built on). Each subcommand owns its remaining argv via `std::env::args().skip(2)`
//! (skip the binary name + the subcommand token) and its own hand-written flag parser.
//!
//! `cc-spt-idle-translate` stays a SEPARATE binary this milestone — it folds into a `claude-spt
//! translate` subcommand only once doyle ask #3 lets `[message-idle-translation-binary]` take a
//! command/subcommand rather than a bare `path` (D3). [impl->REQ-DIST-BINARY-CONSOLIDATE]

mod digest;
mod post_update;
mod psyche;

use std::process::ExitCode;

/// The resolved subcommand. Pure classification of `argv[1]` so dispatch routing is unit-testable
/// without spawning the binary. [impl->REQ-DIST-BINARY-CONSOLIDATE]
#[derive(Debug, PartialEq)]
enum Sub {
    Digest,
    Psyche,
    PostUpdate,
    Help,
    Unknown(String),
}

fn classify(sub: Option<&str>) -> Sub {
    match sub {
        Some("digest") => Sub::Digest,
        Some("psyche") => Sub::Psyche,
        Some("post-update") => Sub::PostUpdate,
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
         \x20 post-update  reconcile the cplugs plugin after `spt adapter update`"
    );
}

fn main() -> ExitCode {
    let sub = std::env::args().nth(1);
    match classify(sub.as_deref()) {
        Sub::Digest => digest::run(),
        Sub::Psyche => psyche::run(),
        Sub::PostUpdate => post_update::run(),
        Sub::Help => {
            usage();
            ExitCode::SUCCESS
        }
        Sub::Unknown(other) => {
            eprintln!("claude-spt: unknown subcommand: {other}");
            usage();
            ExitCode::from(2)
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
}
