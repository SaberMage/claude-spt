//! `claude-spt hook <event>` — the consolidated CC hook handler (D1, ADR-0006 ask #1 →
//! RESOLVE-NOT-EXECUTE; spt-core v0.16.0).
//!
//! Before D1 each Claude Code hook was a hand-written `.sh` wrapper in the cplugs plugin, sourcing a
//! shared `_common.sh`. That put hook LOGIC in the plugin channel, so every hook change forced a
//! cplugs republish + `claude plugin update` + `/reload-plugins`. D1 moves ALL hook logic here — a
//! subcommand of the one consolidated `claude-spt` binary — so it rides `spt adapter update` instead.
//! The plugin now ships only a STATIC-FOREVER `hooks.json` + a thin `dispatch.sh` that resolves this
//! binary via the lazily-substituted `[strings].hook_cmd = "{adapter_dir}/claude-spt hook"` and execs
//! `claude-spt hook <event>` with the CC hook payload on stdin. [impl->REQ-DIST-HOOK-BINARY]
//!
//! This is a BEHAVIOUR-PRESERVING refactor of the eight wrappers + `_common.sh`: the same `spt api …`
//! command lines, the same per-event stdout contract (SessionStart → a `hookSpecificOutput` JSON
//! line; UserPromptSubmit / PreToolUse → raw rendered additionalContext text), the same
//! no-op-when-no-perch, the same additionalContext spill guard. The pure helpers (envelope render,
//! brief assembly, checkpoint parse, …) are pure functions with direct unit tests; every external
//! effect (spawning `spt`, writing stdout / the spill file / the CC env file, reading env) goes
//! through the [`HookEnv`] trait so the event handlers are unit-testable with a recorder (call
//! ordering, no-op gating, emitted output) without spawning anything.
//!
//! Usage: `claude-spt hook <CCEventName> [--host-pid <pid>]`  (stdin = the CC hook payload JSON).
//! `<CCEventName>` is the verbatim CC hook event (SessionStart, UserPromptSubmit, PreToolUse, Stop,
//! SessionEnd, SubagentStart, SubagentStop, PostToolUse). `--host-pid` is the seed pid the dispatch
//! wrapper captures (`$PPID`) — Rust std has no portable getppid on Windows, so the wrapper passes it.
//!
//! [impl->REQ-DIST-HOOKS-API] [impl->REQ-UPS-INJECTION] [impl->REQ-DIST-SESSIONSTART-BRIEF]
//! [impl->REQ-DIST-PRETOOL-POLL] [impl->REQ-DIST-CHECKPOINT-COMMUNE] [impl->REQ-DIST-RESUME-CONTEXT]
//! [impl->REQ-DIST-SKELETON-THIN] [impl->REQ-DIST-SHORTCUT-BASENAME]

use serde_json::Value;
use std::io::Read;
use std::process::ExitCode;

/// The adapter_name — distinct from the plugin name `sptc`. Every `spt api` call that targets the
/// adapter explicitly carries `--adapter claude-spt` (the bind/boundary/state/poll/… verbs); `seed`
/// is adapter-AGNOSTIC (resolved at bind time from the seed's parent pid via host_binaries).
const ADAPTER: &str = "claude-spt";

/// Default additionalContext cap — CC spills additionalContext over ~10,000 chars to a file (dropping
/// it from the inline context the agent sees), so we pre-empt under it with margin. Override via
/// $SPTC_CTX_CAP (tests). (ADR-0002 Open #2.)
const DEFAULT_CAP: usize = 9000;

// ─────────────────────────── side-effect surface (testable seam) ───────────────────────────

/// Every external interaction the handlers need. The real [`SysEnv`] spawns `spt`, writes stdout /
/// files / the CC env file and reads process env; a test recorder records calls and serves canned
/// `spt` output, so the handlers' logic (ordering, gating, emitted text) is unit-testable offline.
pub trait HookEnv {
    /// Run `spt <args>` with optional stdin and extra env vars; return stdout with trailing newlines
    /// stripped (matching shell `$(…)`), or `None` if `spt` could not be spawned. The exit code is
    /// IGNORED — every shell wrapper ran its `spt` call with `|| true`, treating any output as the
    /// result and any failure as empty.
    fn spt(&mut self, args: &[&str], stdin: Option<&str>, extra_env: &[(&str, &str)]) -> Option<String>;
    /// Write text to CC stdout (the additionalContext channel). Verbatim — no added newline.
    fn emit(&mut self, text: &str);
    /// Spill oversized content to `path`; return true on success.
    fn write_spill(&mut self, path: &str, content: &str) -> bool;
    /// Append a `KEY=value` line to $CLAUDE_ENV_FILE (no-op if unset).
    fn append_env_file(&mut self, line: &str);
    /// Read a process environment variable.
    fn env(&self, key: &str) -> Option<String>;
    /// The seed pid the dispatch wrapper captured (`--host-pid`).
    fn host_pid(&self) -> Option<String>;
    /// $HOME (or %USERPROFILE%) — the spill-path root.
    fn home(&self) -> String;
    /// The additionalContext byte cap ($SPTC_CTX_CAP, else [`DEFAULT_CAP`]).
    fn cap(&self) -> usize;
}

// ─────────────────────────── pure helpers (direct unit tests) ───────────────────────────

/// Top-level string field of the parsed CC hook object (empty if absent / not a string).
fn field(v: &Value, key: &str) -> String {
    v.get(key).and_then(Value::as_str).unwrap_or("").to_string()
}

/// A field nested one level under `parent` (CC's `tool_input.{file_path,content}`), empty if absent.
fn nested(v: &Value, parent: &str, key: &str) -> String {
    v.get(parent).and_then(|p| p.get(key)).and_then(Value::as_str).unwrap_or("").to_string()
}

/// Decode an spt envelope body to plain text: literal `<br>` → newline, then HTML entities
/// (`&lt; &gt; &quot;` then `&amp;` LAST, so an embedded `&amp;lt;` does not double-decode). Exactly
/// the live-agent body-parsing rule (spt-proto::event grammar). [impl->REQ-UPS-INJECTION]
fn unescape(s: &str) -> String {
    s.replace("<br>", "\n")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", "\"")
        .replace("&amp;", "&") // LAST
}

/// Value of attribute `name` in an EVENT opening tag (the substring before the first `>`), e.g.
/// `from="doyle"` → `doyle`. Leading-space-anchored so `from` never matches a substring of another
/// attribute name. None if absent.
fn opening_attr(opening: &str, name: &str) -> Option<String> {
    let key = format!(" {name}=\"");
    let ki = opening.find(&key)?;
    let rest = &opening[ki + key.len()..];
    let end = rest.find('"')?;
    Some(rest[..end].to_string())
}

/// Render an `api poll` drain for CC. Canonical format: every message is a self-delimiting
/// `<EVENT type="msg" from="<sender>">body</EVENT>` envelope (spt-proto::event) — the same grammar
/// the live listener emits; multi-message drains concatenate. Each becomes a `<sptc_messages>` block
/// (sender preserved as `from=` for reply-correlation, dropped only when the envelope has none).
/// Multiple blocks are newline-joined. [unit->REQ-UPS-INJECTION]
fn render_frames(raw: &str) -> String {
    let mut out: Vec<String> = Vec::new();
    let mut rest = raw;
    while let Some(start) = rest.find("<EVENT") {
        let after = &rest[start..];
        let Some(gt) = after.find('>') else { break };
        let opening = &after[..gt];
        let body_start = gt + 1;
        let Some(close_rel) = after[body_start..].find("</EVENT>") else { break };
        let body_raw = &after[body_start..body_start + close_rel];
        let body = unescape(body_raw);
        match opening_attr(opening, "from") {
            Some(s) => out.push(format!("<sptc_messages from=\"{s}\">\n{body}\n</sptc_messages>")),
            None => out.push(format!("<sptc_messages>\n{body}\n</sptc_messages>")),
        }
        let consumed = start + body_start + close_rel + "</EVENT>".len();
        rest = &rest[consumed..];
    }
    out.join("\n")
}

