//! `claude-spt translate` — the `[message-idle-translation-binary]` for the claude-spt adapter
//! (spt-core harness-contract v0.13.0+; folded from the standalone cc-spt-idle-translate crate into
//! this subcommand via the v0.16.0 `[message-idle-translation-binary].command` seam — ADR-0006/D3).
//!
//! A lifecycle-managed `stdin -> stdout` JSON-lines filter. spt-core spawns it when the spt-hosted
//! endpoint comes online and reaps it on shutdown; it turns each inbound `<EVENT>` envelope into a
//! sequence of keystroke-commands that spt-core applies ATOMICALLY to the broker-held PTY (live
//! operator input is buffered during emission, so it coexists with an attached `spt rc` controller).
//! Scope is IDLE delivery only — busy/mid-turn injection stays the adapter's `[inject]` hook path.
//!
//! CHECKPOINT BRANCH (agent-driven context reset): an inbound envelope carrying a
//! `json="{"checkpoint":"v1",…}"` attribute (a self-sent signal from the PostToolUse commune hook,
//! via `spt send --json-payload`) fires a `/clear` + wake macro INSTEAD of normal delivery — the
//! agent clearing+rebuilding its own context from its freshest commune. The structured marker lives
//! inside the opaque json attr spt-core carries verbatim, so a normal message can never forge it.
//! See `checkpoint_wake` / `commands_for_checkpoint`. [impl->REQ-DIST-CHECKPOINT-COMMUNE]
//!
//! Input protocol (stdin, one JSON object per line):
//!   {"type":"init","endpoint_id":…,"node":…}   — first message (handshake; no output)
//!   {"type":"event","envelope":"<EVENT…>"}      — one inbound message; the full EVENT envelope
//!   {"type":"input"}                            — content-free ping when the operator types (no output)
//!
//! Output protocol (stdout, one JSON object per line):
//!   {"key":"ctrl+s"}     — keystroke command (Claude Code: STASH the current draft input)
//!   {"key":"enter"}      — keystroke command (submit the PTY line; see SUBMIT note below)
//!   {"delay_ms":50}      — inter-command pause
//!   {"text":"<payload>"} — text injection (the envelope; NO trailing \r — it does not submit CC)
//!   {"commit":true}      — MANDATORY sequence terminator (release the InjectFloor; see below)
//!
//! The per-event choreography delivers the message WITHOUT clobbering a half-typed draft the operator
//! may have in the input box, then terminates the inject sequence:
//!   1. ctrl+s              stash any existing draft
//!   2. delay 50ms          let the stash settle
//!   3. <envelope>          type the envelope (multi-line: a raw \n after the opening tag and before
//!                          the closing </EVENT> — CC soft-newlines a bare \n, so it frames across
//!                          lines without submitting; no trailing CR)
//!   4. delay 50ms          let the text land in CC's input box before the submit key
//!   5. {"key":"enter"}     submit the line
//!   6. {"commit":true}     terminate the inject sequence
//! No trailing restore keystroke: Claude Code AUTO-RESTORES the stashed draft after the submit, so a
//! second ctrl+s would be redundant (it would re-stash, not restore).
//!
//! SUBMIT IS A REAL ENTER KEY, NOT A TRAILING `\r` (corrected 2026-06-23): we previously rode the
//! submit IN the text as a trailing `\r`, on the assumption that spt-core applies `{"text"}` VERBATIM
//! to the PTY (broker.rs:1066, :1016-1017) and a `\r` byte == `{"key":"enter"}`
//! (`key_to_bytes("enter")->b"\r"`). Empirically that is NOT enough: a `\r` byte in injected text does
//! NOT trigger Claude Code's message submission — CC needs the discrete Enter KEY event. So step 5 is
//! now a separate `{"key":"enter"}` after the text lands. The verbatim-text application still REQUIRES
//! `commands_for_event` to neutralize the envelope's INTERNAL CR/LF (an un-neutralized `\n`/`\r` would
//! reach the PTY and could split or corrupt the injection) — only the discrete Enter submits.
//!
//! TWO DISTINCT SIGNALS — do not conflate them:
//!  - The `{"key":"enter"}` in step 5 is the HARNESS-level submit (the discrete keypress CC needs).
//!  - The `{"commit":true}` in step 6 is the PROTOCOL-level terminator: `run_inject_worker`
//!    (broker.rs:1075-1090) ends an inject sequence ONLY on an explicit `{commit}`. Text/Key/Delay
//!    just enqueue; a sequence that emits no `{commit}` hits `INJECT_COMMIT_DEADLINE` (5s,
//!    broker.rs:151-169) and FAULTS on every delivery (reverts to raw inject — input isn't lost but
//!    each delivery stalls to the deadline). `{commit}` flushes the live controller's buffered input
//!    and releases the InjectFloor race-free. Enter submits the line; `{commit}` ends the sequence.
//!
//! Degenerate fallback (per the published contract): `{"text":payload}{"key":"enter"}{"commit":true}`
//! with no choreography — even the bare form MUST commit. (The published manifest doc ORIGINALLY
//! omitted `{commit}` from the vocabulary and its degenerate example — a public-surface defect this
//! adapter's blind-build caught, logged F-016. The contract is now CORRECTED + live:
//! harness-contract/manifest.html documents `{commit}` as the mandatory terminator + the 5s
//! commit-deadline + inject-floor release + raw-inject fallback, since v0.13.0.)
//! We choreograph because Claude Code's input box supports the ctrl+s draft stash/restore, so an
//! inbound message never eats an in-progress draft.
//!
//! Robustness: this is lifecycle-critical — a panic would drop the idle-delivery pipe for the whole
//! session. Malformed lines and unknown `type`s degrade gracefully (skipped, never fatal); unknown
//! JSON fields are ignored (forward-compat with newer spt-core). [impl->REQ-DIST-IDLE-TRANSLATE]

