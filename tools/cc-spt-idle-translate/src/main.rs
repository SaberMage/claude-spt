//! cc-spt-idle-translate — the `[message-idle-translation-binary]` for the claude-spt adapter
//! (spt-core harness-contract v0.13.0+).
//!
//! A lifecycle-managed `stdin -> stdout` JSON-lines filter. spt-core spawns it when the spt-hosted
//! endpoint comes online and reaps it on shutdown; it turns each inbound `<EVENT>` envelope into a
//! sequence of keystroke-commands that spt-core applies ATOMICALLY to the broker-held PTY (live
//! operator input is buffered during emission, so it coexists with an attached `spt rc` controller).
//! Scope is IDLE delivery only — busy/mid-turn injection stays the adapter's `[inject]` hook path.
//!
//! Input protocol (stdin, one JSON object per line):
//!   {"type":"init","endpoint_id":…,"node":…}   — first message (handshake; no output)
//!   {"type":"event","envelope":"<EVENT…>"}      — one inbound message; the full EVENT envelope
//!   {"type":"input"}                            — content-free ping when the operator types (no output)
//!
//! Output protocol (stdout, one JSON object per line):
//!   {"key":"ctrl+s"}     — keystroke command (Claude Code: STASH the current draft input)
//!   {"delay_ms":50}      — inter-command pause
//!   {"text":"<payload>"} — text injection (the envelope; a trailing \r submits it)
//!
//! The per-event choreography (operator-specified) delivers the message WITHOUT clobbering a
//! half-typed draft the operator may have in the input box:
//!   1. ctrl+s              stash any existing draft
//!   2. delay 50ms
//!   3. <envelope>\r        type the envelope, the carriage return submits it
//! No trailing restore keystroke: Claude Code AUTO-RESTORES the stashed draft after the submit, so a
//! second ctrl+s would be redundant (it would re-stash, not restore).
//!
//! spt-core applies a `{"text":…}` command VERBATIM to the PTY — no control-char stripping
//! (broker.rs:1016-1017, doyle-confirmed 2026-06-20). So the trailing `\r` in step 3 IS the submit,
//! exactly equivalent to a separate `{"key":"enter"}` (`key_to_bytes("enter") -> b"\r"`). That same
//! verbatim application is WHY `commands_for_event` must neutralize the envelope's INTERNAL CR/LF —
//! an un-neutralized `\n`/`\r` in the payload would reach the PTY and submit early.
//!
//! Degenerate fallback (per contract): emit `{"text":payload}{"key":"enter"}` with no choreography.
//! We choreograph because Claude Code's input box supports the ctrl+s draft stash/restore, so an
//! inbound message never eats an in-progress draft.
//!
//! Robustness: this is lifecycle-critical — a panic would drop the idle-delivery pipe for the whole
//! session. Malformed lines and unknown `type`s degrade gracefully (skipped, never fatal); unknown
//! JSON fields are ignored (forward-compat with newer spt-core). [impl->REQ-DIST-IDLE-TRANSLATE]

use serde_json::{json, Value};
use std::io::{self, BufRead, Write};

/// Inter-command pause spt-core honors between emitted keystroke/text commands (operator spec).
const DELAY_MS: u64 = 50;

