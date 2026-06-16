# PEROS-PLAN — per-OS `adapter.spt` assets (v1: windows + linux)

> JIT plan. Goal: the `adapter.spt` release asset (which carries the platform-native tool binaries)
> ships **per-OS**, and `/sptc:setup` acquires the one matching the host. Scope locked to the two
> OSes that matter now: **windows + linux**. REQ-DIST-ADAPTER-PEROS.

## Why

The `.spt` bundles `claude-spt-digest` + `claude-spt-psyche` (native binaries). One asset can't serve
two OSes. spt's `--release` takes a caller-named `--asset` (default `adapter.spt`) — it does NOT
auto-pick per-OS. So WE name per-OS assets and WE select on the host.

## Decisions

- **Naming:** `adapter-<os>-<arch>.spt`. os ∈ {windows, linux, macos}, arch ∈ {x86_64, aarch64}.
  Derived from `uname -s`/`uname -m` (MINGW*/MSYS*/CYGWIN*→windows, Linux→linux, Darwin→macos;
  arm64/aarch64→aarch64, else x86_64). Overridable via `SPTC_OS`/`SPTC_ARCH` (CI cross-builds).
- **No reliance on the bare `adapter.spt` default** — setup always passes an explicit `--asset`
  (unambiguous across OSes). The runbook attaches every per-OS asset to the one release.
- **Linux binary build — RESOLVED via cargo-zigbuild (2026-06-16).** Bare `cargo build --target
  x86_64-unknown-linux-gnu` fails (`error: linker 'cc' not found`), but **`cargo-zigbuild`** (zig
  supplies the cross-linker) cross-builds Linux ELF binaries from the Windows dev host. `SPTC_TARGET`
  points the packer at `target/<triple>/release`. `dist/adapter-linux-x86_64.spt` now packs locally
  with verified `ELF x86-64 GNU/Linux` binaries. (A native Linux host/runner also works unchanged.)

## Tasks

1. **REQ-DIST-ADAPTER-PEROS** in traceable-reqs.toml — done.
2. **Packer** (`ci/publish/package-adapter.sh`): derive os/arch (override via env), emit
   `adapter-<os>-<arch>.spt`; keep validate-first + dry-run + the root invariant + the
   build-binaries-first guard. `[impl->REQ-DIST-ADAPTER-PEROS]`.
3. **Setup** (`adapter/strings/skills/setup.md` + `plugin/sptc/skills/setup/SKILL.md`): detect os+arch,
   pass `--asset adapter-<os>-<arch>.spt` on the end-user `adapter add --release`. `[doc->…]`.
4. **Unit** (`tests/adapter-archive.sh`): assert the per-OS asset NAME + root invariant. `[unit->…]`.
5. **Runbook** (`docs/RELEASE-RUNBOOK.md`): per-OS publish (build each OS's binaries on that OS, pack,
   attach all to the release) + the Windows-can't-cross-link note. `[doc->…]`.
6. **Linux build script** (`ci/<tool>/build.sh` already portable): confirm they build on Linux
   unchanged (cargo, no `.exe`); document the Linux pack invocation.

## Gate

`sh ci/run-gates.sh` PASS (shell-syntax + unit + traceable-reqs green); the Windows per-OS asset packs
+ validates locally. Linux asset deferred to a Linux build env (documented, not a coverage hole).
