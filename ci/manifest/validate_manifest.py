#!/usr/bin/env python3
"""Validate an adapter manifest (TOML) against spt-core's published manifest.schema.json.

Deterministic, offline: the schema is the vendored copy of spt-core's published v0.7.0
manifest.schema.json (adapter/manifest.schema.json) — no network, no spt binary, no registry
side effects. This is the schema-validation layer only; spt-core's `spt adapter add` adds a
second cross-field registration-validation layer beyond JSON Schema (see the schema description).

Usage:  validate_manifest.py <schema.json> <manifest.toml> [<manifest.toml> ...]
Exit:   0 = all valid · 1 = a manifest failed validation · 2 = usage / missing dependency.

# [impl->REQ-DIST-MANIFEST-SCHEMA]
"""
import json
import sys

# TOML reader: stdlib tomllib (py3.11+) or the tomli backport (py<=3.10). Either covers the fleet.
try:
    import tomllib as _toml  # type: ignore
except ModuleNotFoundError:  # pragma: no cover - depends on interpreter
    try:
        import tomli as _toml  # type: ignore
    except ModuleNotFoundError:
        sys.stderr.write("MISSING-DEP: no TOML reader (need py3.11 tomllib or `pip install tomli`)\n")
        sys.exit(2)

try:
    import jsonschema
except ModuleNotFoundError:  # pragma: no cover
    sys.stderr.write("MISSING-DEP: jsonschema not installed (`pip install jsonschema`)\n")
    sys.exit(2)


def main(argv):
    if len(argv) < 3:
        sys.stderr.write(__doc__.split("\n\n")[2] + "\n")  # the Usage/Exit block
        return 2

    schema_path, manifest_paths = argv[1], argv[2:]
    with open(schema_path, "rb") as fh:
        schema = json.load(fh)

    # Fail fast on a malformed schema rather than silently passing everything.
    validator_cls = jsonschema.validators.validator_for(schema)
    validator_cls.check_schema(schema)
    validator = validator_cls(schema)

    rc = 0
    for manifest_path in manifest_paths:
        with open(manifest_path, "rb") as fh:
            data = _toml.load(fh)
        errors = sorted(validator.iter_errors(data), key=lambda e: list(e.absolute_path))
        if errors:
            rc = 1
            print(f"FAIL: {manifest_path}")
            for err in errors:
                loc = "/".join(str(p) for p in err.absolute_path) or "(root)"
                print(f"  - {loc}: {err.message}")
        else:
            print(f"ok   {manifest_path}")
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv))
