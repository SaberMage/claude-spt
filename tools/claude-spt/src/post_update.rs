//! `claude-spt post-update` — reconcile the cplugs plugin after `spt adapter update` (NEW, ADR-0006).
//!
//! `spt adapter update` pulls the adapter `.spt` (manifest + binaries + strings — the high-churn
//! surface) but it CANNOT touch the cplugs plugin (the thin skeleton: hooks.json + skill stubs +
//! plugin.json), which lives in Claude Code's marketplace registry. This subcommand closes that gap:
//! detect the host CLI (`claude`, or `ccs` — a drop-in), ensure the `cplugs` marketplace is
//! registered, then install/update the plugin. It then PRINTS a notice — it CANNOT run
//! `/reload-plugins` (a TUI-only action), so the manual residual is the user's `/reload-plugins`.
//!
//! WIRED (spt-core v0.16.0, D2): the manifest `[update.post] = {command = "{adapter_dir}/claude-spt
//! post-update", self_verifies = false}` runs this AFTER the `gh_release` pull, UNCONDITIONALLY.
//! spt-core pipes ONE JSON line on stdin — `{adapter_applied, adapter_name, profile_name, version,
//! previous_version, adapter_dir}` (additive; we ignore unknown keys) — and reads our STDOUT to
//! arbitrate the update notice: custom text SUPERSEDES `[update].message`; the reserved sentinel
//! `!!update-message!!` (alone) FIRES the static `[update].message`; empty = nothing. Exit code is
//! orthogonal (the pull is never rolled back on our failure — fail-isolated). `self_verifies` is
//! attestation-only (gates nothing yet).
//!
//! We use the SENTINEL strategy: on a successful real reconcile we print `!!update-message!!` so the
//! single user-facing copy lives once in `[update].message` (the /reload-plugins + go-live notice,
//! REQ-DIST-UPDATE-MESSAGE). Diagnostics go to STDERR (never stdout — stdout is the arbiter channel).
//!
//! THREE invocation modes:
//!   * `[update.post]` (stdin is a piped JSON line) — reconcile, then stdout = sentinel on success / empty.
//!   * standalone by hand / `/sptc:setup` (stdin is a TTY) — reconcile, then print the human notice to stdout.
//!   * `--dry-run` / `-n` — print the intended actions (no spawn); the deterministic surface the int asserts.
//! [impl->REQ-DIST-BINARY-CONSOLIDATE] [impl->REQ-DIST-UPDATE-MESSAGE]

use std::io::{IsTerminal, Read};
use std::path::PathBuf;
use std::process::{Command, ExitCode, Stdio};

/// Reserved stdout sentinel: printing it (alone) tells spt-core to fire the static `[update].message`.
const UPDATE_MESSAGE_SENTINEL: &str = "!!update-message!!";

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