use serde_json::{json, Value};
use std::io::{self, BufRead, Write};
use std::process::ExitCode;

/// Inter-command pause spt-core honors between emitted keystroke/text commands (operator spec).
const DELAY_MS: u64 = 50;

/// Pause after `/clear` submits, before the wake text is typed — `/clear` rebuilds the session and
/// needs longer to settle than a normal inter-command gap (operator spec, checkpoint macro).
const CLEAR_DELAY_MS: u64 = 500;

/// Wake directive used when a checkpoint carries no explicit `wake` (operator-specified default).
const DEFAULT_WAKE: &str = "Proceed with next steps";

/// Extract the raw (still XML-attr-escaped) value of the `json="…"` attribute from an EVENT
/// envelope's opening tag, if present. Returns None when there is no such attribute. The attr value
/// is the structured checkpoint payload spt-core carried verbatim from `spt send --json-payload`
/// (doyle 2026-06-24): spt-core never parses it — it rides as an opaque envelope attribute. We only
/// look inside the opening tag (before the first `>`), and an attr value is XML-escaped so it cannot
/// contain a raw `"`, so the first `"` after `json="` terminates it. [impl->REQ-DIST-CHECKPOINT-COMMUNE]
fn extract_json_attr(envelope: &str) -> Option<String> {
    let gt = envelope.find('>')?; // opening tag ends at the first '>'
    let opening = &envelope[..gt];
    // Leading space ensures we match a real attribute, not a substring of some other name.
    let key = " json=\"";
    let ki = opening.find(key)?;
    let rest = &opening[ki + key.len()..];
    let end = rest.find('"')?;
    Some(rest[..end].to_string())
}

/// Reverse XML attribute escaping. spt-core attr-escapes the `json` value; we must unescape it BEFORE
/// JSON-parsing. `&amp;` is decoded LAST so an embedded `&amp;quot;` does not double-decode (doyle's
/// caveat). This is a SEPARATE escape layer from the message body's `<br>`/HTML-unescape handling.
/// [impl->REQ-DIST-CHECKPOINT-COMMUNE]
fn xml_attr_unescape(s: &str) -> String {
    s.replace("&quot;", "\"")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&amp;", "&") // LAST
}

