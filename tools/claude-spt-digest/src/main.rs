//! claude-spt-digest — the `[digest]` session-digest extractor for the claude-spt adapter (ADR-0019).
//!
//! Maps Claude Code's native JSONL transcript -> the published digest-record contract: NDJSON, one
//! `{"role","text"?,"tool"?,"ts"?}` object per stdout line. Emits RAW records — spt-core's digest
//! renderer applies the `[digest]` presentation defaults (window_turns / arg_truncation /
//! sprint_collapse), NOT this extractor. `role` is one of `input | agent | tool` (the published enum).
//!
//! Per-session by contract: spt-core's session ledger stitches the per-endpoint digest across
//! `/clear`; this reads exactly ONE session's log (the watch-item doyle flagged 2026-06-15 —
//! single-session slice is correct here, the spanning is ledger-side).
//!
//! Invoked by spt-core:  `claude-spt-digest --session <session_id> --in <source>`
//!   `<source>` is CC's per-project ROOT (`~/.claude/projects`); the session file lives at
//!   `<source>/<cwd-slug>/<session_id>.jsonl`. The cwd-slug subdir is a CC-internal encoding not
//!   expressible as a flat template, so we LOCATE `<session_id>.jsonl` by search under `<source>`.
//!   `spt adapter digest-proof --sample <file>` points `--in` straight at a log file; both shapes
//!   are handled (file -> read directly; dir -> locate the session within).
//!
//! ccs profile (REQ-CCS-PROFILES): a ccs-launched session relocates CC's whole state tree —
//! including `projects/` — under `$CLAUDE_CONFIG_DIR` (e.g. `~/.ccs/instances/<account>/.claude`).
//! That value is set by ccs at runtime per-account and is NOT expressible as a static manifest path,
//! so the `claude-spt:ccs` overlay carries no `[digest]` leaf — instead the dir-locate branch here
//! prefers `$CLAUDE_CONFIG_DIR/projects` over the `--in` root. Mirrors the known-good sister project
//! claude_skill_owl (owlery::claude_projects_root). The `--sample` file path is never overridden.
//!
//! Mapping (CC event -> digest record):
//!   type=user,  message.content str         -> {role:input, text}              (a real user prompt)
//!   type=user,  content[].type=text         -> {role:input, text}
//!   type=assistant, content[].type=text     -> {role:agent, text}
//!   type=assistant, content[].type=tool_use -> {role:tool,  tool:{name,arg}}
//!   thinking / tool_result / attachment / queue-operation / last-prompt -> skipped (not emitted)
//! [impl->REQ-DIST-DIGEST-EXTRACTOR]

use serde_json::{json, Value};
use std::fs::{self, File};
use std::io::{self, BufRead, BufReader, BufWriter, Write};
use std::path::{Path, PathBuf};
use std::process::ExitCode;

/// Single salient arg per tool call (spt-core truncates to arg_truncation). Preference order picks
/// the most digest-meaningful field; falls back to the first scalar, then compact JSON of the input.
const ARG_KEYS: &[&str] = &[
    "file_path", "path", "notebook_path", "command", "pattern", "query", "url", "prompt",
    "old_string", "description", "subagent_type",
];

fn scalar_str(v: &Value) -> Option<String> {
    match v {
        Value::String(s) => Some(s.clone()),
        Value::Number(n) => Some(n.to_string()),
        Value::Bool(b) => Some(b.to_string()),
        _ => None,
    }
}

fn tool_arg(input: &Value) -> String {
    let obj = match input.as_object() {
        Some(o) => o,
        None => return String::new(),
    };
    for k in ARG_KEYS {
        if let Some(s) = obj.get(*k).and_then(scalar_str) {
            if !s.is_empty() {
                return s;
            }
        }
    }
    for v in obj.values() {
        if let Some(s) = scalar_str(v) {
            if !s.is_empty() {
                return s;
            }
        }
    }
    serde_json::to_string(input).unwrap_or_default()
}

fn rec(role: &str, text: Option<&str>, tool: Option<Value>, ts: Option<&str>) -> Value {
    let mut m = serde_json::Map::new();
    m.insert("role".into(), json!(role));
    if let Some(t) = text {
        m.insert("text".into(), json!(t));
    }
    if let Some(t) = tool {
        m.insert("tool".into(), t);
    }
    if let Some(t) = ts {
        if !t.is_empty() {
            m.insert("ts".into(), json!(t));
        }
    }
    Value::Object(m)
}