/// Extract the skill name from a `/sptc:<skill>` slash-command prompt. UPS fires on a slash-command
/// with the token intact (ADR-0002 validation); the name is leading-only (after optional whitespace)
/// so prose merely mentioning `/sptc:x` mid-sentence does not fire. Skill ids are `[a-z][a-z0-9-]*`.
/// Empty if not a leading sptc slash-command. [unit->REQ-UPS-INJECTION]
fn skill_key(prompt: &str) -> String {
    let p = prompt.trim_start_matches([' ', '\t']);
    let Some(after) = p.strip_prefix("/sptc:") else { return String::new() };
    let mut chars = after.chars();
    match chars.next() {
        Some(c) if c.is_ascii_lowercase() => {}
        _ => return String::new(),
    }
    let mut key = String::new();
    key.push(after.chars().next().unwrap());
    for c in after.chars().skip(1) {
        if c.is_ascii_lowercase() || c.is_ascii_digit() || c == '-' {
            key.push(c);
        } else {
            break;
        }
    }
    key
}

/// The SessionStart registration verb for this spawn. `clear`/`compact` → `boundary` (rebind the
/// perch to the new session id within a live session); else `bind` when spt-hosted (the broker
/// injected $SPT_ENDPOINT_ID — the perch already exists, self-register post-spawn) or `seed` when
/// harness-hosted (user-launched CC — record an ephemeral seed for /sptc:ready|live).
/// [impl->REQ-DIST-SHORTCUT-BASENAME]
fn register_verb(source: &str, endpoint_id_present: bool) -> &'static str {
    match source {
        "clear" | "compact" => "boundary",
        _ if endpoint_id_present => "bind",
        _ => "seed",
    }
}

/// True for a subagent session (CC sets `agent_type`); those get no SessionStart brief.
/// [impl->REQ-DIST-SESSIONSTART-BRIEF]
fn is_subagent(agent_type: &str) -> bool {
    !agent_type.is_empty()
}

/// Peer-presence gate for the ring brief: `spt subnet status` output has peers iff it has >1
/// non-empty line (header + ≥1 subnet row). Line-count only — never parses a column value (the
/// columnar layout is human-formatted, not a hook contract). [impl->REQ-DIST-SESSIONSTART-BRIEF]
fn has_peers(subnet_status: &str) -> bool {
    subnet_status.lines().filter(|l| !l.trim().is_empty()).count() > 1
}

/// Assemble the identity (perched) block, substituting every `{id}` in the identity body (agent ids
/// are `[a-z0-9-]`, so plain string replace is safe). [impl->REQ-DIST-SESSIONSTART-BRIEF]
fn assemble_perch(id: &str, identity_body: &str, messaging_body: &str, roster: &str) -> String {
    format!(
        "<sptc-active-perch id=\"{id}\">\n{}\n\n{messaging_body}\n\n{roster}\n</sptc-active-perch>",
        identity_body.replace("{id}", id)
    )
}

/// Assemble the ring (no-perch) block. [impl->REQ-DIST-SESSIONSTART-BRIEF]
fn assemble_noperch(messaging_body: &str, roster: &str) -> String {
    format!("<sptc-reach>\n{messaging_body}\n\n{roster}\n</sptc-reach>")
}

/// JSON-escape a string into a value (no surrounding quotes): `\` then `"` then tab then CR, and
/// newlines become a literal `\n`. Mirrors the awk escaper so multi-line bodies survive.
/// [impl->REQ-DIST-SESSIONSTART-BRIEF]
fn json_escape(s: &str) -> String {
    let mut out = String::new();
    for (i, line) in s.split('\n').enumerate() {
        if i > 0 {
            out.push_str("\\n");
        }
        out.push_str(
            &line
                .replace('\\', "\\\\")
                .replace('"', "\\\"")
                .replace('\t', "\\t")
                .replace('\r', "\\r"),
        );
    }
    out
}

/// The SessionStart `hookSpecificOutput` JSON line carrying `text` as additionalContext, or empty
/// (no output) when `text` is empty. [impl->REQ-DIST-SESSIONSTART-BRIEF]
fn emit_additional_context(text: &str) -> String {
    if text.is_empty() {
        return String::new();
    }
    format!(
        "{{\"hookSpecificOutput\":{{\"hookEventName\":\"SessionStart\",\"additionalContext\":\"{}\"}}}}\n",
        json_escape(text)
    )
}

/// Append the durable RESUME context below a SessionStart brief, skipping cleanly (brief unchanged,
/// no trailing newline) when the resume is empty (NO-CONTEXT). [impl->REQ-DIST-RESUME-CONTEXT]
fn append_resume(brief: &str, resume: &str) -> String {
    if resume.is_empty() {
        brief.to_string()
    } else {
        format!("{brief}\n{resume}")
    }
}

/// Does this commune content carry the checkpoint trigger? [unit->REQ-DIST-CHECKPOINT-COMMUNE]
fn has_checkpoint(content: &str) -> bool {
    content.contains("!!checkpoint!!")
}

/// Extract a CUSTOM wake directive from commune content — the trimmed text between the first PAIR of
/// `!!checkpoint!!` markers. Empty when there is fewer than one pair (a single marker = default wake,
/// supplied by the translation binary; none = not a checkpoint). [unit->REQ-DIST-CHECKPOINT-COMMUNE]
fn checkpoint_wake(content: &str) -> String {
    const M: &str = "!!checkpoint!!";
    let Some(first) = content.find(M) else { return String::new() };
    let after_first = first + M.len();
    let Some(rel) = content[after_first..].find(M) else { return String::new() };
    content[after_first..after_first + rel].trim().to_string()
}

/// Is this tool call a Write to THIS agent's own commune file `<id>-commune.md`? Suffix match
/// tolerates a JSON-escaped Windows path (doubled backslashes) and either separator.
/// [unit->REQ-DIST-CHECKPOINT-COMMUNE]
fn is_commune_write(tool: &str, file_path: &str, id: &str) -> bool {
    tool == "Write" && !id.is_empty() && file_path.ends_with(&format!("{id}-commune.md"))
}

/// Build the structured checkpoint self-send payload: a custom wake rides as `wake`, otherwise it is
/// omitted so the translation binary applies its own default. [impl->REQ-DIST-CHECKPOINT-COMMUNE]
fn checkpoint_payload(wake: &str) -> String {
    if wake.is_empty() {
        "{\"checkpoint\":\"v1\"}".to_string()
    } else {
        format!("{{\"checkpoint\":\"v1\",\"wake\":\"{}\"}}", json_escape(wake))
    }
}

/// The capped-emit decision (pure). Under the cap → inline verbatim; over → spill the full text and
/// emit only a pointer marker (never a head-cut that would split a `<sptc_messages>`/`<EVENT>` block
/// and silently drop a message); empty → no output. [impl->REQ-UPS-INJECTION]
enum Cap {
    Empty,
    Inline(String),
    Overflow { len: usize },
}

fn cap_decide(text: &str, cap: usize) -> Cap {
    if text.is_empty() {
        Cap::Empty
    } else if text.len() <= cap {
        Cap::Inline(text.to_string())
    } else {
        Cap::Overflow { len: text.len() }
    }
}

/// Emit additionalContext under CC's spill threshold: inline if it fits, else spill the FULL text to
/// `spill_path` (agent-readable) and emit a concise `<sptc_overflow>` pointer. [impl->REQ-UPS-INJECTION]
fn emit_capped(env: &mut dyn HookEnv, text: &str, spill_path: &str) {
    match cap_decide(text, env.cap()) {
        Cap::Empty => {}
        Cap::Inline(t) => env.emit(&t),
        Cap::Overflow { len } => {
            let path = if env.write_spill(spill_path, text) {
                spill_path.to_string()
            } else {
                "(spill failed; content too large to inline)".to_string()
            };
            let cap = env.cap();
            env.emit(&format!(
                "<sptc_overflow bytes=\"{len}\" cap=\"{cap}\" spilled_to=\"{path}\">\nDelivery exceeded CC's additionalContext cap. The full content (skill instructions and/or {len} message bytes) was written to the file above — read it now to see everything; it is NOT inlined here to avoid silently dropping a message.\n</sptc_overflow>\n"
            ));
        }
    }
}