/// If this envelope carries a `{"checkpoint":"v1", ...}` json attr, return the wake directive (the
/// `wake` field, or DEFAULT_WAKE when absent/blank). Any other shape — no json attr, malformed JSON,
/// a different/absent `checkpoint` marker — returns None so delivery falls through to the normal
/// multi-line path. Collision-proof: the marker lives INSIDE the structured attr value, so a normal
/// message body can never forge it. [impl->REQ-DIST-CHECKPOINT-COMMUNE]
fn checkpoint_wake(envelope: &str) -> Option<String> {
    let raw = extract_json_attr(envelope)?;
    let v: Value = serde_json::from_str(&xml_attr_unescape(&raw)).ok()?;
    if v.get("checkpoint").and_then(Value::as_str) != Some("v1") {
        return None;
    }
    let wake = v
        .get("wake")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .unwrap_or(DEFAULT_WAKE);
    Some(wake.to_string())
}

/// The checkpoint clear+wake macro: stash any lingering draft, submit `/clear` to reset the session,
/// wait for it to settle, then type + submit the wake directive as the first post-clear turn. This is
/// the agent-driven context reset (the operator's manual `/clear` done by the agent itself) — fired
/// when a self-sent checkpoint signal loops back through this binary. Stray CR/LF in the wake collapse
/// to spaces so the wake submits as one turn. Terminated by the mandatory `{commit}` like every
/// sequence. [impl->REQ-DIST-CHECKPOINT-COMMUNE]
fn commands_for_checkpoint(wake: &str) -> Vec<Value> {
    let wake_clean: String = wake
        .chars()
        .map(|c| if c == '\r' || c == '\n' { ' ' } else { c })
        .collect();
    vec![
        json!({ "key": "ctrl+s" }),            // 1. stash any lingering input
        json!({ "delay_ms": DELAY_MS }),       // 2. let the stash settle
        json!({ "text": "/clear" }),           // 3. type the clear command
        json!({ "key": "enter" }),             // 4. submit /clear (resets the session)
        json!({ "delay_ms": CLEAR_DELAY_MS }), // 5. let /clear rebuild before typing the wake
        json!({ "text": wake_clean }),         // 6. type the wake directive
        json!({ "key": "enter" }),             // 7. submit the wake — the first post-checkpoint turn
        json!({ "commit": true }),             // 8. terminate the inject sequence
    ]
}

/// Frame a (CR/LF-sanitized) EVENT envelope across MULTIPLE LINES for visual distinction in CC's
/// input box: a raw `\n` after the opening `<EVENT …>` tag and a raw `\n` before the closing
/// `</EVENT>`, so an inbound idle message renders as
///
/// ```text
/// <EVENT type="msg" from="doyle">
/// body
/// </EVENT>
/// ```
///
/// instead of one dense line. This is safe because spt-core writes `{"text"}` byte-verbatim
/// INCLUDING `\n` (broker.rs:1016-1017, doyle 2026-06-20) and Claude Code SOFT-NEWLINES on a bare
/// `\n` in the input box rather than submitting — empirically gated 2026-06-24 (a two-line `{text}`
/// landed as ONE user turn with the `\n` preserved, no early submit). Cyan/SGR distinction is
/// impossible (CC's input handling eats SGR bytes; user-turns are theme-fixed), so a multi-line
/// plain-text frame is the only viable visual distinction.
///
/// `s` must already have its stray CR/LF neutralized (see `commands_for_event`) — the only newlines
/// in the result are the two we deliberately insert at the structural seams. Degenerate inputs that
/// don't match `<…>…</EVENT>` (e.g. an `<EVENT-PART …>` chunk, or a non-envelope payload) fall back
/// to the single-line form unchanged — never panic, never corrupt. [impl->REQ-DIST-IDLE-MULTILINE]
fn frame_envelope(s: &str) -> String {
    // Opening tag ends at the first '>' (EVENT bodies HTML-escape '>' as &gt;, and attribute values
    // carry no raw '>', so the first '>' is the opening tag's close).
    let Some(gt) = s.find('>') else { return s.to_string() };
    // Closing tag is the last literal "</EVENT>" ("</EVENT-PART>" does not contain it, so EVENT-PART
    // chunks correctly fall through to the single-line form).
    let Some(close) = s.rfind("</EVENT>") else { return s.to_string() };
    // The body sits strictly between the opening '>' and the closing tag.
    if close < gt + 1 {
        return s.to_string();
    }
    let opening = &s[..=gt];
    let body = &s[gt + 1..close];
    let closing = &s[close..];
    format!("{opening}\n{body}\n{closing}")
}

