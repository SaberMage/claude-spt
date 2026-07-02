//! `claude-spt launch` — the `[session.self]` / `[session.resume]` CC spawn shim (v0.10.3).
//!
//! WHY A SHIM: the operator wants spt-hosted endpoints named `<id> @ <node>` (display) so a fleet
//! of live agents is cross-node-distinguishable in the prompt box / `/resume` picker / terminal
//! title — the REQ-DIST-RC-STARTUP STRETCH (doyle ask #4). spt-core's published fill catalog
//! (harness-contract/manifest, v0.19.1) has NO `{node}` key, so the node name is not templatable
//! manifest-side; and tokenize-then-fill can never produce a space-carrying single argv element
//! anyway (`-n {id} @ {node}` would be three argv tokens). Both problems dissolve by routing the
//! spawn through this shim: it runs ON the node, computes the hostname itself, and passes each
//! name as one clean argv element. Same resolve-through-own-binary move as `hook`/`psyche`
//! (ADR-0006); the `{node}` fill-key gap stays a reported spt-core finding, not a blocker.
//!
//! Invoked by the spt-core daemon (broker PTY leader):
//!   claude-spt launch --id <id> [--cli claude|ccs] [--resume <session_id>]
//! and it spawns the real harness CLI:
//!   <cli> [-r <session_id>] -n "<id> @ <node>" --remote-control <id>--<node> --dangerously-skip-permissions
//!
//! NAME SHAPES: display = `<id> @ <node>` (spaces fine — one argv element). Remote Control =
//! `<id>--<node>`: RC session names are tokeny (CC's own auto-generated names use the hostname as
//! prefix, `--remote-control-session-name-prefix` default), and whether the RC backend accepts
//! spaces/`@` is not verifiable from the public surface — so the deterministic separator form is
//! used rather than risking a bringup-time reject. `spt rc <id>` is UNAFFECTED either way: it
//! attaches the broker-held PTY by ENDPOINT id (broker-internal), not by CC's RC name. A node
//! name we cannot determine degrades BOTH names to the bare `<id>` (the pre-0.10.3 shape) — never
//! a half-named endpoint, never a failed launch.
//!
//! PTY: on unix this process exec()s the CLI (process replacement — the harness IS the PTY leader,
//! zero interference). Windows has no exec: spawn with inherited stdio + wait + propagate the exit
//! code. CC runs its TUI in raw mode, so ConPTY passes ^C through as bytes (no CTRL_C_EVENT racing
//! the waiting shim in steady state). `ccs` on Windows is an npm `.cmd` shim — CreateProcess does
//! not resolve those from a bare name, so the CLI is PATH-resolved to an explicit
//! `.exe`/`.cmd`/`.bat` candidate first (std spawns an explicit `.cmd` via cmd.exe with safe
//! quoting). [impl->REQ-DIST-RC-STARTUP]

use std::path::PathBuf;
use std::process::{Command, ExitCode};

/// Parsed launch args: the daemon-filled keys we template (`{id}`, `{session_id}` on the resume
/// role) plus the profile-static `--cli` selector (base manifest omits it → `claude`; the ccs
/// profile overlay passes `--cli ccs`).
#[derive(Debug, PartialEq)]
struct Args {
    id: String,
    cli: String,
    resume: Option<String>,
}

impl Args {
    /// Parse `--id V [--cli V] [--resume V]` (order-independent, all single-value — nothing here is
    /// prompt-shaped, so no greedy tail like psyche's `--prompt`). Unknown args are loud: a manifest
    /// template drift must fail the bringup visibly, not launch a half-configured session.
    fn parse<I: IntoIterator<Item = String>>(argv: I) -> Result<Args, String> {
        let (mut id, mut cli, mut resume) = (None, None, None);
        let mut it = argv.into_iter();
        while let Some(flag) = it.next() {
            let want = |it: &mut dyn Iterator<Item = String>| {
                it.next().ok_or_else(|| format!("{flag} expects a value"))
            };
            match flag.as_str() {
                "--id" => id = Some(want(&mut it)?),
                "--cli" => cli = Some(want(&mut it)?),
                "--resume" => resume = Some(want(&mut it)?),
                other => return Err(format!("unknown arg: {other}")),
            }
        }
        Ok(Args {
            id: id.ok_or("missing --id")?,
            cli: cli.unwrap_or_else(|| "claude".to_string()),
            resume,
        })
    }
}

