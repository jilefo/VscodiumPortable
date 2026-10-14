# check-version.ps1 - Version consistency check for VscodiumPortable
#
# Verifies that the version fields are consistent across the three files
# that carry the application version:
#   - build.properties       (app.version / app.release)
#   - versioninfo.json       (StringFileInfo.ProductVersion = <version>.<release>)
#   - bin\build\portapp.json (version / release)
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check-version.ps1 [-RepoRoot <path>]
#
# Exit codes:
#   0 - all version fields are consistent
#   1 - one or more mismatches detected (details printed to stdout/stderr)
#
# Copyright (c) 2019-2026 CrazyMax

param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

function Get-KeyValue {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Key
    )
    $pattern = "^\s*$([regex]::Escape($Key))\s*=\s*(.+?)\s*$"
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match $pattern) {
            return $Matches[1].Trim()
        }
    }
    return $null
}

$buildProps = Join-Path $RepoRoot 'build.properties'
$versionInfo = Join-Path $RepoRoot 'versioninfo.json'
$portappJson = Join-Path $RepoRoot 'bin\build\portapp.json'

foreach ($p in @($buildProps, $versionInfo, $portappJson)) {
    if (-not (Test-Path -LiteralPath $p)) {
        Write-Error "Required file not found: $p"
        exit 1
    }
}

$appVersion = Get-KeyValue $buildProps 'app.version'
$appRelease = Get-KeyValue $buildProps 'app.release'

$vi = Get-Content -LiteralPath $versionInfo -Raw | ConvertFrom-Json
$productVersion = [string]$vi.StringFileInfo.ProductVersion

$pj = Get-Content -LiteralPath $portappJson -Raw | ConvertFrom-Json
$pjVersion = [string]$pj.version
$pjRelease = [string]$pj.release

$expectedProductVersion = "$appVersion.$appRelease"

$errors = @()

if ($appVersion -ne $pjVersion) {
    $errors += "portapp.json version ('$pjVersion') != build.properties app.version ('$appVersion')"
}
if ($appRelease -ne $pjRelease) {
    $errors += "portapp.json release ('$pjRelease') != build.properties app.release ('$appRelease')"
}
if ($productVersion -ne $expectedProductVersion) {
    $errors += "versioninfo.json ProductVersion ('$productVersion') != expected app.version.app.release ('$expectedProductVersion')"
}

if ($errors.Count -gt 0) {
    Write-Host "[check-version] FAIL: version mismatch detected:" -ForegroundColor Red
    foreach ($e in $errors) {
        Write-Host "  - $e" -ForegroundColor Red
    }
    exit 1
}

Write-Host "[check-version] OK: app.version=$appVersion app.release=$appRelease ProductVersion=$productVersion (consistent)"
exit 0