// ─────────────────────────── impure resolvers (use HookEnv) ───────────────────────────

/// Resolve this session's perch id via `spt whoami --json` (off $OWL_SESSION_ID / $SPT_AGENT_ID).
/// Empty ⇒ no perch yet (session never readied) ⇒ caller no-ops. The whoami call is given
/// $OWL_SESSION_ID set to the env value if present, else the stdin session id (mirrors the shell
/// `${OWL_SESSION_ID:-$sid}`).
///
/// `--json` is REQUIRED here (global read/status flag, spt-core v0.16.0 — always on our floor):
/// the identity is `.self.id`, `null` when the session has no perch. NEVER take a line of the
/// human view — it is a grouped roster whose first line is a `SUBNET <name>` header on any node
/// with subnet membership (and `SELF: <id> …` when perched), so first-line parsing crowned an
/// agent "SUBNET SPT_DEV" and told it not to run whoami (doyle bug report 2026-07-01; the wrong
/// identity self-reinforced through a whole orchestration round).
/// [impl->REQ-DIST-WHOAMI-JSON]
fn self_id(env: &mut dyn HookEnv, sid: &str) -> String {
    let owl = env.env("OWL_SESSION_ID").filter(|s| !s.is_empty()).unwrap_or_else(|| sid.to_string());
    let out = env
        .spt(&["whoami", "--json"], None, &[("OWL_SESSION_ID", &owl)])
        .unwrap_or_default();
    parse_whoami_self(&out)
}

/// Extract `.self.id` from `spt whoami --json` output. Pure over the string so the contract is
/// unit-testable: JSON with `self:null` (or any parse failure, e.g. a pre-JSON binary's human
/// roster) resolves to "" — no-perch, NEVER a roster header. [impl->REQ-DIST-WHOAMI-JSON]
fn parse_whoami_self(out: &str) -> String {
    serde_json::from_str::<serde_json::Value>(out.trim())
        .ok()
        .and_then(|v| v.get("self").and_then(|s| s.get("id")).and_then(|i| i.as_str()).map(String::from))
        .unwrap_or_default()
}

/// Resolve a `[strings]` value by dot-path on the registered adapter (file-backed values resolve to
/// file contents at read time). Empty on absent key / unregistered adapter / missing spt.
fn get_string(env: &mut dyn HookEnv, key: &str) -> String {
    env.spt(&["adapter", "get-string", ADAPTER, key], None, &[]).unwrap_or_default()
}

/// Inject a skill's operative instructions as additionalContext, resolved from
/// `[strings.skills].<skill>`. No-op (empty) if the name is empty or the body is unset.
/// [impl->REQ-UPS-INJECTION]
fn inject_skill(env: &mut dyn HookEnv, skill: &str) -> String {
    if skill.is_empty() {
        return String::new();
    }
    let body = get_string(env, &format!("skills.{skill}"));
    if body.is_empty() {
        return String::new();
    }
    format!("<sptc_skill name=\"{skill}\">\n{body}\n</sptc_skill>\n")
}

/// Resolve + assemble the perched-session identity brief. The live-ops block (commune incl
/// --checkpoint, signoff — U4) is composed into the messaging block so a perched/live agent is
/// briefed on upkeep proactively. [impl->REQ-DIST-SESSIONSTART-BRIEF] [impl->REQ-DIST-SKELETON-THIN]
fn perch_brief(env: &mut dyn HookEnv, id: &str) -> String {
    let mut msg = get_string(env, "briefs.messaging-perch");
    let ops = get_string(env, "briefs.live-ops");
    if !ops.is_empty() {
        msg = format!("{msg}\n\n{ops}");
    }
    let identity = get_string(env, "briefs.identity");
    let roster = get_string(env, "briefs.endpoint-list");
    assemble_perch(id, &identity, &msg, &roster)
}

/// Resolve + assemble the no-perch ring brief. [impl->REQ-DIST-SESSIONSTART-BRIEF]
fn noperch_brief(env: &mut dyn HookEnv) -> String {
    let msg = get_string(env, "briefs.messaging-no-perch");
    let roster = get_string(env, "briefs.endpoint-list");
    assemble_noperch(&msg, &roster)
}

/// Pull the live-agent durable RESUME context via `spt api psyche-download` (closes F-020). Empty on
/// NO-CONTEXT / the verb absent (pre-v0.15.0) / unregistered — caller appends nothing. Mirrors the
/// id-scoped `api poll` auth shape (--session-id; project resolves from the bound cwd).
/// [impl->REQ-DIST-RESUME-CONTEXT]
fn psyche_download(env: &mut dyn HookEnv, id: &str, sid: &str) -> String {
    if id.is_empty() {
        return String::new();
    }
    if sid.is_empty() {
        env.spt(&["api", "--adapter", ADAPTER, "psyche-download", id], None, &[]).unwrap_or_default()
    } else {
        env.spt(&["api", "--adapter", ADAPTER, "psyche-download", id, "--session-id", sid], None, &[])
            .unwrap_or_default()
    }
}

/// The additionalContext spill path for a session (absolute, agent-readable, keyed by session id).
fn spill_path(env: &dyn HookEnv, sid: &str) -> String {
    let sid = if sid.is_empty() { "unknown" } else { sid };
    format!("{}/.claude/sptc-drain-{sid}.txt", env.home())
}

// ─────────────────────────── per-event handlers ───────────────────────────

/// SessionStart: register the perch (bind / seed / boundary) + persist session env, then relay an
/// agent-facing brief as additionalContext. Non-blocking (never `listen`). The invisible-installer
/// bootstrap (install spt-core if absent) + the $SPTC_HOOK_BIN cache live in the dispatch wrapper —
/// the binary cannot exist before spt-core + the adapter are installed. [impl->REQ-DIST-HOOKS-API]
fn handle_session_start(env: &mut dyn HookEnv, v: &Value) {
    let sid = field(v, "session_id");
    let src = field(v, "source");
    let endpoint_id = env.env("SPT_ENDPOINT_ID").filter(|s| !s.is_empty());
    let verb = register_verb(&src, endpoint_id.is_some());

    match verb {
        "boundary" => {
            let id = self_id(env, &sid);
            if !id.is_empty() {
                env.spt(
                    &["api", "--adapter", ADAPTER, "boundary", &src, &id, "--to-session-id", &sid],
                    None,
                    &[],
                );
            }
        }
        "bind" => {
            // spt-hosted: the perch exists (broker parentage is the credential — --set-session-id
            // only, no proof token). endpoint_id is Some here by construction of register_verb.
            if let Some(eid) = endpoint_id.as_deref() {
                env.spt(&["api", "--adapter", ADAPTER, "bind", eid, "--set-session-id", &sid], None, &[]);
            }
        }
        _ => {
            // seed (harness-hosted): adapter-agnostic (NO --adapter) — resolved at bind time from the
            // seed's parent pid via host_binaries. The host pid is passed by dispatch (--host-pid).
            let pid = env.host_pid().unwrap_or_default();
            env.spt(&["api", "seed", "--pid", &pid, "--session-id", &sid], None, &[]);
        }
    }

    // Persist for the rest of the session (whoami fallback + parity with the shell wrapper).
    env.append_env_file(&format!("OWL_SESSION_ID={sid}"));
    env.append_env_file(&format!("SPT_ADAPTER={ADAPTER}"));

    // Brief (skip subagent sessions). Perched (bind/boundary) → identity brief + durable resume;
    // no-perch seed on a node WITH peers → ring brief; seed without peers → nothing.
    if is_subagent(&field(v, "agent_type")) {
        return;
    }
    let brief = match verb {
        "bind" | "boundary" => {
            let bid = endpoint_id.clone().unwrap_or_else(|| self_id(env, &sid));
            if bid.is_empty() {
                String::new()
            } else {
                let b = perch_brief(env, &bid);
                append_resume(&b, &psyche_download(env, &bid, &sid))
            }
        }
        _ => {
            let status = env.spt(&["subnet", "status"], None, &[]).unwrap_or_default();
            if has_peers(&status) {
                noperch_brief(env)
            } else {
                String::new()
            }
        }
    };
    let line = emit_additional_context(&brief);
    if !line.is_empty() {
        env.emit(&line);
    }
}