/// Read CC JSONL from `reader`, write digest NDJSON to `writer`. Pure over byte streams so it is
/// directly unit-testable without touching the filesystem.
fn extract<R: BufRead, W: Write>(reader: R, mut writer: W) -> io::Result<()> {
    for line in reader.lines() {
        let line = line?;
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        let o: Value = match serde_json::from_str(line) {
            Ok(v) => v,
            Err(_) => continue, // CC's log is well-formed; a stray line is not ours to emit
        };
        let typ = o.get("type").and_then(Value::as_str).unwrap_or("");
        let ts = o.get("timestamp").and_then(Value::as_str);
        let msg = match o.get("message").and_then(Value::as_object) {
            Some(m) => m,
            None => continue,
        };
        let role = msg.get("role").and_then(Value::as_str).unwrap_or("");
        let content = msg.get("content");

        if typ == "user" && role == "user" {
            // A plain prompt is a string. List-content user turns are tool_results -> skip those.
            match content {
                Some(Value::String(s)) if !s.is_empty() => {
                    writeln!(writer, "{}", rec("input", Some(s), None, ts))?;
                }
                Some(Value::Array(items)) => {
                    for it in items {
                        if it.get("type").and_then(Value::as_str) == Some("text") {
                            if let Some(t) = it.get("text").and_then(Value::as_str) {
                                if !t.is_empty() {
                                    writeln!(writer, "{}", rec("input", Some(t), None, ts))?;
                                }
                            }
                        }
                    }
                }
                _ => {}
            }
        } else if typ == "assistant" && role == "assistant" {
            if let Some(Value::Array(items)) = content {
                for it in items {
                    match it.get("type").and_then(Value::as_str) {
                        Some("text") => {
                            if let Some(t) = it.get("text").and_then(Value::as_str) {
                                if !t.is_empty() {
                                    writeln!(writer, "{}", rec("agent", Some(t), None, ts))?;
                                }
                            }
                        }
                        Some("tool_use") => {
                            let name = it.get("name").and_then(Value::as_str).unwrap_or("");
                            let arg = it.get("input").map(tool_arg).unwrap_or_default();
                            let tool = json!({"name": name, "arg": arg});
                            writeln!(writer, "{}", rec("tool", None, Some(tool), ts))?;
                        }
                        _ => {} // thinking, etc. -> skip
                    }
                }
            }
        }
        // other event types -> skip
    }
    writer.flush()
}

/// Locate `<session>.jsonl` under `root` (depth-1 guess first, then a bounded recursive sweep —
/// the cwd-slug subdir is CC-internal so the exact path is not known a priori).
fn locate(root: &Path, session: &str) -> Option<PathBuf> {
    let target = format!("{session}.jsonl");
    // Depth-1: root/<slug>/<session>.jsonl
    if let Ok(entries) = fs::read_dir(root) {
        for e in entries.flatten() {
            let p = e.path();
            if p.is_dir() {
                let cand = p.join(&target);
                if cand.is_file() {
                    return Some(cand);
                }
            }
        }
    }
    // Bounded recursive fallback.
    find_recursive(root, &target, 6)
}

fn find_recursive(dir: &Path, target: &str, depth: usize) -> Option<PathBuf> {
    if depth == 0 {
        return None;
    }
    let entries = fs::read_dir(dir).ok()?;
    for e in entries.flatten() {
        let p = e.path();
        if p.is_file() {
            if p.file_name().and_then(|n| n.to_str()) == Some(target) {
                return Some(p);
            }
        } else if p.is_dir() {
            if let Some(hit) = find_recursive(&p, target, depth - 1) {
                return Some(hit);
            }
        }
    }
    None
}

struct Args {
    session: Option<String>,
    source: Option<String>,
}

