#!/bin/sh
# manifest-schema gate: validate the claude-spt adapter manifest against spt-core's published
# (vendored) manifest.schema.json. Deterministic + offline — no network, no spt binary, no
# registry side effects. Self-announcing: prints its own ok/SKIP/FAIL line.
#   exit 0 = valid OR skipped (no capable interpreter) · exit 1 = manifest failed validation.
# [impl->REQ-DIST-MANIFEST-SCHEMA]
set -u
ROOT=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
SCHEMA="$ROOT/adapter/manifest.schema.json"
MANIFEST="$ROOT/adapter/claude-spt.toml"
VALIDATOR="$ROOT/ci/manifest/validate_manifest.py"

for f in "$SCHEMA" "$MANIFEST" "$VALIDATOR"; do
  if [ ! -f "$f" ]; then echo "SKIP: missing $f"; exit 0; fi
done

# Pick an interpreter that has BOTH a TOML reader (tomllib|tomli) AND jsonschema. The fleet's
# python is 3.12 (tomllib) and python3 is 3.10 (tomli) — either satisfies the validator.
PY=""
for cand in python python3 py; do
  command -v "$cand" >/dev/null 2>&1 || continue
  if "$cand" - <<'PROBE' >/dev/null 2>&1
import importlib.util as u, sys
have_toml = u.find_spec("tomllib") or u.find_spec("tomli")
sys.exit(0 if (have_toml and u.find_spec("jsonschema")) else 1)
PROBE
  then PY="$cand"; break; fi
done

if [ -z "$PY" ]; then
  echo "SKIP: no python with (tomllib|tomli)+jsonschema on PATH (pip install tomli jsonschema)"
  exit 0
fi

if "$PY" "$VALIDATOR" "$SCHEMA" "$MANIFEST"; then
  echo "ok   manifest validates against published manifest.schema.json"
  exit 0
else
  echo "FAIL: manifest does not satisfy manifest.schema.json"
  exit 1
fi