/// Build the keystroke-command sequence for one inbound EVENT envelope.
///
/// `envelope` is the full `<EVENT…>…</EVENT>` string. The envelope is single-line by contract (it
/// encodes newlines as the literal `<br>` token), but we defensively strip any raw CR/LF so a stray
/// newline can never submit early or split the injection — our single trailing `\r` is the ONLY
/// submit. (Necessary because spt-core applies `{"text"}` verbatim — broker.rs:1016-1017, doyle
/// 2026-06-20 — so any internal CR/LF would otherwise reach the PTY.) [impl->REQ-DIST-IDLE-TRANSLATE]
fn commands_for_event(envelope: &str) -> Vec<Value> {
    let sanitized: String = envelope
        .chars()
        .map(|c| if c == '\r' || c == '\n' { ' ' } else { c })
        .collect();
    vec![
        json!({ "key": "ctrl+s" }),                  // 1. stash any existing draft
        json!({ "delay_ms": DELAY_MS }),             // 2. let the stash settle
        json!({ "text": format!("{sanitized}\r") }), // 3. envelope + CR submits; CC auto-restores draft
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

fn main() {
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
                eprintln!("cc-spt-idle-translate: skipping unparseable line: {e}");
                continue;
            }
        };
        for cmd in commands_for_line(&v) {
            // One compact JSON object per line; flush per command so spt-core applies promptly.
            if writeln!(out, "{cmd}").is_err() || out.flush().is_err() {
                return; // stdout closed: endpoint gone.
            }
        }
    }
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
                } else {
                    "?".into()
                }
            })
            .collect()
    }

    #[test]
    fn event_emits_the_stash_then_submit_choreography() {
        let cmds = commands_for_event("<EVENT type=\"msg\" from=\"doyle\">hi</EVENT>");
        assert_eq!(
            keys(&cmds),
            vec![
                "key:ctrl+s".to_string(),
                "delay:50".to_string(),
                "text:<EVENT type=\"msg\" from=\"doyle\">hi</EVENT>\r".to_string(),
            ]
        );
    }

    #[test]
    fn no_trailing_restore_keystroke() {
        // CC auto-restores the stashed draft after the submit, so there is EXACTLY ONE ctrl+s (the
        // stash) and it is the LAST command's predecessor — never a trailing restore.
        let cmds = commands_for_event("m");
        let ctrl_s = cmds.iter().filter(|c| c.get("key").and_then(Value::as_str) == Some("ctrl+s")).count();
        assert_eq!(ctrl_s, 1, "exactly one ctrl+s (stash only); CC auto-restores");
        // The submit (text) is the final command — nothing follows it.
        assert!(cmds.last().unwrap().get("text").is_some(), "last command is the text submit");
    }

    #[test]
    fn submit_is_a_trailing_carriage_return_on_the_text() {
        let cmds = commands_for_event("payload");
        let text = cmds[2].get("text").and_then(Value::as_str).unwrap();
        assert!(text.ends_with('\r'), "text must end with the submit \\r");
        assert_eq!(text, "payload\r");
        // The submit is carried IN the text, not a separate enter key (operator spec: text+\r).
        assert!(cmds.iter().all(|c| c.get("key").and_then(Value::as_str) != Some("enter")));
    }

    #[test]
    fn stash_precedes_the_submit() {
        let cmds = commands_for_event("x");
        // ctrl+s (stash) is FIRST; the text submit is the final command (CC auto-restores after).
        assert_eq!(cmds.first().unwrap().get("key").and_then(Value::as_str), Some("ctrl+s"));
        assert!(cmds[2].get("text").is_some());
        assert_eq!(cmds.len(), 3);
    }

    #[test]
    fn raw_newlines_in_envelope_are_neutralized() {
        // A stray CR/LF must not produce an early submit or split the injection — only the trailing
        // \r submits. Embedded newlines collapse to spaces; the single submit \r is the LAST char.
        let cmds = commands_for_event("a\nb\r\nc");
        let text = cmds[2].get("text").and_then(Value::as_str).unwrap();
        assert_eq!(text, "a b  c\r");
        assert_eq!(text.matches('\r').count(), 1, "exactly one (submit) CR");
        assert_eq!(text.matches('\n').count(), 0, "no raw LF survives");
    }

    #[test]
    fn event_dispatch_via_line() {
        let v: Value = serde_json::from_str(
            r#"{"type":"event","envelope":"<EVENT type=\"msg\" from=\"a\">b</EVENT>"}"#,
        )
        .unwrap();
        let cmds = commands_for_line(&v);
        assert_eq!(cmds.len(), 3);
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
        assert_eq!(commands_for_line(&v).len(), 3);
    }

    #[test]
    fn output_commands_are_single_key_objects() {
        // Each emitted command is exactly one of the contract shapes (key | delay_ms | text).
        for c in commands_for_event("m") {
            let obj = c.as_object().unwrap();
            assert_eq!(obj.len(), 1, "each command carries exactly one field: {c}");
            let k = obj.keys().next().unwrap().as_str();
            assert!(matches!(k, "key" | "delay_ms" | "text"), "unexpected field {k}");
        }
    }
}