/// `<cli> plugin marketplace update cplugs` — REFRESH the local marketplace cache before install.
/// Without this, an ALREADY-registered-but-stale `cplugs` cache makes `plugin install sptc@cplugs`
/// fail with "Plugin sptc not found in marketplace cplugs ... try claude plugin marketplace update
/// cplugs" (the v0.9.0 bug). Run when the marketplace is already registered (a fresh `add` already
/// fetches). [impl->REQ-DIST-UPDATE-MESSAGE]
fn marketplace_update_cmd() -> Vec<String> {
    ["plugin", "marketplace", "update", MARKETPLACE]
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

/// Parse a `from <old> to <new>` version transition out of Claude Code's `plugin update` stdout
/// (e.g. `Plugin "sptc" updated from 0.1.3 to 0.1.8 for scope user.`). None when CC's wording does
/// not carry one (a fresh install, or a future CC reformat). Pure. [impl->REQ-DIST-UPDATE-MESSAGE]
fn parse_version_transition(cc_output: &str) -> Option<(String, String)> {
    // Scan for the literal " from <tok> to <tok>" without a regex dep.
    let i = cc_output.find(" from ")?;
    let rest = &cc_output[i + " from ".len()..];
    let to = rest.find(" to ")?;
    let old = rest[..to].trim();
    let after = &rest[to + " to ".len()..];
    // <new> is the next whitespace-delimited token (version dots are part of it), minus any trailing
    // sentence punctuation (e.g. `0.1.8 for scope user.` or `0.1.8.`).
    let new: &str = after
        .split_whitespace()
        .next()
        .unwrap_or("")
        .trim_end_matches(['.', ',']);
    if old.is_empty() || new.is_empty() {
        return None;
    }
    Some((old.to_string(), new.to_string()))
}

/// The reworded plugin-sync notice (REQ-DIST-UPDATE-MESSAGE). Names Claude Code explicitly and the
/// exact manual residual (`/reload-plugins`) — avoiding CC's "Restart to apply changes" wording.
/// Carries the version transition when CC reported one. Pure. [impl->REQ-DIST-UPDATE-MESSAGE]
fn reworded_notice(transition: Option<(&str, &str)>) -> String {
    match transition {
        Some((old, new)) => format!(
            "✔ Claude Code plugin \"sptc\" updated from {old} to {new}. Active sessions need to run the /reload-plugins command."
        ),
        None => "✔ Claude Code plugin \"sptc\" reconciled. Active sessions need to run the /reload-plugins command.".to_string(),
    }
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

/// Parse the [update.post] stdin JSON line (ADDITIVE — ignore unknown keys, per doyle). Returns the
/// `adapter_applied` flag (whether the adapter version was applied this run); false on absent/bad
/// JSON. Pure so the stdin read stays at the edge. [impl->REQ-DIST-UPDATE-MESSAGE]
fn update_applied_in(json: &str) -> bool {
    serde_json::from_str::<serde_json::Value>(json)
        .ok()
        .and_then(|v| v.get("adapter_applied").and_then(|b| b.as_bool()))
        .unwrap_or(false)
}

/// The stdout ARBITER line for the [update.post] channel: the reserved sentinel (→ spt-core fires the
/// static `[update].message`) when the reconcile ran OR the adapter was applied, else empty (nothing).
/// We fire on any successful real reconcile so the one-lever `spt adapter update` always surfaces the
/// /reload-plugins reminder (the user-facing copy lives once in `[update].message`). Pure.
/// [impl->REQ-DIST-UPDATE-MESSAGE]
fn arbiter_line(reconciled: bool, adapter_applied: bool) -> &'static str {
    if reconciled || adapter_applied {
        UPDATE_MESSAGE_SENTINEL
    } else {
        ""
    }
}

/// `claude-spt post-update` entry. Reads its own argv (binary name + `post-update` token consumed).
pub fn run() -> ExitCode {
    let dry_run = std::env::args()
        .skip(2)
        .any(|a| a == "--dry-run" || a == "-n");

    // [update.post] mode iff stdin is a piped JSON line (spt-core pipes one line then closes); a TTY
    // stdin = standalone-by-hand. --dry-run forces the standalone-diagnostic path regardless.
    let post_mode = !dry_run && !std::io::stdin().is_terminal();
    let mut adapter_applied = false;
    if post_mode {
        let mut buf = String::new();
        let _ = std::io::stdin().read_to_string(&mut buf);
        adapter_applied = update_applied_in(buf.trim());
    }

    let cli = match choose_cli(which("claude"), which("ccs")) {
        Some(c) => c,
        None => {
            // fail-isolated: spt-core never rolls back the pull on our exit code. stderr, not stdout.
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
    } else {
        // Registered-but-possibly-STALE cache: refresh it so `plugin install` sees the latest sptc.
        // (The v0.9.0 bug: install failed "Plugin sptc not found in marketplace cplugs" on a stale
        // cache because this step was missing.) A fresh `add` above already fetches, so this only
        // runs on the already-registered path.
        steps.push(marketplace_update_cmd());
    }
    steps.push(plugin_sync_cmd(installed));
    let sync_idx = steps.len() - 1; // the last step is always the plugin install/update.

    for (i, argv) in steps.iter().enumerate() {
        let shown = format!("{cli} {}", argv.join(" "));
        if dry_run {
            println!("would run: {shown}"); // diagnostic preview to stdout (no spt-core arbiter present)
            continue;
        }
        // Diagnostics → STDERR: stdout is the [update.post] arbiter channel (sentinel/custom/empty).
        eprintln!("claude-spt post-update: {shown}");
        // CAPTURE the subprocess output — it must NOT inherit our stdout. In [update.post] mode our
        // stdout is the arbiter channel; CC's verbose `plugin update` line leaking there would be read
        // by spt-core as a CUSTOM update message (superseding [update].message) — the v0.9.0 wording bug.
        let output = match Command::new(cli).args(argv).stdin(Stdio::null()).output() {
            Ok(o) => o,
            Err(e) => {
                eprintln!("claude-spt post-update: failed to spawn `{shown}`: {e}");
                return ExitCode::from(1);
            }
        };
        let so = String::from_utf8_lossy(&output.stdout);
        let se = String::from_utf8_lossy(&output.stderr);
        if !output.status.success() {
            // Surface CC's own diagnostics on STDERR (spt-core displays post-step stderr), fail-isolated.
            if !so.trim().is_empty() {
                eprintln!("{}", so.trim_end());
            }
            if !se.trim().is_empty() {
                eprintln!("{}", se.trim_end());
            }
            eprintln!("claude-spt post-update: `{shown}` exited {}", output.status);
            return ExitCode::from(1); // stdout stays empty so no notice fires
        }
        if i == sync_idx {
            // Reword CC's "Plugin sptc updated from X to Y for scope user. Restart to apply changes."
            // → name Claude Code + the exact /reload-plugins residual, carrying the version transition.
            let transition = parse_version_transition(&so);
            let line = reworded_notice(transition.as_ref().map(|(o, n)| (o.as_str(), n.as_str())));
            if post_mode {
                eprintln!("{line}"); // stderr (shown by spt-core); stdout stays clean for the arbiter
            } else {
                println!("{line}"); // standalone-by-hand: no arbiter, show it directly
            }
        } else if !so.trim().is_empty() {
            eprintln!("{}", so.trim_end()); // marketplace step output → stderr, never the arbiter
        }
    }

    if dry_run {
        return ExitCode::SUCCESS; // diagnostics already printed; no arbiter output
    }
    if post_mode {
        // spt-core reads stdout to arbitrate: the sentinel (ALONE) fires the static [update].message.
        print!("{}", arbiter_line(true, adapter_applied));
    }
    // (standalone-by-hand already printed the reworded sync notice above.)
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

    // [unit->REQ-DIST-UPDATE-MESSAGE] the v0.9.1 stale-marketplace fix.
    #[test]
    fn marketplace_update_refreshes_the_cplugs_cache() {
        assert_eq!(
            marketplace_update_cmd(),
            vec!["plugin", "marketplace", "update", "cplugs"]
        );
    }

    // [unit->REQ-DIST-UPDATE-MESSAGE] reworded notice + version parse.
    #[test]
    fn parse_version_transition_pulls_from_cc_update_line() {
        let line = "Plugin \"sptc\" updated from 0.1.3 to 0.1.8 for scope user. Restart to apply changes.";
        assert_eq!(
            parse_version_transition(line),
            Some(("0.1.3".to_string(), "0.1.8".to_string()))
        );
        // A fresh install (no "from X to Y") yields None.
        assert_eq!(parse_version_transition("Plugin \"sptc\" installed for scope user."), None);
        assert_eq!(parse_version_transition(""), None);
    }

    #[test]
    fn reworded_notice_names_claude_code_and_reload_plugins() {
        let n = reworded_notice(Some(("0.1.3", "0.1.8")));
        assert_eq!(
            n,
            "✔ Claude Code plugin \"sptc\" updated from 0.1.3 to 0.1.8. Active sessions need to run the /reload-plugins command."
        );
        // Drops CC's "Restart to apply changes" wording; never present.
        assert!(!n.contains("Restart to apply"));
        // Fallback (no transition) still names /reload-plugins.
        assert!(reworded_notice(None).contains("/reload-plugins"));
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

    // [unit->REQ-DIST-UPDATE-MESSAGE] the [update.post] stdin/stdout contract (D2).
    #[test]
    fn update_context_reads_adapter_applied_additively() {
        // Additive: unknown future keys ignored; only adapter_applied read.
        assert!(update_applied_in(
            r#"{"adapter_applied":true,"adapter_name":"claude-spt","version":"0.8.0","unknown_future_key":42}"#
        ));
        assert!(!update_applied_in(r#"{"adapter_applied":false,"adapter_dir":"/x"}"#));
        assert!(!update_applied_in(r#"{"adapter_name":"claude-spt"}"#)); // key absent -> false
        assert!(!update_applied_in("not json"));
        assert!(!update_applied_in(""));
    }

    #[test]
    fn arbiter_fires_sentinel_on_reconcile_or_applied_else_empty() {
        assert_eq!(arbiter_line(true, false), "!!update-message!!"); // reconcile ran
        assert_eq!(arbiter_line(false, true), "!!update-message!!"); // adapter applied
        assert_eq!(arbiter_line(true, true), "!!update-message!!");
        assert_eq!(arbiter_line(false, false), ""); // true no-op -> nothing
    }
}