fn parse_args() -> Result<Args, String> {
    let mut session = None;
    let mut source = None;
    let mut it = std::env::args().skip(1);
    while let Some(a) = it.next() {
        match a.as_str() {
            "--session" => session = it.next(),
            "--in" => source = it.next(),
            "-h" | "--help" => {
                println!("claude-spt-digest --session <id> --in <projects-root-or-logfile>");
                std::process::exit(0);
            }
            other => return Err(format!("unknown arg: {other}")),
        }
    }
    Ok(Args { session, source })
}

/// Expand a leading `~/` (or bare `~`) to the user's home. spt-core resolves `~` in the `source`
/// template, but the extractor expands defensively too — it runs argv-direct (no shell), so a
/// literal `~` would otherwise become a bogus relative path.
fn expand_tilde(p: &str) -> PathBuf {
    if p == "~" || p.starts_with("~/") || p.starts_with("~\\") {
        if let Some(home) = std::env::var_os("HOME").or_else(|| std::env::var_os("USERPROFILE")) {
            let rest = p[1..].trim_start_matches(['/', '\\']);
            return Path::new(&home).join(rest);
        }
    }
    PathBuf::from(p)
}

/// ccs (and any CLAUDE_CONFIG_DIR-relocating launcher) move CC's state tree — including the
/// `projects/` transcript root — under `$CLAUDE_CONFIG_DIR`. Returns `$CLAUDE_CONFIG_DIR/projects`
/// when `cfg` is `Some` and non-empty, else `None` (caller falls back to the `--in` root). Pure over
/// its input so the env read stays at the edge and this is unit-testable without env races. Mirrors
/// the known-good claude_skill_owl resolver (owlery::claude_projects_root). [impl->REQ-CCS-PROFILES]
fn ccs_projects_root_from(cfg: Option<&str>) -> Option<PathBuf> {
    match cfg {
        Some(c) if !c.is_empty() => Some(PathBuf::from(c).join("projects")),
        _ => None,
    }
}

fn run() -> Result<(), String> {
    let args = parse_args()?;
    let source = args.source.ok_or("missing required --in")?;
    let src = expand_tilde(&source);

    // --in may be a direct log FILE (digest-proof --sample) -> read it as-is, no env override.
    let path: Option<PathBuf> = if src.is_file() {
        Some(src)
    } else {
        // Directory ("projects root") branch. Honor a ccs-relocated config tree: prefer
        // $CLAUDE_CONFIG_DIR/projects over the manifest `--in` root (REQ-CCS-PROFILES).
        let env_cfg = std::env::var("CLAUDE_CONFIG_DIR").ok();
        let root = ccs_projects_root_from(env_cfg.as_deref()).unwrap_or(src);
        if root.is_dir() {
            let session = args.session.ok_or("--in is a directory but no --session to locate")?;
            locate(&root, &session)
        } else {
            None
        }
    };

    let path = match path {
        Some(p) => p,
        None => return Ok(()), // no log -> empty digest (not an error; spt-core reports the empty)
    };

    let file = File::open(&path).map_err(|e| format!("open {}: {e}", path.display()))?;
    let stdout = io::stdout();
    let writer = BufWriter::new(stdout.lock());
    extract(BufReader::new(file), writer).map_err(|e| e.to_string())
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("claude-spt-digest: {e}");
            ExitCode::from(2)
        }
    }
}