/// UserPromptSubmit (turn-start): inject a `/sptc:<skill>` body if present, mark the perch BUSY so
/// inbound DEFERS for mid-turn PreToolUse delivery, then DRAIN the inbox (incl. deferred). Both ride
/// the combined, once-capped additionalContext. [impl->REQ-UPS-INJECTION] [impl->REQ-DIST-PRETOOL-POLL]
fn handle_user_prompt_submit(env: &mut dyn HookEnv, v: &Value) {
    let sid = field(v, "session_id");
    // Skill-injection runs BEFORE the perch check — /sptc:version|setup are valid without a perch.
    let mut out = inject_skill(env, &skill_key(&field(v, "prompt")));

    let id = self_id(env, &sid);
    if !id.is_empty() {
        // Mark busy BEFORE the drain so a message arriving mid-drain also defers (F-021).
        env.spt(&["api", "--adapter", ADAPTER, "state", "busy", &id, "--session-id", &sid], None, &[]);
        let frames = env
            .spt(&["api", "--adapter", ADAPTER, "poll", &id, "--session-id", &sid, "--include-deferred"], None, &[])
            .unwrap_or_default();
        if !frames.is_empty() {
            let rendered = render_frames(&frames);
            if !rendered.is_empty() {
                out = if out.is_empty() { rendered } else { format!("{out}\n{rendered}") };
            }
        }
    }
    let spill = spill_path(env, &sid);
    emit_capped(env, &out, &spill);
}

/// PreToolUse: mid-turn delivery (F-021). Marks the perch busy (idempotent; the only busy mark for a
/// turn that started without a UserPromptSubmit) then drains messages deferred while busy.
/// [impl->REQ-DIST-PRETOOL-POLL]
fn handle_pre_tool_use(env: &mut dyn HookEnv, v: &Value) {
    let sid = field(v, "session_id");
    let id = self_id(env, &sid);
    if id.is_empty() {
        return;
    }
    env.spt(&["api", "--adapter", ADAPTER, "state", "busy", &id, "--session-id", &sid], None, &[]);
    let frames = env
        .spt(&["api", "--adapter", ADAPTER, "poll", &id, "--session-id", &sid, "--include-deferred"], None, &[])
        .unwrap_or_default();
    if frames.is_empty() {
        return;
    }
    let rendered = render_frames(&frames);
    let spill = spill_path(env, &sid);
    emit_capped(env, &rendered, &spill);
}

/// Stop (turn-end): mark the perch idle (also arms the echo-gate fallback). [impl->REQ-DIST-HOOKS-API]
fn handle_stop(env: &mut dyn HookEnv, v: &Value) {
    let sid = field(v, "session_id");
    let id = self_id(env, &sid);
    if id.is_empty() {
        return;
    }
    env.spt(&["api", "--adapter", ADAPTER, "state", "idle", &id, "--session-id", &sid], None, &[]);
}

/// SessionEnd: soft teardown of the perch (spool/history preserved). [impl->REQ-DIST-HOOKS-API]
fn handle_session_end(env: &mut dyn HookEnv, v: &Value) {
    let sid = field(v, "session_id");
    let id = self_id(env, &sid);
    if id.is_empty() {
        return;
    }
    env.spt(&["api", "--adapter", ADAPTER, "session-end", &id, "--session-id", &sid], None, &[]);
}

/// SubagentStart (fires in the PARENT's context): create a nested worker perch under the parent.
/// [impl->REQ-DIST-HOOKS-API]
fn handle_subagent_start(env: &mut dyn HookEnv, v: &Value) {
    let sid = field(v, "session_id");
    let agent_id = field(v, "agent_id");
    let parent = self_id(env, &sid);
    if parent.is_empty() || agent_id.is_empty() {
        return;
    }
    env.spt(&["api", "--adapter", ADAPTER, "worker-start", &parent, &agent_id, "--session-id", &sid], None, &[]);
}

/// SubagentStop (fires in the PARENT's context): tear down the worker perch. [impl->REQ-DIST-HOOKS-API]
fn handle_subagent_stop(env: &mut dyn HookEnv, v: &Value) {
    let sid = field(v, "session_id");
    let agent_id = field(v, "agent_id");
    if agent_id.is_empty() {
        return;
    }
    env.spt(&["api", "--adapter", ADAPTER, "worker-stop", &agent_id, "--session-id", &sid], None, &[]);
}

/// PostToolUse (Write matcher): the agent-driven CHECKPOINT detector. On a Write to THIS spt-hosted
/// live agent's own `.claude/<id>-commune.md` whose content carries `!!checkpoint!!`, mark the perch
/// idle and self-send a reserved `{"checkpoint":"v1",…}` signal that loops back through the endpoint's
/// own translation binary (the clear+wake macro). spt-hosted live sessions only ($SPT_ENDPOINT_ID).
/// [impl->REQ-DIST-CHECKPOINT-COMMUNE]
fn handle_post_tool_use(env: &mut dyn HookEnv, v: &Value) {
    let Some(id) = env.env("SPT_ENDPOINT_ID").filter(|s| !s.is_empty()) else { return };
    let tool = field(v, "tool_name");
    let file_path = nested(v, "tool_input", "file_path");
    if !is_commune_write(&tool, &file_path, &id) {
        return;
    }
    let content = nested(v, "tool_input", "content");
    if !has_checkpoint(&content) {
        return;
    }
    let sid = field(v, "session_id");
    // Mark idle so the loopback delivery lands on an idle input box, not mid-turn.
    env.spt(&["api", "--adapter", ADAPTER, "state", "idle", &id, "--session-id", &sid], None, &[]);
    let payload = checkpoint_payload(&checkpoint_wake(&content));
    // Self-send the signal back through our own endpoint's translation binary (the proven loopback).
    // Body is a harmless note; the structured trigger rides the json attr (collision-proof).
    env.spt(
        &["send", "--from", &id, &id, "--json-payload", &payload],
        Some("checkpoint requested"),
        &[],
    );
}

/// Dispatch a parsed CC hook payload to the handler for `event` (the verbatim CC event name).
/// Unknown events are a silent no-op (forward-compat with a newer plugin wiring an event this binary
/// does not yet handle). [impl->REQ-DIST-HOOK-BINARY]
fn dispatch(env: &mut dyn HookEnv, event: &str, v: &Value) {
    match event {
        "SessionStart" => handle_session_start(env, v),
        "UserPromptSubmit" => handle_user_prompt_submit(env, v),
        "PreToolUse" => handle_pre_tool_use(env, v),
        "Stop" => handle_stop(env, v),
        "SessionEnd" => handle_session_end(env, v),
        "SubagentStart" => handle_subagent_start(env, v),
        "SubagentStop" => handle_subagent_stop(env, v),
        "PostToolUse" => handle_post_tool_use(env, v),
        _ => {}
    }
}

// ─────────────────────────── real environment + entry ───────────────────────────

/// The production [`HookEnv`]: spawns `spt`, writes real stdout / files / env, reads process env.
struct SysEnv {
    host_pid: Option<String>,
}

