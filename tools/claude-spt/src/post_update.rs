//! `claude-spt post-update` — reconcile the cplugs plugin after `spt adapter update` (NEW, ADR-0006).
//!
//! `spt adapter update` pulls the adapter `.spt` (manifest + binaries + strings — the high-churn
//! surface) but it CANNOT touch the cplugs plugin (the thin skeleton: hooks.json + skill stubs +
//! plugin.json), which lives in Claude Code's marketplace registry. This subcommand closes that gap:
//! detect the host CLI (`claude`, or `ccs` — a drop-in), ensure the `cplugs` marketplace is
//! registered, then install/update the plugin. It then PRINTS a notice — it CANNOT run
//! `/reload-plugins` (a TUI-only action), so the manual residual is the user's `/reload-plugins`.
//!
//! WIRING STATUS: standalone-runnable + unit-tested NOW, but `[update]` cannot invoke it until doyle
//! ask #2 (composite `[update]` with a delegated post-step) lands — see ADR-0006 + UPDATE-NAMING-
//! DOYLE-ASKS.md ask 2 (D2). Until then it is run by hand / by /sptc:setup. `--dry-run` prints the
//! intended actions without spawning the CLI (the deterministic surface a future int asserts on).
//! [impl->REQ-DIST-BINARY-CONSOLIDATE]

use std::path::PathBuf;
use std::process::{Command, ExitCode, Stdio};

const MARKETPLACE: &str = "cplugs";
const MARKETPLACE_REPO: &str = "SaberMage/cplugs";
/// Plugin reference Claude Code keys by: `<plugin.json name>@<marketplace>`. This milestone the
/// plugin stays `sptc` (the `sptc`→`spt` succession is D4, owl-gated) so the ref is `sptc@cplugs`.
const PLUGIN_REF: &str = "sptc@cplugs";

/// Pick the CLI to drive. Prefer real `claude`; fall back to `ccs` (a documented drop-in for the
/// `claude` binary, same argv). Pure so the PATH probe stays at the edge and routing is testable.
fn choose_cli(has_claude: bool, has_ccs: bool) -> Option<&'static str> {
    if has_claude {
        Some("claude")
    } else if has_ccs {
        Some("ccs")
    } else {
        None
    }
}

/// `<cli> plugin marketplace add SaberMage/cplugs` — register the marketplace (run only when absent).
fn marketplace_add_cmd() -> Vec<String> {
    ["plugin", "marketplace", "add", MARKETPLACE_REPO]
        .iter()
        .map(|s| (*s).to_string())
        .collect()
}

/// `<cli> plugin (install|update) sptc@cplugs` — `update` when already installed, else `install`.
fn plugin_sync_cmd(installed: bool) -> Vec<String> {
    let verb = if installed { "update" } else { "install" };
    ["plugin", verb, PLUGIN_REF]
        .iter()
        .map(|s| (*s).to_string())
        .collect()
}

/// Is `MARKETPLACE` registered? Parses `known_marketplaces.json` — a top-level object keyed by
/// marketplace name, each with `source.repo`. True if the `cplugs` key exists OR any entry's repo is
/// `SaberMage/cplugs` (robust to a differently-named registration of the same repo). Pure over the
/// file contents (read at the edge). Malformed/empty -> false (caller registers it).
fn marketplace_registered_in(json: &str) -> bool {
    let v: serde_json::Value = match serde_json::from_str(json) {
        Ok(v) => v,
        Err(_) => return false,
    };
    let obj = match v.as_object() {
        Some(o) => o,
        None => return false,
    };
    if obj.contains_key(MARKETPLACE) {
        return true;
    }
    obj.values().any(|entry| {
        entry
            .get("source")
            .and_then(|s| s.get("repo"))
            .and_then(|r| r.as_str())
            == Some(MARKETPLACE_REPO)
    })
}

/// Is the plugin already installed? Parses `installed_plugins.json` — `{ plugins: { "<ref>": [...] } }`
/// — and checks for the `sptc@cplugs` key. Pure over the file contents. Malformed/empty/absent ->
/// false (caller installs rather than updates).
fn plugin_installed_in(json: &str) -> bool {
    serde_json::from_str::<serde_json::Value>(json)
        .ok()
        .and_then(|v| {
            v.get("plugins")
                .and_then(|p| p.as_object())
                .map(|p| p.contains_key(PLUGIN_REF))
        })
        .unwrap_or(false)
}

/// Executable names to probe on PATH for `name`. Windows resolves `claude`/`ccs` via PATHEXT
/// (`.exe`/`.cmd`/`.bat`); POSIX uses the bare name. Pure so PATH resolution is testable.
fn program_candidates(name: &str) -> Vec<String> {
    if cfg!(windows) {
        ["", ".exe", ".cmd", ".bat"]
            .iter()
            .map(|ext| format!("{name}{ext}"))
            .collect()
    } else {
        vec![name.to_string()]
    }
}

/// The post-update notice. It states what was reconciled and the ONE manual residual
/// (`/reload-plugins`) — it deliberately does NOT run that itself (TUI-only). Kept aligned with the
/// manifest `[update].message` copy (REQ-DIST-UPDATE-MESSAGE) so both levers say the same thing.
fn notice() -> &'static str {
    "claude-spt: plugin reconciled. Run /reload-plugins in Claude Code (or restart it) to load the refreshed skills/hooks."
}

/// Claude Code's config root: `$CLAUDE_CONFIG_DIR` (set by `ccs` per-account) else `~/.claude`.
fn claude_config_dir() -> Option<PathBuf> {
    if let Some(cfg) = std::env::var_os("CLAUDE_CONFIG_DIR") {
        if !cfg.is_empty() {
            return Some(PathBuf::from(cfg));
        }
    }
    std::env::var_os("HOME")
        .or_else(|| std::env::var_os("USERPROFILE"))
        .map(|home| PathBuf::from(home).join(".claude"))
}