/// Build the keystroke-command sequence for one inbound EVENT envelope.
///
/// `envelope` is the full `<EVENT…>…</EVENT>` string. The envelope is single-line by contract (it
/// encodes newlines as the literal `<br>` token), but we defensively strip any raw CR/LF so a stray
/// newline can never split or corrupt the injection. (Necessary because spt-core applies `{"text"}`
/// verbatim — broker.rs:1066/:1016-1017, doyle 2026-06-20 — so any internal CR/LF would otherwise
/// reach the PTY.) After sanitizing, `frame_envelope` re-inserts exactly two deliberate `\n`s at the
/// opening-tag / body / closing-tag seams to render the message across multiple lines (CC soft-newlines
/// a bare `\n`; empirically gated 2026-06-24). The submit is a DISCRETE `{"key":"enter"}` AFTER the
/// text — a trailing `\r` byte in the text does NOT submit a Claude Code message (corrected
/// 2026-06-23), and the deliberate `\n`s soft-newline rather than submit. The closing `{"commit"}`
/// is the MANDATORY inject-sequence terminator (broker.rs:1075-1090; no-commit FAULTs at the 5s
/// INJECT_COMMIT_DEADLINE). [impl->REQ-DIST-IDLE-TRANSLATE] [impl->REQ-DIST-IDLE-MULTILINE]
fn commands_for_event(envelope: &str) -> Vec<Value> {
    // Checkpoint branch FIRST: a self-sent {"checkpoint":"v1",…} json attr fires the clear+wake macro
    // instead of normal delivery (the agent-driven context reset). Any other envelope falls through.
    if let Some(wake) = checkpoint_wake(envelope) {
        return commands_for_checkpoint(&wake);
    }
    let sanitized: String = envelope
        .chars()
        .map(|c| if c == '\r' || c == '\n' { ' ' } else { c })
        .collect();
    let framed = frame_envelope(&sanitized); // re-insert the two deliberate structural newlines
    vec![
        json!({ "key": "ctrl+s" }),      // 1. stash any existing draft
        json!({ "delay_ms": DELAY_MS }), // 2. let the stash settle
        json!({ "text": framed }),       // 3. type the multi-line envelope — only the framing \n's; NO trailing CR
        json!({ "delay_ms": DELAY_MS }), // 4. let the text land in CC's input box before the submit key
        json!({ "key": "enter" }),       // 5. submit — a real Enter keypress (CC needs the key event, not a \r byte)
        json!({ "commit": true }),       // 6. terminate the inject sequence (release the InjectFloor)
    ]
}

/// Dispatch one parsed input line to its output commands. `init`/`input` (and any unknown `type`)
/// produce nothing; only `event` emits the choreography. Returns an empty vec for no-output lines.
fn commands_for_line(v: &Value) -> Vec<Value> {
    match v.get("type").and_then(Value::as_str) {
        Some("event") => match v.get("envelope").and_then(Value::as_str) {
            Some(env) => commands_for_event(env),
            None => Vec::new(), // event without an envelope: nothing to deliver
        },
        // "init" handshake, "input" operator-typing ping, or any unknown type: no output.
        _ => Vec::new(),
    }
}