/// The node name for session naming: `COMPUTERNAME` (Windows) else `HOSTNAME` (often unset in
/// non-interactive POSIX shells) else the `hostname` command. None when nothing yields a
/// non-blank value — the caller degrades to bare-`{id}` names.
fn node_name() -> Option<String> {
    for var in ["COMPUTERNAME", "HOSTNAME"] {
        if let Ok(v) = std::env::var(var) {
            let v = v.trim();
            if !v.is_empty() {
                return Some(v.to_string());
            }
        }
    }
    let out = Command::new("hostname").output().ok()?;
    let v = String::from_utf8_lossy(&out.stdout).trim().to_string();
    (!v.is_empty()).then_some(v)
}

/// Display name (`-n`): `<id> @ <node>`, or bare `<id>` when the node is unknown. Pure.
fn display_name(id: &str, node: Option<&str>) -> String {
    match node {
        Some(n) => format!("{id} @ {n}"),
        None => id.to_string(),
    }
}

/// Remote Control name (`--remote-control`): `<id>--<node>`, or bare `<id>` when the node is
/// unknown. Separator form, not the spaced display name — see the module comment. Pure.
fn rc_name(id: &str, node: Option<&str>) -> String {
    match node {
        Some(n) => format!("{id}--{n}"),
        None => id.to_string(),
    }
}

/// The harness CLI argv (everything after the program): `[-r <session_id>]` first (mirrors the
/// pre-0.10.3 `[session.resume]` flag order), then the two names, then skip-permissions (REQUIRED
/// for the non-interactive broker PTY — REQ-HAZARD-PSYCHE-PERMS-DEADLOCK; no operator exists at
/// spawn time to approve a permission prompt). Pure so the full command shape is unit-testable.
/// [impl->REQ-DIST-RC-STARTUP]
fn cli_argv(args: &Args, node: Option<&str>) -> Vec<String> {
    let mut v = Vec::new();
    if let Some(sid) = &args.resume {
        v.push("-r".into());
        v.push(sid.clone());
    }
    v.push("-n".into());
    v.push(display_name(&args.id, node));
    v.push("--remote-control".into());
    v.push(rc_name(&args.id, node));
    v.push("--dangerously-skip-permissions".into());
    v
}

/// PATH-resolve `name` to a spawnable program. Windows probes `.exe`/`.cmd`/`.bat` per PATH dir
/// (bare `Command::new("ccs")` cannot spawn the npm `ccs.cmd` shim; an explicit `.cmd` path std
/// runs via cmd.exe with safe quoting); POSIX returns the bare name (execvp resolves it). Pure
/// over the supplied PATH string so resolution is unit-testable. Shared with `post-update` (its
/// `ccs plugin update` follow-up hits the same .cmd-shim wall).
pub(crate) fn resolve_program_from(name: &str, path: Option<&std::ffi::OsStr>) -> Option<PathBuf> {
    if !cfg!(windows) {
        return Some(PathBuf::from(name));
    }
    let path = path?;
    for dir in std::env::split_paths(path) {
        for ext in [".exe", ".cmd", ".bat"] {
            let cand = dir.join(format!("{name}{ext}"));
            if cand.is_file() {
                return Some(cand);
            }
        }
    }
    None
}

/// `claude-spt launch` entry. Reads its own argv (binary name + `launch` token already consumed).
pub fn run() -> ExitCode {
    let args = match Args::parse(std::env::args().skip(2)) {
        Ok(a) => a,
        Err(e) => {
            eprintln!("claude-spt launch: {e}");
            return ExitCode::from(2);
        }
    };
    let node = node_name();
    let argv = cli_argv(&args, node.as_deref());
    let path = std::env::var_os("PATH");
    let program = match resolve_program_from(&args.cli, path.as_deref()) {
        Some(p) => p,
        None => {
            eprintln!("claude-spt launch: `{}` not found on PATH", args.cli);
            return ExitCode::from(2);
        }
    };

    let mut cmd = Command::new(&program);
    cmd.args(&argv);

    #[cfg(unix)]
    {
        // exec() replaces this process — the harness becomes the PTY leader directly. Returning
        // at all means the exec failed.
        use std::os::unix::process::CommandExt;
        let err = cmd.exec();
        eprintln!("claude-spt launch: failed to exec `{}`: {err}", program.display());
        ExitCode::from(1)
    }
    #[cfg(not(unix))]
    {
        // No exec on Windows: run the harness as a child on the same console and propagate its
        // exit code (stdio inherited by default — the broker PTY reaches the harness untouched).
        match cmd.status() {
            Ok(st) => ExitCode::from(st.code().unwrap_or(1).clamp(0, 255) as u8),
            Err(e) => {
                eprintln!("claude-spt launch: failed to spawn `{}`: {e}", program.display());
                ExitCode::from(1)
            }
        }
    }
}