impl SysEnv {
    /// Resolve the `spt` binary: PATH first (post-bootstrap), then known install locations.
    fn spt_bin() -> String {
        if which("spt") {
            return "spt".to_string();
        }
        let home = std::env::var("HOME").unwrap_or_default();
        let local = std::env::var("LOCALAPPDATA").unwrap_or_default();
        for p in [
            format!("{home}/.local/bin/spt"),
            format!("{local}/spt-core/bin/spt.exe"),
            format!("{home}/AppData/Local/spt-core/bin/spt.exe"),
        ] {
            if std::path::Path::new(&p).is_file() {
                return p;
            }
        }
        "spt".to_string() // last resort; the caller tolerates failure
    }
}

/// Is `name` resolvable on PATH? (cross-platform `command -v`).
fn which(name: &str) -> bool {
    let path = std::env::var_os("PATH").unwrap_or_default();
    let exts: Vec<String> = if cfg!(windows) {
        std::env::var("PATHEXT")
            .unwrap_or_else(|_| ".EXE;.CMD;.BAT;.COM".into())
            .split(';')
            .map(|e| e.to_ascii_lowercase())
            .collect()
    } else {
        vec![String::new()]
    };
    for dir in std::env::split_paths(&path) {
        let cand = dir.join(name);
        if cand.is_file() {
            return true;
        }
        for ext in &exts {
            if ext.is_empty() {
                continue;
            }
            if dir.join(format!("{name}{ext}")).is_file() {
                return true;
            }
        }
    }
    false
}

impl HookEnv for SysEnv {
    fn spt(&mut self, args: &[&str], stdin: Option<&str>, extra_env: &[(&str, &str)]) -> Option<String> {
        use std::io::Write;
        use std::process::{Command, Stdio};
        let mut cmd = Command::new(SysEnv::spt_bin());
        cmd.args(args);
        for (k, val) in extra_env {
            cmd.env(k, val);
        }
        cmd.stdout(Stdio::piped()).stderr(Stdio::null());
        cmd.stdin(if stdin.is_some() { Stdio::piped() } else { Stdio::null() });
        let mut child = cmd.spawn().ok()?;
        if let Some(s) = stdin {
            if let Some(mut si) = child.stdin.take() {
                let _ = si.write_all(s.as_bytes());
            }
        }
        let out = child.wait_with_output().ok()?;
        let mut s = String::from_utf8_lossy(&out.stdout).into_owned();
        // Match shell `$(…)`: strip ALL trailing newlines.
        while s.ends_with('\n') || s.ends_with('\r') {
            s.pop();
        }
        Some(s)
    }

    fn emit(&mut self, text: &str) {
        use std::io::Write;
        let mut so = std::io::stdout();
        let _ = so.write_all(text.as_bytes());
        let _ = so.flush();
    }

    fn write_spill(&mut self, path: &str, content: &str) -> bool {
        std::fs::write(path, content).is_ok()
    }

    fn append_env_file(&mut self, line: &str) {
        use std::io::Write;
        if let Ok(path) = std::env::var("CLAUDE_ENV_FILE") {
            if !path.is_empty() {
                if let Ok(mut f) = std::fs::OpenOptions::new().create(true).append(true).open(&path) {
                    let _ = writeln!(f, "{line}");
                }
            }
        }
    }

    fn env(&self, key: &str) -> Option<String> {
        std::env::var(key).ok()
    }

    fn host_pid(&self) -> Option<String> {
        self.host_pid.clone()
    }

    fn home(&self) -> String {
        std::env::var("HOME")
            .or_else(|_| std::env::var("USERPROFILE"))
            .unwrap_or_else(|_| ".".to_string())
    }

    fn cap(&self) -> usize {
        std::env::var("SPTC_CTX_CAP").ok().and_then(|s| s.parse().ok()).unwrap_or(DEFAULT_CAP)
    }
}

/// The CC hook event names this binary handles — the SINGLE source of truth, shared by [`dispatch`]
/// and the stale-dispatch pass-through recognizer [`is_cc_hook_event`] that `main` uses to DEGRADE
/// (not brick) when a stale plugin dispatch.sh execs `claude-spt <Event>` without the `hook` token.
/// [impl->REQ-HAZARD-HOOKCMD-DISPATCH-LOCKSTEP]
pub const CC_HOOK_EVENTS: &[&str] = &[
    "SessionStart",
    "UserPromptSubmit",
    "PreToolUse",
    "Stop",
    "SessionEnd",
    "SubagentStart",
    "SubagentStop",
    "PostToolUse",
];

/// True if `name` is a CC hook event this binary handles. `main` uses this to recognise the
/// stale-dispatch skew (a bare `claude-spt UserPromptSubmit` — the `hook` token dropped by an old
/// plugin dispatch.sh) and route it through as a hook instead of exiting nonzero → blocking CC.
/// [impl->REQ-HAZARD-HOOKCMD-DISPATCH-LOCKSTEP]
pub fn is_cc_hook_event(name: &str) -> bool {
    CC_HOOK_EVENTS.contains(&name)
}

/// `claude-spt hook <event> [--host-pid <pid>]` entry. Reads the CC hook payload from stdin, parses
/// it once, and dispatches to the event handler. A missing event or unparseable stdin is a silent
/// no-op exit 0 (a hook must never break the CC session). [impl->REQ-DIST-HOOK-BINARY]
pub fn run() -> ExitCode {
    let Some(event) = std::env::args().nth(2) else {
        // skip "claude-spt" + "hook"
        eprintln!("claude-spt hook: missing <event>");
        return ExitCode::SUCCESS;
    };
    run_event(&event)
}

/// Handle a CC hook `event` given the event name explicitly. Scans argv for `--host-pid`
/// POSITION-INDEPENDENTLY so it serves both the normal `claude-spt hook <event> --host-pid <pid>`
/// path and the stale-dispatch pass-through `claude-spt <event> --host-pid <pid>` (where the `hook`
/// token is missing, so a fixed `skip(2)` would mis-read the event). Reads the CC hook payload from
/// stdin; always exits 0 — a hook must never break the CC session.
/// [impl->REQ-DIST-HOOK-BINARY] [impl->REQ-HAZARD-HOOKCMD-DISPATCH-LOCKSTEP]
pub fn run_event(event: &str) -> ExitCode {
    let mut host_pid: Option<String> = None;
    let mut it = std::env::args();
    while let Some(a) = it.next() {
        if a == "--host-pid" {
            host_pid = it.next();
        }
    }

    let mut input = String::new();
    let _ = std::io::stdin().read_to_string(&mut input);
    let v: Value = serde_json::from_str(input.trim()).unwrap_or(Value::Null);

    let mut env = SysEnv { host_pid };
    dispatch(&mut env, event, &v);
    ExitCode::SUCCESS
}