/// `claude-spt translate` entry — the [message-idle-translation-binary] stdin->stdout JSON-lines
/// filter (was the cc-spt-idle-translate crate; folded in via the v0.16.0 `command` seam, ADR-0006/D3).
/// Reads no argv: the protocol is entirely stdin/stdout, unchanged from the standalone binary.
pub fn run() -> ExitCode {
    let stdin = io::stdin();
    let stdout = io::stdout();
    let mut out = stdout.lock();

    for line in stdin.lock().lines() {
        let line = match line {
            Ok(l) => l,
            Err(_) => break, // stdin closed/errored: spt-core is tearing us down.
        };
        let trimmed = line.trim();
        if trimmed.is_empty() {
            continue;
        }
        let v: Value = match serde_json::from_str(trimmed) {
            Ok(v) => v,
            Err(e) => {
                // Skip malformed lines — never fatal. stderr lands in spt-core's log, not the PTY.
                eprintln!("claude-spt translate: skipping unparseable line: {e}");
                continue;
            }
        };
        for cmd in commands_for_line(&v) {
            // One compact JSON object per line; flush per command so spt-core applies promptly.
            if writeln!(out, "{cmd}").is_err() || out.flush().is_err() {
                return ExitCode::SUCCESS; // stdout closed: endpoint gone.
            }
        }
    }
    ExitCode::SUCCESS
}

#[cfg(test)]
mod tests {
    use super::*;

    fn keys(cmds: &[Value]) -> Vec<String> {
        cmds.iter()
            .map(|c| {
                if let Some(k) = c.get("key").and_then(Value::as_str) {
                    format!("key:{k}")
                } else if let Some(d) = c.get("delay_ms").and_then(Value::as_u64) {
                    format!("delay:{d}")
                } else if let Some(t) = c.get("text").and_then(Value::as_str) {
                    format!("text:{t}")
                } else if c.get("commit").and_then(Value::as_bool) == Some(true) {
                    "commit".into()
                } else {
                    "?".into()
                }
            })
            .collect()
    }

    #[test]
    fn event_emits_the_stash_submit_commit_choreography() {
        let cmds = commands_for_event("<EVENT type=\"msg\" from=\"doyle\">hi</EVENT>");
        assert_eq!(
            keys(&cmds),
            vec![
                "key:ctrl+s".to_string(),
                "delay:50".to_string(),
                // The envelope is framed across lines: \n after the opening tag, \n before </EVENT>.
                "text:<EVENT type=\"msg\" from=\"doyle\">\nhi\n</EVENT>".to_string(),
                "delay:50".to_string(),
                "key:enter".to_string(),
                "commit".to_string(),
            ]
        );
    }

    // [unit->REQ-DIST-IDLE-MULTILINE]
    #[test]
    fn envelope_is_framed_across_three_lines() {
        // The deliberate visual-distinction frame: opening tag · \n · body · \n · closing tag.
        // CC soft-newlines a bare \n (empirically gated 2026-06-24), so this renders as one user
        // turn spanning three lines, not an early submit.
        let cmds = commands_for_event("<EVENT type=\"msg\" from=\"doyle\">hello there</EVENT>");
        let text = cmds[2].get("text").and_then(Value::as_str).unwrap();
        assert_eq!(
            text,
            "<EVENT type=\"msg\" from=\"doyle\">\nhello there\n</EVENT>"
        );
        // Exactly two deliberate newlines (the structural seams) and zero CR.
        assert_eq!(text.matches('\n').count(), 2, "exactly two framing newlines");
        assert_eq!(text.matches('\r').count(), 0, "no CR");
        // The three lines are: opening tag, body, closing tag.
        let lines: Vec<&str> = text.split('\n').collect();
        assert_eq!(lines[0], "<EVENT type=\"msg\" from=\"doyle\">");
        assert_eq!(lines[1], "hello there");
        assert_eq!(lines[2], "</EVENT>");
    }