// [unit->REQ-DIST-DIGEST-EXTRACTOR]
#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::Value;

    fn run_extract(input: &str) -> Vec<Value> {
        let mut out = Vec::new();
        extract(input.as_bytes(), &mut out).unwrap();
        String::from_utf8(out)
            .unwrap()
            .lines()
            .filter(|l| !l.trim().is_empty())
            .map(|l| serde_json::from_str(l).expect("each output line is valid JSON"))
            .collect()
    }

    #[test]
    fn user_string_is_input() {
        let recs = run_extract(
            r#"{"type":"user","timestamp":"2026-06-15T10:00:00Z","message":{"role":"user","content":"hello"}}"#,
        );
        assert_eq!(recs.len(), 1);
        assert_eq!(recs[0]["role"], "input");
        assert_eq!(recs[0]["text"], "hello");
        assert_eq!(recs[0]["ts"], "2026-06-15T10:00:00Z");
    }

    #[test]
    fn assistant_text_is_agent_thinking_skipped() {
        let recs = run_extract(
            r#"{"type":"assistant","message":{"role":"assistant","content":[{"type":"thinking","thinking":"x"},{"type":"text","text":"hi"}]}}"#,
        );
        assert_eq!(recs.len(), 1, "thinking dropped, text kept");
        assert_eq!(recs[0]["role"], "agent");
        assert_eq!(recs[0]["text"], "hi");
    }

    #[test]
    fn tool_use_maps_name_and_arg() {
        let recs = run_extract(
            r#"{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Write","input":{"file_path":"src/a.rs","content":"fn main(){}"}}]}}"#,
        );
        assert_eq!(recs.len(), 1);
        assert_eq!(recs[0]["role"], "tool");
        assert_eq!(recs[0]["tool"]["name"], "Write");
        assert_eq!(recs[0]["tool"]["arg"], "src/a.rs"); // file_path preferred over content
    }

    #[test]
    fn tool_arg_prefers_command_then_first_scalar() {
        let recs = run_extract(
            r#"{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Bash","input":{"command":"cargo build","description":"d"}}]}}"#,
        );
        assert_eq!(recs[0]["tool"]["arg"], "cargo build");
    }

    #[test]
    fn user_tool_result_is_skipped() {
        let recs = run_extract(
            r#"{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1","content":"ok"}]}}"#,
        );
        assert!(recs.is_empty(), "tool_result has no contract role");
    }

    #[test]
    fn noise_types_and_bad_lines_skipped() {
        let input = concat!(
            r#"{"type":"attachment","attachment":{}}"#,
            "\n",
            r#"{"type":"last-prompt","lastPrompt":"x"}"#,
            "\n",
            "this is not json\n",
            "\n",
            r#"{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"only this"}]}}"#,
        );
        let recs = run_extract(input);
        assert_eq!(recs.len(), 1);
        assert_eq!(recs[0]["text"], "only this");
    }

    #[test]
    fn non_ascii_round_trips_utf8() {
        let recs = run_extract(
            r#"{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"done — built clean"}]}}"#,
        );
        assert_eq!(recs[0]["text"], "done — built clean");
    }

    #[test]
    fn tilde_expands_to_home() {
        std::env::set_var("HOME", "/home/test");
        assert_eq!(expand_tilde("~/.claude/projects"), Path::new("/home/test").join(".claude/projects"));
        assert_eq!(expand_tilde("/abs/path"), PathBuf::from("/abs/path"));
        assert_eq!(expand_tilde("rel/path"), PathBuf::from("rel/path"));
    }

    // [unit->REQ-CCS-PROFILES] ccs CLAUDE_CONFIG_DIR-aware projects-root resolution. Pure helper so
    // no env mutation / no test races (owl parity: set -> $CFG/projects; unset/empty -> fall back).
    #[test]
    fn ccs_root_honors_config_dir() {
        assert_eq!(
            ccs_projects_root_from(Some("/tmp/ccs-acct/.claude")),
            Some(Path::new("/tmp/ccs-acct/.claude").join("projects"))
        );
    }

    #[test]
    fn ccs_root_none_when_unset() {
        assert_eq!(ccs_projects_root_from(None), None);
    }

    #[test]
    fn ccs_root_ignores_empty() {
        // Empty env var must NOT shadow the --in fallback (owl: `!cfg.is_empty()` guard).
        assert_eq!(ccs_projects_root_from(Some("")), None);
    }

    #[test]
    fn every_record_satisfies_the_contract() {
        // role enum + field-presence invariants across a mixed stream.
        let input = concat!(
            r#"{"type":"user","message":{"role":"user","content":"q"}}"#,
            "\n",
            r#"{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"a"},{"type":"tool_use","name":"Read","input":{"file_path":"f"}}]}}"#,
        );
        for r in run_extract(input) {
            let role = r["role"].as_str().unwrap();
            assert!(matches!(role, "input" | "agent" | "tool"), "role enum: {role}");
            match role {
                "input" | "agent" => assert!(r.get("text").is_some() && r.get("tool").is_none()),
                "tool" => {
                    assert!(r.get("text").is_none());
                    assert!(r["tool"].get("name").is_some() && r["tool"].get("arg").is_some());
                }
                _ => unreachable!(),
            }
        }
    }
}