// ─────────────────────────── tests ───────────────────────────
#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    // ---- pure helpers (port of tests/hooks-parse.sh coverage) ----

    #[test]
    fn field_and_nested_extraction() {
        let v = json!({"session_id":"s1","prompt":"/sptc:send doyle","tool_input":{"file_path":"/x/p.md","content":"c"}});
        assert_eq!(field(&v, "session_id"), "s1");
        assert_eq!(field(&v, "prompt"), "/sptc:send doyle");
        assert_eq!(field(&v, "nope"), "");
        assert_eq!(nested(&v, "tool_input", "file_path"), "/x/p.md");
        assert_eq!(nested(&v, "tool_input", "content"), "c");
        assert_eq!(nested(&v, "tool_input", "nope"), "");
    }

    // [unit->REQ-UPS-INJECTION]
    #[test]
    fn unescape_br_entities_amp_last() {
        assert_eq!(unescape("a &lt;b&gt;<br>&quot;c&quot; &amp; &amp;lt;"), "a <b>\n\"c\" & &lt;");
    }

    // [unit->REQ-UPS-INJECTION]
    #[test]
    fn render_frames_named_entity_multi_nofrom_empty() {
        assert_eq!(
            render_frames("<EVENT type=\"msg\" from=\"doyle\">hello<br>world</EVENT>"),
            "<sptc_messages from=\"doyle\">\nhello\nworld\n</sptc_messages>"
        );
        assert_eq!(
            render_frames("<EVENT type=\"msg\" from=\"kit\">a &lt;tag&gt; &amp; b</EVENT>"),
            "<sptc_messages from=\"kit\">\na <tag> & b\n</sptc_messages>"
        );
        assert_eq!(
            render_frames("<EVENT type=\"msg\" from=\"a\">one</EVENT><EVENT type=\"msg\" from=\"b\">two</EVENT>"),
            "<sptc_messages from=\"a\">\none\n</sptc_messages>\n<sptc_messages from=\"b\">\ntwo\n</sptc_messages>"
        );
        assert_eq!(
            render_frames("<EVENT type=\"msg\">sys note</EVENT>"),
            "<sptc_messages>\nsys note\n</sptc_messages>"
        );
        assert_eq!(render_frames(""), "");
    }

    // [unit->REQ-UPS-INJECTION]
    #[test]
    fn skill_key_cases() {
        assert_eq!(skill_key("/sptc:ready"), "ready");
        assert_eq!(skill_key("/sptc:send doyle hi"), "send");
        assert_eq!(skill_key("   /sptc:setup"), "setup");
        assert_eq!(skill_key("/sptc:list-agents"), "list-agents");
        assert_eq!(skill_key("please run /sptc:ready for me"), "");
        assert_eq!(skill_key("/other:ready"), "");
        assert_eq!(skill_key("ready set go"), "");
        assert_eq!(skill_key(""), "");
    }

    // [unit->REQ-DIST-SHORTCUT-BASENAME]
    #[test]
    fn register_verb_branches() {
        assert_eq!(register_verb("startup", false), "seed");
        assert_eq!(register_verb("", false), "seed");
        assert_eq!(register_verb("clear", false), "boundary");
        assert_eq!(register_verb("compact", false), "boundary");
        assert_eq!(register_verb("startup", true), "bind");
        assert_eq!(register_verb("clear", true), "boundary"); // boundary wins even when spt-hosted
    }

    // [unit->REQ-UPS-INJECTION]
    #[test]
    fn cap_decide_thresholds() {
        assert!(matches!(cap_decide("small body", 9000), Cap::Inline(t) if t == "small body"));
        assert!(matches!(cap_decide("abcdefghij", 5), Cap::Overflow { len: 10 }));
        assert!(matches!(cap_decide("", 5), Cap::Empty));
    }

    // [unit->REQ-DIST-SESSIONSTART-BRIEF]
    #[test]
    fn assemble_perch_structure_and_global_subst() {
        assert_eq!(
            assemble_perch("perri", "you are {id}.", "send body", "roster line"),
            "<sptc-active-perch id=\"perri\">\nyou are perri.\n\nsend body\n\nroster line\n</sptc-active-perch>"
        );
        let multi = assemble_perch("kit", "a {id} b {id}", "m", "r");
        assert!(multi.contains("a kit b kit"), "global subst");
        assert!(!multi.contains("{id}"), "no leftover");
    }

    // [unit->REQ-DIST-SESSIONSTART-BRIEF]
    #[test]
    fn assemble_noperch_structure() {
        assert_eq!(
            assemble_noperch("ring body", "roster line"),
            "<sptc-reach>\nring body\n\nroster line\n</sptc-reach>"
        );
    }

    // [unit->REQ-DIST-SESSIONSTART-BRIEF]
    #[test]
    fn is_subagent_and_peers() {
        assert!(!is_subagent(""));
        assert!(is_subagent("general-purpose"));
        assert!(has_peers("SUBNET NODES ENDPOINTS\nSPT_DEV 3 4\n"));
        assert!(!has_peers("no subnets\n"));
        assert!(!has_peers(""));
    }

    // [unit->REQ-DIST-SESSIONSTART-BRIEF]
    #[test]
    fn json_escape_and_emit() {
        assert_eq!(json_escape("say \"hi\""), "say \\\"hi\\\"");
        assert_eq!(json_escape("a\\b"), "a\\\\b");
        assert_eq!(json_escape("a\nb"), "a\\nb");
        assert_eq!(emit_additional_context(""), "");
        assert_eq!(
            emit_additional_context("hi \"x\""),
            "{\"hookSpecificOutput\":{\"hookEventName\":\"SessionStart\",\"additionalContext\":\"hi \\\"x\\\"\"}}\n"
        );
        assert_eq!(
            emit_additional_context("a\nb"),
            "{\"hookSpecificOutput\":{\"hookEventName\":\"SessionStart\",\"additionalContext\":\"a\\nb\"}}\n"
        );
    }

    // [unit->REQ-DIST-CHECKPOINT-COMMUNE]
    #[test]
    fn checkpoint_detect_and_wake() {
        assert!(has_checkpoint("delta ... !!checkpoint!!"));
        assert!(has_checkpoint("!!checkpoint!! wake !!checkpoint!!"));
        assert!(!has_checkpoint("an ordinary commune delta"));
        assert!(!has_checkpoint(""));
        assert_eq!(checkpoint_wake("work ... !!checkpoint!!"), ""); // single → default
        assert_eq!(checkpoint_wake("body !!checkpoint!! Resume T2c now !!checkpoint!! more"), "Resume T2c now");
        assert_eq!(checkpoint_wake("delta\n!!checkpoint!! wire the hook !!checkpoint!!\nend"), "wire the hook");
        assert_eq!(checkpoint_wake("no markers here"), "");
    }

    // [unit->REQ-DIST-CHECKPOINT-COMMUNE]
    #[test]
    fn commune_write_guard() {
        assert!(is_commune_write("Write", "/home/x/.claude/perri-commune.md", "perri"));
        assert!(is_commune_write("Write", "C:\\\\Users\\\\d\\\\.claude\\\\perri-commune.md", "perri"));
        assert!(!is_commune_write("Write", "/home/x/.claude/notes.md", "perri"));
        assert!(!is_commune_write("Write", "/home/x/.claude/doyle-commune.md", "perri"));
        assert!(!is_commune_write("Edit", "/home/x/.claude/perri-commune.md", "perri"));
        assert!(!is_commune_write("Write", "/home/x/.claude/perri-commune.md", ""));
    }

    // [unit->REQ-DIST-CHECKPOINT-COMMUNE]
    #[test]
    fn checkpoint_payload_shape() {
        assert_eq!(checkpoint_payload(""), "{\"checkpoint\":\"v1\"}");
        assert_eq!(checkpoint_payload("Resume now"), "{\"checkpoint\":\"v1\",\"wake\":\"Resume now\"}");
        assert_eq!(checkpoint_payload("a\"b"), "{\"checkpoint\":\"v1\",\"wake\":\"a\\\"b\"}");
    }

    // [unit->REQ-DIST-RESUME-CONTEXT]
    #[test]
    fn append_resume_cases() {
        assert_eq!(append_resume("<brief/>", "<live-context>ctx</live-context>"), "<brief/>\n<live-context>ctx</live-context>");
        assert_eq!(append_resume("<brief/>", ""), "<brief/>");
        assert_eq!(append_resume("", ""), "");
    }

    // ---- recorder-driven handler tests (ordering / gating / emitted output) ----

    /// A recording [`HookEnv`]: serves canned `spt` output via a responder keyed on the full argv,
    /// records every `spt` call (args only) and every emit, and captures the latest spill.
    struct Recorder {
        responder: Box<dyn Fn(&[&str]) -> Option<String>>,
        calls: Vec<Vec<String>>,
        emitted: Vec<String>,
        spills: Vec<(String, String)>,
        env_lines: Vec<String>,
        envs: std::collections::HashMap<String, String>,
        host_pid: Option<String>,
        cap: usize,
    }

    impl Recorder {
        fn new(responder: impl Fn(&[&str]) -> Option<String> + 'static) -> Self {
            Recorder {
                responder: Box::new(responder),
                calls: Vec::new(),
                emitted: Vec::new(),
                spills: Vec::new(),
                env_lines: Vec::new(),
                envs: std::collections::HashMap::new(),
                host_pid: Some("4242".into()),
                cap: 9000,
            }
        }
        fn with_env(mut self, k: &str, v: &str) -> Self {
            self.envs.insert(k.into(), v.into());
            self
        }
        /// The recorded `spt` call argv strings joined for readable assertions.
        fn call_lines(&self) -> Vec<String> {
            self.calls.iter().map(|c| c.join(" ")).collect()
        }
        fn out(&self) -> String {
            self.emitted.concat()
        }
    }

    impl HookEnv for Recorder {
        fn spt(&mut self, args: &[&str], _stdin: Option<&str>, _extra_env: &[(&str, &str)]) -> Option<String> {
            self.calls.push(args.iter().map(|s| s.to_string()).collect());
            (self.responder)(args)
        }
        fn emit(&mut self, text: &str) {
            self.emitted.push(text.to_string());
        }
        fn write_spill(&mut self, path: &str, content: &str) -> bool {
            self.spills.push((path.to_string(), content.to_string()));
            true
        }
        fn append_env_file(&mut self, line: &str) {
            self.env_lines.push(line.to_string());
        }
        fn env(&self, key: &str) -> Option<String> {
            self.envs.get(key).cloned()
        }
        fn host_pid(&self) -> Option<String> {
            self.host_pid.clone()
        }
        fn home(&self) -> String {
            "/home/x".to_string()
        }
        fn cap(&self) -> usize {
            self.cap
        }
    }

    // [unit->REQ-DIST-WHOAMI-JSON] the doyle bug (2026-07-01): a node with subnet membership makes
    // the HUMAN whoami/list view start with a "SUBNET <name>" header — first-line parsing crowned
    // the agent "SUBNET SPT_DEV" and the injected brief forbade running whoami, so the wrong
    // identity self-reinforced. The load-bearing regression: human-roster input resolves EMPTY.
    #[test]
    fn whoami_human_roster_is_never_an_id() {
        let human = "SUBNET SPT_DEV\n  hall-a  HFENDULEAM (14efb80c…)  ■ ONLINE\nSUBNET BIGNET\n  hall-a  HFENDULEAM (14efb80c…)  ■ ONLINE\nENDPOINTS:2\nThis node: HFENDULEAM (14efb80c…)\n  (no local perches)";
        assert_eq!(parse_whoami_self(human), "", "a grouped roster header must resolve to no-perch");
        // The perched human shape must not leak either — only --json is the contract.
        let perched = "SELF: perri  live_agent  ready=true alive=true\nSUBNET SPT_DEV\n  …";
        assert_eq!(parse_whoami_self(perched), "", "human SELF line is not the contract");
    }

    // [unit->REQ-DIST-WHOAMI-JSON] the --json contract: .self.id when perched, "" on self:null,
    // "" on garbage (defensive — a pre-JSON binary or a transport error must read as no-perch).
    #[test]
    fn whoami_json_self_id_contract() {
        assert_eq!(
            parse_whoami_self(r#"{"self":{"id":"doyle","status":"live_agent","ready":true,"alive":true},"subnets":[]}"#),
            "doyle"
        );
        assert_eq!(parse_whoami_self(r#"{"self":null,"subnets":[{"name":"SPT_DEV"}]}"#), "");
        assert_eq!(parse_whoami_self(""), "");
        assert_eq!(parse_whoami_self("ERROR: daemon unreachable"), "");
        assert_eq!(parse_whoami_self(r#"{"subnets":[]}"#), "", "missing self key reads as no-perch");
    }

    // [unit->REQ-DIST-PRETOOL-POLL]
    #[test]
    fn ups_marks_busy_before_drain_and_includes_deferred() {
        let mut env = Recorder::new(|args| match args {
            ["whoami", "--json"] => Some(r#"{"self":{"id":"perri","status":"live_agent","ready":true,"alive":true}}"#.into()),
            a if a.contains(&"poll") => Some("<EVENT type=\"msg\" from=\"doyle\">hi</EVENT>".into()),
            _ => Some(String::new()),
        });
        handle_user_prompt_submit(&mut env, &json!({"session_id":"s1","prompt":"hello"}));
        let lines = env.call_lines();
        let busy = lines.iter().position(|l| l.contains("state busy")).expect("busy");
        let poll = lines.iter().position(|l| l.contains("poll")).expect("poll");
        assert!(busy < poll, "busy must precede the drain");
        assert!(lines[poll].contains("--include-deferred"), "drain includes deferred");
        assert!(env.out().contains("<sptc_messages from=\"doyle\">"), "rendered drain emitted");
    }

    #[test]
    fn ups_skill_injection_without_perch() {
        // No perch (whoami empty) → no busy/poll, but the skill body still injects.
        let mut env = Recorder::new(|args| match args {
            ["whoami", "--json"] => Some(r#"{"self":null,"subnets":[]}"#.into()),
            ["adapter", "get-string", _, key] if *key == "skills.ready" => Some("# /sptc:ready\nbody".into()),
            _ => Some(String::new()),
        });
        handle_user_prompt_submit(&mut env, &json!({"session_id":"s1","prompt":"/sptc:ready go"}));
        assert!(env.out().starts_with("<sptc_skill name=\"ready\">\n# /sptc:ready"), "skill injected");
        assert!(!env.call_lines().iter().any(|l| l.contains("poll")), "no drain without a perch");
    }

    #[test]
    fn pre_tool_use_noop_without_perch() {
        let mut env = Recorder::new(|args| match args {
            ["whoami", "--json"] => Some(r#"{"self":null,"subnets":[]}"#.into()),
            _ => Some(String::new()),
        });
        handle_pre_tool_use(&mut env, &json!({"session_id":"s1"}));
        assert!(!env.call_lines().iter().any(|l| l.contains("poll")), "no drain");
        assert!(env.out().is_empty());
    }

    // [unit->REQ-DIST-PRETOOL-POLL]
    #[test]
    fn pre_tool_use_busy_before_drain() {
        let mut env = Recorder::new(|args| match args {
            ["whoami", "--json"] => Some(r#"{"self":{"id":"perri","status":"live_agent","ready":true,"alive":true}}"#.into()),
            a if a.contains(&"poll") => Some("<EVENT type=\"msg\" from=\"a\">m</EVENT>".into()),
            _ => Some(String::new()),
        });
        handle_pre_tool_use(&mut env, &json!({"session_id":"s1"}));
        let lines = env.call_lines();
        let busy = lines.iter().position(|l| l.contains("state busy")).expect("busy");
        let poll = lines.iter().position(|l| l.contains("poll")).expect("poll");
        assert!(busy < poll);
        assert!(env.out().contains("<sptc_messages from=\"a\">"));
    }

    #[test]
    fn stop_marks_idle_when_perched_else_noop() {
        let mut env = Recorder::new(|args| match args {
            ["whoami", "--json"] => Some(r#"{"self":{"id":"perri","status":"live_agent","ready":true,"alive":true}}"#.into()),
            _ => Some(String::new()),
        });
        handle_stop(&mut env, &json!({"session_id":"s1"}));
        assert!(env.call_lines().iter().any(|l| l == "api --adapter claude-spt state idle perri --session-id s1"));

        let mut env2 = Recorder::new(|_| Some(String::new())); // whoami empty
        handle_stop(&mut env2, &json!({"session_id":"s1"}));
        assert!(!env2.call_lines().iter().any(|l| l.contains("state idle")));
    }

    #[test]
    fn session_start_seed_path_uses_host_pid_and_writes_env() {
        // No SPT_ENDPOINT_ID, source startup, no peers → seed + env-file writes, no brief.
        let mut env = Recorder::new(|args| match args {
            ["subnet", "status"] => Some("no subnets".into()),
            _ => Some(String::new()),
        });
        handle_session_start(&mut env, &json!({"session_id":"s9","source":"startup"}));
        assert!(env.call_lines().iter().any(|l| l == "api seed --pid 4242 --session-id s9"), "seed by host pid");
        assert!(env.env_lines.iter().any(|l| l == "OWL_SESSION_ID=s9"));
        assert!(env.env_lines.iter().any(|l| l == "SPT_ADAPTER=claude-spt"));
        assert!(env.out().is_empty(), "no brief for a peerless seed");
    }

    #[test]
    fn session_start_bind_path_binds_and_briefs() {
        let mut env = Recorder::new(|args| match args {
            ["adapter", "get-string", _, k] => Some(format!("[{k}]")), // non-empty brief parts
            a if a.contains(&"psyche-download") => Some(String::new()), // NO-CONTEXT
            _ => Some(String::new()),
        })
        .with_env("SPT_ENDPOINT_ID", "cc-1");
        handle_session_start(&mut env, &json!({"session_id":"s1","source":"startup"}));
        assert!(env.call_lines().iter().any(|l| l == "api --adapter claude-spt bind cc-1 --set-session-id s1"), "bind");
        let out = env.out();
        assert!(out.contains("\"hookEventName\":\"SessionStart\""), "emits SessionStart additionalContext");
        assert!(out.contains("sptc-active-perch id=\\\"cc-1\\\""), "perched identity brief for the endpoint id");
    }

    #[test]
    fn session_start_subagent_gets_no_brief() {
        let mut env = Recorder::new(|_| Some("x".into())).with_env("SPT_ENDPOINT_ID", "cc-1");
        handle_session_start(&mut env, &json!({"session_id":"s1","source":"startup","agent_type":"general-purpose"}));
        assert!(env.out().is_empty(), "subagent sessions get no brief");
    }

    // [unit->REQ-DIST-CHECKPOINT-COMMUNE]
    #[test]
    fn post_tool_use_fires_checkpoint_self_send() {
        let mut env = Recorder::new(|_| Some(String::new())).with_env("SPT_ENDPOINT_ID", "perri");
        handle_post_tool_use(
            &mut env,
            &json!({
                "session_id":"s1","tool_name":"Write",
                "tool_input":{"file_path":"/p/.claude/perri-commune.md","content":"delta !!checkpoint!! go now !!checkpoint!! tail"}
            }),
        );
        let lines = env.call_lines();
        assert!(lines.iter().any(|l| l == "api --adapter claude-spt state idle perri --session-id s1"), "idle first");
        assert!(
            lines.iter().any(|l| l == "send --from perri perri --json-payload {\"checkpoint\":\"v1\",\"wake\":\"go now\"}"),
            "self-send carries the custom wake; got {:?}",
            lines
        );
    }

    #[test]
    fn post_tool_use_noop_without_endpoint_or_marker() {
        // No SPT_ENDPOINT_ID → inert (harness-hosted).
        let mut env = Recorder::new(|_| Some(String::new()));
        handle_post_tool_use(&mut env, &json!({"tool_name":"Write","tool_input":{"file_path":"/p/.claude/perri-commune.md","content":"!!checkpoint!!"}}));
        assert!(env.calls.is_empty());

        // spt-hosted but a Write to a non-commune file, or no marker → no self-send.
        let mut env2 = Recorder::new(|_| Some(String::new())).with_env("SPT_ENDPOINT_ID", "perri");
        handle_post_tool_use(&mut env2, &json!({"session_id":"s","tool_name":"Write","tool_input":{"file_path":"/p/.claude/notes.md","content":"!!checkpoint!!"}}));
        assert!(!env2.call_lines().iter().any(|l| l.contains("send --from")));

        let mut env3 = Recorder::new(|_| Some(String::new())).with_env("SPT_ENDPOINT_ID", "perri");
        handle_post_tool_use(&mut env3, &json!({"session_id":"s","tool_name":"Write","tool_input":{"file_path":"/p/.claude/perri-commune.md","content":"ordinary delta"}}));
        assert!(!env3.call_lines().iter().any(|l| l.contains("send --from")));
    }

    #[test]
    fn subagent_start_and_stop() {
        let mut env = Recorder::new(|args| match args {
            ["whoami", "--json"] => Some(r#"{"self":{"id":"parent","status":"live_agent","ready":true,"alive":true}}"#.into()),
            _ => Some(String::new()),
        });
        handle_subagent_start(&mut env, &json!({"session_id":"s1","agent_id":"w7"}));
        assert!(env.call_lines().iter().any(|l| l == "api --adapter claude-spt worker-start parent w7 --session-id s1"));

        let mut env2 = Recorder::new(|_| Some(String::new()));
        handle_subagent_stop(&mut env2, &json!({"session_id":"s1","agent_id":"w7"}));
        assert!(env2.call_lines().iter().any(|l| l == "api --adapter claude-spt worker-stop w7 --session-id s1"));

        // No agent_id → no-op.
        let mut env3 = Recorder::new(|_| Some(String::new()));
        handle_subagent_stop(&mut env3, &json!({"session_id":"s1"}));
        assert!(env3.calls.is_empty());
    }

    #[test]
    fn emit_capped_overflow_spills_full_and_emits_marker_only() {
        let mut env = Recorder::new(|_| Some(String::new()));
        env.cap = 5;
        emit_capped(&mut env, "abcdefghij", "/home/x/.claude/spill.txt");
        assert_eq!(env.spills.len(), 1);
        assert_eq!(env.spills[0].1, "abcdefghij", "full body spilled");
        let out = env.out();
        assert!(out.contains("<sptc_overflow"), "marker emitted");
        assert!(out.contains("bytes=\"10\""));
        assert!(!out.contains("abcdefghij"), "body never inlined in the marker");
    }

    // [unit->REQ-DIST-HOOK-BINARY]
    #[test]
    fn dispatch_routes_known_events_and_noops_unknown() {
        // Every CC event the static hooks.json wires routes to a handler; an event the binary does
        // not yet know is a silent no-op (forward-compat with a newer plugin wiring).
        let mut env = Recorder::new(|args| match args {
            ["whoami", "--json"] => Some(r#"{"self":{"id":"perri","status":"live_agent","ready":true,"alive":true}}"#.into()),
            _ => Some(String::new()),
        });
        dispatch(&mut env, "Stop", &json!({"session_id":"s"}));
        assert!(env.call_lines().iter().any(|l| l.contains("state idle")), "Stop routed");
    }

    #[test]
    fn dispatch_unknown_event_is_noop() {
        let mut env = Recorder::new(|_| Some("x".into()));
        dispatch(&mut env, "FutureEvent", &json!({"session_id":"s"}));
        assert!(env.calls.is_empty());
        assert!(env.out().is_empty());
    }

    // [unit->REQ-HAZARD-HOOKCMD-DISPATCH-LOCKSTEP]
    #[test]
    fn cc_hook_events_recognizer_matches_the_dispatch_arms() {
        // `is_cc_hook_event` is what `main` uses to tell a stale-dispatch skew (`claude-spt <CCEvent>`,
        // degrade + pass-through) from a genuine typo (loud exit 2). Every event `dispatch` has a real
        // arm for MUST be recognised (else a real event misjudged as a typo → brick), and a name with
        // NO dispatch arm must NOT be (else a typo silently swallowed). We assert both directions
        // against the exact set `dispatch` routes — the two lists move in lockstep or this fails.
        let dispatched: &[&str] = &[
            "SessionStart", "UserPromptSubmit", "PreToolUse", "Stop", "SessionEnd", "SubagentStart",
            "SubagentStop", "PostToolUse",
        ];
        assert_eq!(CC_HOOK_EVENTS, dispatched, "CC_HOOK_EVENTS drifted from dispatch's arms");
        for ev in dispatched {
            assert!(is_cc_hook_event(ev), "{ev} has a dispatch arm but is not recognised");
        }
        assert!(!is_cc_hook_event("FutureEvent")); // no arm (dispatch `_ => {}`) → typo branch
        assert!(!is_cc_hook_event("digest")); // a real subcommand is never a hook event
    }
}