    #[test]
    fn frame_envelope_falls_back_on_non_envelope_payloads() {
        // No opening '>' or no closing </EVENT>: leave the text single-line (never panic/corrupt).
        assert_eq!(frame_envelope("plain payload, no tags"), "plain payload, no tags");
        assert_eq!(frame_envelope("<EVENT no close"), "<EVENT no close");
        // An EVENT-PART chunk has no literal "</EVENT>" (it ends "</EVENT-PART>"), so it falls back.
        let part = "<EVENT-PART seq=\"1/2\" id=\"abcd1234\">chunk</EVENT-PART>";
        assert_eq!(frame_envelope(part), part);
        assert!(!frame_envelope(part).contains('\n'), "EVENT-PART stays single-line");
    }

    #[test]
    fn frame_envelope_handles_attrless_and_empty_body() {
        // Attribute-less opening tag still frames on the first '>'.
        assert_eq!(frame_envelope("<EVENT>body</EVENT>"), "<EVENT>\nbody\n</EVENT>");
        // Empty body yields an empty middle line — harmless.
        assert_eq!(frame_envelope("<EVENT></EVENT>"), "<EVENT>\n\n</EVENT>");
    }

    #[test]
    fn sequence_terminates_with_a_mandatory_commit() {
        // broker.rs run_inject_worker ends a sequence ONLY on {commit:true}; without it the broker
        // FAULTs at the 5s INJECT_COMMIT_DEADLINE on every delivery. The terminator MUST be last.
        let cmds = commands_for_event("m");
        assert_eq!(cmds.last().unwrap().get("commit").and_then(Value::as_bool), Some(true));
        // Exactly one commit, and it is the final command (nothing emits after the terminator).
        let commits = cmds.iter().filter(|c| c.get("commit").is_some()).count();
        assert_eq!(commits, 1, "exactly one terminating commit");
    }

    #[test]
    fn no_trailing_restore_keystroke() {
        // CC auto-restores the stashed draft after the submit, so there is EXACTLY ONE ctrl+s (the
        // stash) — never a trailing restore. (The sequence ends with the {commit} terminator.)
        let cmds = commands_for_event("m");
        let ctrl_s = cmds.iter().filter(|c| c.get("key").and_then(Value::as_str) == Some("ctrl+s")).count();
        assert_eq!(ctrl_s, 1, "exactly one ctrl+s (stash only); CC auto-restores");
    }

    #[test]
    fn submit_is_a_discrete_enter_key_not_a_trailing_cr() {
        let cmds = commands_for_event("payload");
        // The text carries NO trailing \r — a \r byte does not submit a Claude Code message.
        let text = cmds[2].get("text").and_then(Value::as_str).unwrap();
        assert_eq!(text, "payload");
        assert!(!text.contains('\r'), "text must NOT carry a submit \\r");
        // The submit is a discrete enter keypress, after the text.
        let enters = cmds.iter().filter(|c| c.get("key").and_then(Value::as_str) == Some("enter")).count();
        assert_eq!(enters, 1, "exactly one enter key (the submit)");
        // ...and it comes AFTER the text command.
        let text_idx = cmds.iter().position(|c| c.get("text").is_some()).unwrap();
        let enter_idx = cmds.iter().position(|c| c.get("key").and_then(Value::as_str) == Some("enter")).unwrap();
        assert!(enter_idx > text_idx, "the enter submit must follow the text");
    }

    #[test]
    fn stash_precedes_the_submit() {
        let cmds = commands_for_event("x");
        // ctrl+s (stash) is FIRST; the text is cmds[2]; enter submits; the {commit} terminator is last.
        assert_eq!(cmds.first().unwrap().get("key").and_then(Value::as_str), Some("ctrl+s"));
        assert!(cmds[2].get("text").is_some());
        assert_eq!(cmds.len(), 6);
    }

    #[test]
    fn raw_newlines_in_envelope_are_neutralized() {
        // A stray CR/LF must not split or corrupt the injection — only the discrete enter submits.
        // A non-envelope payload collapses embedded newlines to spaces and stays single-line.
        let cmds = commands_for_event("a\nb\r\nc");
        let text = cmds[2].get("text").and_then(Value::as_str).unwrap();
        assert_eq!(text, "a b  c");
        assert_eq!(text.matches('\r').count(), 0, "no raw CR survives");
        assert_eq!(text.matches('\n').count(), 0, "no raw LF survives");
    }