// [unit->REQ-DIST-RC-STARTUP]
#[cfg(test)]
mod tests {
    use super::*;

    fn args(v: &[&str]) -> Result<Args, String> {
        Args::parse(v.iter().map(|s| s.to_string()))
    }

    #[test]
    fn parses_id_only_defaults_to_claude_fresh() {
        assert_eq!(
            args(&["--id", "perri"]).unwrap(),
            Args { id: "perri".into(), cli: "claude".into(), resume: None }
        );
    }

    #[test]
    fn parses_ccs_resume_order_independent() {
        assert_eq!(
            args(&["--resume", "sid-1", "--cli", "ccs", "--id", "perri"]).unwrap(),
            Args { id: "perri".into(), cli: "ccs".into(), resume: Some("sid-1".into()) }
        );
    }

    #[test]
    fn missing_id_and_unknown_args_are_loud() {
        assert!(args(&["--cli", "ccs"]).unwrap_err().contains("missing --id"));
        assert!(args(&["--id", "x", "--nope"]).unwrap_err().contains("unknown arg"));
        assert!(args(&["--id"]).unwrap_err().contains("expects a value"));
    }

    #[test]
    fn names_carry_id_at_node_and_separator_rc() {
        // Display = "<id> @ <node>" (spaced, one argv element); RC = "<id>--<node>" (tokeny form).
        assert_eq!(display_name("perri", Some("HFENDULEAM")), "perri @ HFENDULEAM");
        assert_eq!(rc_name("perri", Some("HFENDULEAM")), "perri--HFENDULEAM");
    }

    #[test]
    fn unknown_node_degrades_both_names_to_bare_id() {
        // The pre-0.10.3 shape — never a half-named endpoint, never a failed launch.
        assert_eq!(display_name("perri", None), "perri");
        assert_eq!(rc_name("perri", None), "perri");
    }

    #[test]
    fn fresh_argv_has_names_then_skip_perms() {
        let a = args(&["--id", "perri"]).unwrap();
        assert_eq!(
            cli_argv(&a, Some("HFENDULEAM")),
            vec![
                "-n",
                "perri @ HFENDULEAM",
                "--remote-control",
                "perri--HFENDULEAM",
                "--dangerously-skip-permissions",
            ]
        );
    }

    #[test]
    fn resume_argv_leads_with_native_resume_verb() {
        // -r {session_id} FIRST (pre-0.10.3 [session.resume] flag order), then the U6 name flags.
        let a = args(&["--id", "perri", "--resume", "sid-1"]).unwrap();
        assert_eq!(
            cli_argv(&a, Some("N1")),
            vec![
                "-r",
                "sid-1",
                "-n",
                "perri @ N1",
                "--remote-control",
                "perri--N1",
                "--dangerously-skip-permissions",
            ]
        );
    }

    #[cfg(windows)]
    #[test]
    fn windows_resolution_finds_cmd_shims_and_misses_are_none() {
        // An npm `ccs.cmd` shim must resolve to its explicit path (bare names can't spawn .cmd).
        let dir = std::env::temp_dir().join("claude-spt-launch-test-path");
        std::fs::create_dir_all(&dir).unwrap();
        std::fs::write(dir.join("fakecli.cmd"), "@echo off\r\n").unwrap();
        let path = std::env::join_paths([&dir]).unwrap();
        assert_eq!(
            resolve_program_from("fakecli", Some(path.as_os_str())),
            Some(dir.join("fakecli.cmd"))
        );
        assert_eq!(resolve_program_from("no-such-cli-xyz", Some(path.as_os_str())), None);
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[cfg(unix)]
    #[test]
    fn unix_resolution_is_the_bare_name() {
        // execvp does PATH resolution itself; the shim passes the bare name through.
        assert_eq!(resolve_program_from("ccs", None), Some(PathBuf::from("ccs")));
    }
}