/// True if `name` (or a PATHEXT variant) resolves to a file on any PATH dir.
fn which(name: &str) -> bool {
    let path = match std::env::var_os("PATH") {
        Some(p) => p,
        None => return false,
    };
    let cands = program_candidates(name);
    std::env::split_paths(&path).any(|dir| cands.iter().any(|c| dir.join(c).is_file()))
}

/// `claude-spt post-update` entry. Reads its own argv (binary name + `post-update` token consumed).
pub fn run() -> ExitCode {
    let dry_run = std::env::args()
        .skip(2)
        .any(|a| a == "--dry-run" || a == "-n");

    let cli = match choose_cli(which("claude"), which("ccs")) {
        Some(c) => c,
        None => {
            eprintln!("claude-spt post-update: no `claude` or `ccs` CLI on PATH — cannot reconcile the plugin");
            return ExitCode::from(3);
        }
    };

    let plugins_dir = claude_config_dir().map(|d| d.join("plugins"));
    let read = |name: &str| -> String {
        plugins_dir
            .as_ref()
            .and_then(|d| std::fs::read_to_string(d.join(name)).ok())
            .unwrap_or_default()
    };
    let registered = marketplace_registered_in(&read("known_marketplaces.json"));
    let installed = plugin_installed_in(&read("installed_plugins.json"));

    let mut steps: Vec<Vec<String>> = Vec::new();
    if !registered {
        steps.push(marketplace_add_cmd());
    }
    steps.push(plugin_sync_cmd(installed));

    for argv in &steps {
        let shown = format!("{cli} {}", argv.join(" "));
        if dry_run {
            println!("would run: {shown}");
            continue;
        }
        eprintln!("claude-spt post-update: {shown}");
        let status = Command::new(cli).args(argv).stdin(Stdio::null()).status();
        match status {
            Ok(s) if s.success() => {}
            Ok(s) => {
                eprintln!("claude-spt post-update: `{shown}` exited {s}");
                return ExitCode::from(1);
            }
            Err(e) => {
                eprintln!("claude-spt post-update: failed to spawn `{shown}`: {e}");
                return ExitCode::from(1);
            }
        }
    }

    println!("{}", notice());
    ExitCode::SUCCESS
}

// [unit->REQ-DIST-BINARY-CONSOLIDATE]
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cli_prefers_claude_then_ccs_then_none() {
        assert_eq!(choose_cli(true, true), Some("claude"));
        assert_eq!(choose_cli(true, false), Some("claude"));
        assert_eq!(choose_cli(false, true), Some("ccs")); // ccs is a documented claude drop-in
        assert_eq!(choose_cli(false, false), None);
    }

    #[test]
    fn marketplace_add_targets_the_cplugs_repo() {
        assert_eq!(
            marketplace_add_cmd(),
            vec!["plugin", "marketplace", "add", "SaberMage/cplugs"]
        );
    }

    #[test]
    fn plugin_sync_picks_update_when_installed_else_install() {
        assert_eq!(plugin_sync_cmd(false), vec!["plugin", "install", "sptc@cplugs"]);
        assert_eq!(plugin_sync_cmd(true), vec!["plugin", "update", "sptc@cplugs"]);
    }

    #[test]
    fn marketplace_registered_detects_by_key() {
        let json = r#"{"cplugs":{"source":{"source":"github","repo":"SaberMage/cplugs"}}}"#;
        assert!(marketplace_registered_in(json));
    }

    #[test]
    fn marketplace_registered_detects_by_repo_under_other_name() {
        // Same repo registered under a different marketplace name must still count.
        let json = r#"{"my-fork":{"source":{"source":"github","repo":"SaberMage/cplugs"}}}"#;
        assert!(marketplace_registered_in(json));
    }

    #[test]
    fn marketplace_registered_false_when_absent_or_malformed() {
        assert!(!marketplace_registered_in(
            r#"{"other":{"source":{"source":"github","repo":"a/b"}}}"#
        ));
        assert!(!marketplace_registered_in("not json"));
        assert!(!marketplace_registered_in(""));
    }

    #[test]
    fn plugin_installed_detects_the_ref_key() {
        let json = r#"{"version":2,"plugins":{"sptc@cplugs":[{"scope":"user"}]}}"#;
        assert!(plugin_installed_in(json));
    }

    #[test]
    fn plugin_installed_false_for_legacy_or_absent() {
        // The legacy owl plugin is `spt@cplugs`, NOT `sptc@cplugs` — must not be mistaken for ours.
        assert!(!plugin_installed_in(
            r#"{"version":2,"plugins":{"spt@cplugs":[{"scope":"user"}]}}"#
        ));
        assert!(!plugin_installed_in(r#"{"version":2,"plugins":{}}"#));
        assert!(!plugin_installed_in("not json"));
    }

    #[test]
    fn program_candidates_cover_windows_pathext() {
        let c = program_candidates("claude");
        assert!(c.contains(&"claude".to_string()));
        if cfg!(windows) {
            assert!(c.contains(&"claude.exe".to_string()));
            assert!(c.contains(&"claude.cmd".to_string()));
        } else {
            assert_eq!(c, vec!["claude".to_string()]);
        }
    }

    #[test]
    fn notice_names_reload_plugins_but_does_not_claim_to_run_it() {
        let n = notice();
        assert!(n.contains("/reload-plugins"), "notice must point at the manual residual");
        // The notice tells the user to run it — the subcommand never runs the TUI action itself.
        assert!(n.contains("Run /reload-plugins"));
    }
}
