# sptc SessionStart bootstrap (PowerShell/Windows) — install spt-core on demand if absent.
# Verbatim against the published contract: spt-releases harness-contract/install-on-demand.md.
# The invisible-installer pattern: a user who installs the sptc plugin gets spt-core for free.
# [impl->REQ-DIST-BOOTSTRAP-INSTALL]
if (-not (Get-Command spt -ErrorAction SilentlyContinue)) {
    Write-Output "spt-core not found - installing..."
    irm https://sabermage.github.io/spt-releases/install.ps1 | iex
    # Windows PATH registration doesn't affect the current process — use the absolute path first.
    $spt = Join-Path $env:LOCALAPPDATA 'spt-core\bin\spt.exe'
} else {
    $spt = 'spt'
}

& $spt --version
# After this initial bootstrap, `spt update` handles signed self-updates automatically.
