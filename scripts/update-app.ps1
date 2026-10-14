# update-app.ps1 - Manual version bump helper for VscodiumPortable
#
# Reads the current version from build.properties, prompts for a new VSCodium
# version and release number, updates build.properties and versioninfo.json,
# runs the version consistency check and prints the next steps (download URL
# and packaging command) for a manual release.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\update-app.ps1 [-RepoRoot <path>]
#
# Copyright (c) 2019-2026 CrazyMax

param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

$buildProps = Join-Path $RepoRoot 'build.properties'
$versionInfo = Join-Path $RepoRoot 'versioninfo.json'
$checkScript = Join-Path $RepoRoot 'scripts\check-version.ps1'

foreach ($p in @($buildProps, $versionInfo)) {
    if (-not (Test-Path -LiteralPath $p)) {
        Write-Error "Required file not found: $p"
        exit 1
    }
}

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

# --- Current version -------------------------------------------------------
$currentVersion = Get-KeyValue $buildProps 'app.version'
$currentRelease = Get-KeyValue $buildProps 'app.release'
Write-Host "Current version: app.version=$currentVersion app.release=$currentRelease"

# --- Prompt for new version ------------------------------------------------
$newVersion = Read-Host "New VSCodium version (e.g. 1.141.07001; Enter to keep $currentVersion)"
if ([string]::IsNullOrWhiteSpace($newVersion)) {
    $newVersion = $currentVersion
}
$newRelease = Read-Host "New release number (e.g. 61; Enter to keep $currentRelease)"
if ([string]::IsNullOrWhiteSpace($newRelease)) {
    $newRelease = $currentRelease
}

if ($newVersion -eq $currentVersion -and $newRelease -eq $currentRelease) {
    Write-Host "No version change requested. Aborting." -ForegroundColor Yellow
    exit 0
}

# --- Update build.properties ------------------------------------------------
$content = Get-Content -LiteralPath $buildProps
$content = $content | ForEach-Object {
    $line = $_
    if ($line -match "^\s*app\.version\s*=") { "app.version = $newVersion" }
    elseif ($line -match "^\s*app\.release\s*=") { "app.release = $newRelease" }
    else { $line }
}
# Write without BOM: Set-Content -Encoding UTF8 emits a BOM which breaks
# Ant Properties parsing of build.properties.
[System.IO.File]::WriteAllLines($buildProps, $content, (New-Object System.Text.UTF8Encoding($false)))

# --- Update versioninfo.json (ProductVersion = <version>.<release>) ---------
$viContent = Get-Content -LiteralPath $versionInfo -Raw
$newProductVersion = "$newVersion.$newRelease"
$viContent = $viContent -replace '("ProductVersion"\s*:\s*")[^"]*(")', "`${1}$newProductVersion`${2}"
# Write without BOM (same reason as build.properties above).
[System.IO.File]::WriteAllText($versionInfo, $viContent, (New-Object System.Text.UTF8Encoding($false)))

# --- Consistency check ------------------------------------------------------
Write-Host "Running version consistency check..."
& $checkScript -RepoRoot $RepoRoot
if ($LASTEXITCODE -ne 0) {
    Write-Host "Version consistency check FAILED. Please review the changes." -ForegroundColor Red
    exit 1
}

# --- Print next steps --------------------------------------------------------
# Resolve the download URL template from the updated build.properties
$props = @{}
foreach ($line in Get-Content -LiteralPath $buildProps) {
    if ($line -match "^\s*([A-Za-z0-9_.\-]+)\s*=\s*(.+?)\s*$") {
        $props[$Matches[1]] = $Matches[2]
    }
}
$url = $props['atf.win64.url']
# Resolve ${...} placeholders (loop twice to cover nested references)
for ($i = 0; $i -lt 4; $i++) {
    $resolved = $false
    foreach ($k in $props.Keys) {
        $placeholder = '${' + $k + '}'
        if ($url -like "*$placeholder*") {
            $url = $url.Replace($placeholder, $props[$k])
            $resolved = $true
        }
    }
    if (-not $resolved) { break }
}

$filename = $props['atf.win64.filename'] + $props['atf.win64.ext']

Write-Host ""
Write-Host "Version bumped to: $newVersion-$newRelease" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps for a manual release:" -ForegroundColor Cyan
Write-Host "  1. Download the official archive:"
Write-Host "     $url"
Write-Host "     (expected filename: $filename)"
Write-Host "  2. Place the archive next to the project and update CHANGELOG.md with a new entry."
Write-Host "  3. Build and package:"
Write-Host "     ant release   # requires Apache Ant and the portapps core (D:\Projects\portapps)"
Write-Host "     # or manually:"
Write-Host "     #   7za a -y -mx=1 -r bin\release\vscodiumportable-win64-$newVersion-$newRelease.7z .\bin\build\*"
Write-Host "  4. Regenerate checksums.txt (see build.xml 'release' target / hashfolder)."