    #[test]
    fn stray_newlines_neutralized_then_only_framing_newlines_remain() {
        // STRAY CR/LF inside a real envelope collapse to spaces FIRST; then framing re-inserts
        // EXACTLY the two deliberate structural newlines. No stray newline can split the injection.
        let cmds = commands_for_event("<EVENT type=\"msg\">a\nb\r\nc</EVENT>");
        let text = cmds[2].get("text").and_then(Value::as_str).unwrap();
        assert_eq!(text, "<EVENT type=\"msg\">\na b  c\n</EVENT>");
        assert_eq!(text.matches('\r').count(), 0, "no raw CR survives");
        assert_eq!(text.matches('\n').count(), 2, "only the two framing newlines survive");
    }

    /// Build an EVENT envelope carrying a `json` attr whose value is the XML-attr-escaped form of
    /// `obj` — mirrors what spt-core composes from `spt send --json-payload`.
    fn envelope_with_json(obj: &str) -> String {
        let escaped = obj
            .replace('&', "&amp;")
            .replace('<', "&lt;")
            .replace('>', "&gt;")
            .replace('"', "&quot;");
        format!("<EVENT type=\"msg\" from=\"self\" json=\"{escaped}\">checkpoint</EVENT>")
    }

    // [unit->REQ-DIST-CHECKPOINT-COMMUNE]
    #[test]
    fn checkpoint_json_attr_fires_the_clear_wake_macro() {
        let env = envelope_with_json(r#"{"checkpoint":"v1","wake":"Resume T2c now"}"#);
        let cmds = commands_for_event(&env);
        assert_eq!(
            keys(&cmds),
            vec![
                "key:ctrl+s".to_string(),
                "delay:50".to_string(),
                "text:/clear".to_string(),
                "key:enter".to_string(),
                "delay:500".to_string(),
                "text:Resume T2c now".to_string(),
                "key:enter".to_string(),
                "commit".to_string(),
            ]
        );
    }

    #[test]
    fn checkpoint_without_wake_uses_the_default() {
        let env = envelope_with_json(r#"{"checkpoint":"v1"}"#);
        let cmds = commands_for_event(&env);
        let wake = cmds[5].get("text").and_then(Value::as_str).unwrap();
        assert_eq!(wake, "Proceed with next steps");
        // Blank wake also falls back to the default.
        let env2 = envelope_with_json(r#"{"checkpoint":"v1","wake":"   "}"#);
        let wake2 = commands_for_event(&env2)[5].get("text").and_then(Value::as_str).unwrap().to_string();
        assert_eq!(wake2, "Proceed with next steps");
    }

    #[test]
    fn checkpoint_macro_submits_clear_then_wake_and_commits() {
        let cmds = commands_for_checkpoint("go");
        // /clear is typed+submitted BEFORE the wake text+submit; the 500ms settle sits between them.
        let texts: Vec<&str> = cmds.iter().filter_map(|c| c.get("text").and_then(Value::as_str)).collect();
        assert_eq!(texts, vec!["/clear", "go"]);
        // Two discrete enter submits (clear, wake) and exactly one terminating commit, last.
        let enters = cmds.iter().filter(|c| c.get("key").and_then(Value::as_str) == Some("enter")).count();
        assert_eq!(enters, 2, "two submits: /clear and the wake");
        assert_eq!(cmds.last().unwrap().get("commit").and_then(Value::as_bool), Some(true));
        // The longer post-/clear settle is present.
        assert!(cmds.iter().any(|c| c.get("delay_ms").and_then(Value::as_u64) == Some(500)));
    }

    #[test]
    fn non_checkpoint_envelopes_deliver_normally() {
        // A different marker, a plain message, and a body that merely MENTIONS the token all deliver
        // normally (collision-proof: the marker only counts inside a structured json attr).
        for env in [
            envelope_with_json(r#"{"checkpoint":"v2"}"#),
            envelope_with_json(r#"{"note":"hi"}"#),
            "<EVENT type=\"msg\" from=\"a\">please run a checkpoint v1</EVENT>".to_string(),
            "<EVENT type=\"msg\" from=\"a\">hi</EVENT>".to_string(),
        ] {
            let cmds = commands_for_event(&env);
            // Normal delivery is the 6-step choreography ending text-then-enter-then-commit — NOT the
            // 8-step macro; in particular it never types "/clear".
            assert_eq!(cmds.len(), 6, "normal delivery for: {env}");
            assert!(
                !cmds.iter().any(|c| c.get("text").and_then(Value::as_str) == Some("/clear")),
                "must NOT clear for: {env}"
            );
        }
    }

    #[test]
    fn malformed_checkpoint_json_falls_through_to_normal_delivery() {
        // A json attr that isn't valid JSON must not panic or macro — degrade to normal delivery.
        let env = "<EVENT type=\"msg\" from=\"a\" json=\"{not valid json\">b</EVENT>";
        let cmds = commands_for_event(env);
        assert_eq!(cmds.len(), 6);
        assert!(!cmds.iter().any(|c| c.get("text").and_then(Value::as_str) == Some("/clear")));
    }

    #[test]
    fn xml_attr_unescape_decodes_amp_last() {
        // &amp;quot; must decode to &quot; (one level), not "" — &amp; is applied LAST.
        assert_eq!(xml_attr_unescape("&amp;quot;"), "&quot;");
        assert_eq!(xml_attr_unescape("&quot;&lt;&gt;&amp;"), "\"<>&");
    }

    #[test]
    fn extract_json_attr_pulls_the_attr_value() {
        let env = "<EVENT type=\"msg\" from=\"a\" json=\"&quot;v&quot;\">b</EVENT>";
        assert_eq!(extract_json_attr(env).as_deref(), Some("&quot;v&quot;"));
        // No json attr → None.
        assert_eq!(extract_json_attr("<EVENT type=\"msg\">b</EVENT>"), None);
    }

    #[test]
    fn event_dispatch_via_line() {
        let v: Value = serde_json::from_str(
            r#"{"type":"event","envelope":"<EVENT type=\"msg\" from=\"a\">b</EVENT>"}"#,
        )
        .unwrap();
        let cmds = commands_for_line(&v);
        assert_eq!(cmds.len(), 6);
        assert_eq!(cmds[0].get("key").and_then(Value::as_str), Some("ctrl+s"));
    }

    #[test]
    fn init_and_input_and_unknown_types_emit_nothing() {
        for line in [
            r#"{"type":"init","endpoint_id":"perri","node":"HFENDULEAM"}"#,
            r#"{"type":"input"}"#,
            r#"{"type":"future-thing","x":1}"#,
            r#"{"no_type":true}"#,
        ] {
            let v: Value = serde_json::from_str(line).unwrap();
            assert!(commands_for_line(&v).is_empty(), "no output for: {line}");
        }
    }

    #[test]
    fn event_without_envelope_emits_nothing() {
        let v: Value = serde_json::from_str(r#"{"type":"event"}"#).unwrap();
        assert!(commands_for_line(&v).is_empty());
    }

    #[test]
    fn unknown_fields_are_ignored_forward_compat() {
        // A newer spt-core adding fields must not break dispatch (unknown keys ignored).
        let v: Value = serde_json::from_str(
            r#"{"type":"event","envelope":"<EVENT>z</EVENT>","priority":9,"trace_id":"t"}"#,
        )
        .unwrap();
        assert_eq!(commands_for_line(&v).len(), 6);
    }

    #[test]
    fn output_commands_are_single_field_objects() {
        // Each emitted command is exactly one of the contract shapes (key | delay_ms | text | commit).
        for c in commands_for_event("m") {
            let obj = c.as_object().unwrap();
            assert_eq!(obj.len(), 1, "each command carries exactly one field: {c}");
            let k = obj.keys().next().unwrap().as_str();
            assert!(matches!(k, "key" | "delay_ms" | "text" | "commit"), "unexpected field {k}");
        }
    }
}
