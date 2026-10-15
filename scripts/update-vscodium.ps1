# update-vscodium.ps1 - One-click local update helper for VscodiumPortable
#
# Run this when you open the project and want to check whether upstream
# VSCodium has published a newer stable release.
#
# What it does:
#   1. Reads the current version from build.properties
#   2. Queries the upstream VSCodium releases (same filter rules as
#      .github/workflows/auto-update.yml, so both agree on what "latest
#      stable" means)
#   3. Compares semantically and reports
#        - already up to date  -> nothing to do
#        - update available    -> asks what you want to do next
#
# Options offered when an update is available:
#   [1] Trigger the GitHub auto-update workflow (recommended)
#       Dispatches .github/workflows/auto-update.yml on the current branch.
#       CI then bumps the version, pushes commit + tag with the PAT and
#       publishes the Release. Nothing is modified locally.
#   [2] Bump the version files locally only
#       Updates build.properties + versioninfo.json, then runs the existing
#       version consistency check. Does not build or publish anything.
#   [3] Do nothing
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\update-vscodium.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\update-vscodium.ps1 -CheckOnly
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\update-vscodium.ps1 -WorkflowOnly
#
# Exit codes:
#   0 - up to date, or the chosen action completed successfully
#   1 - an error occurred (network, missing file, failed check, ...)
#   2 - an update is available and -CheckOnly was used
#
# Requires: PowerShell 5.1+ (Windows PowerShell or PowerShell Core).
# Option [1] additionally needs git credentials able to dispatch workflows
# on the remote repository.
#
# Copyright (c) 2019-2026 CrazyMax

param(
    # Repository root. Defaults to the parent of the scripts directory.
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),

    # Only report the state, never offer or perform any action.
    # Exits with 2 when an update is available (useful for scheduled checks).
    [switch]$CheckOnly,

    # Never prompt. If an update is available, trigger the GitHub workflow.
    # Suitable for double-click / shortcut usage.
    [switch]$WorkflowOnly
)

$ErrorActionPreference = 'Stop'

# --- Configuration -----------------------------------------------------------

$buildProps    = Join-Path $RepoRoot 'build.properties'
$versionInfo   = Join-Path $RepoRoot 'versioninfo.json'
$checkScript   = Join-Path $RepoRoot 'scripts\check-version.ps1'
$workflowFile  = '.github/workflows/auto-update.yml'

$UpstreamOwner = 'VSCodium'
$UpstreamRepo  = 'vscodium'
$ArchiveName   = 'VSCodium-win32-x64-{0}.zip'   # {0} = upstream tag

$ApiBase       = 'https://api.github.com'
$ApiHeaders    = @{ 'User-Agent' = 'VscodiumPortable-update-helper'; 'Accept' = 'application/vnd.github+json' }

# --- Small helpers -----------------------------------------------------------

function Write-Head {
    param([string]$Text)
    Write-Host ''
    Write-Host "=== $Text ===" -ForegroundColor Cyan
}

function Get-Property {
    <# Reads a key from a .properties style file. #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Key
    )
    $pattern = "^\s*$([regex]::Escape($Key))\s*=\s*(.+?)\s*$"
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match $pattern) { return $Matches[1].Trim() }
    }
    return $null
}

function Compare-Version {
    <#
        Semantic-ish numeric comparison used by the GitHub workflow as well.
        Returns -1 / 0 / 1 for left < / == / > right.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Left,
        [Parameter(Mandatory = $true)][string]$Right
    )
    $l = $Left.Split('.')  | ForEach-Object { [int]$_ }
    $r = $Right.Split('.') | ForEach-Object { [int]$_ }
    $len = [Math]::Max($l.Count, $r.Count)
    for ($i = 0; $i -lt $len; $i++) {
        $lv = if ($i -lt $l.Count) { $l[$i] } else { 0 }
        $rv = if ($i -lt $r.Count) { $r[$i] } else { 0 }
        if ($lv -ne $rv) { return [Math]::Sign($lv - $rv) }
    }
    return 0
}

function Test-VersionShape {
    param([string]$Value)
    return $Value -match '^\d+(\.\d+){2,3}$'
}

function Get-LatestStableUpstream {
    <#
        Mirrors candidateFromRelease() in auto-update.yml:
        skip draft / prerelease / alpha|beta|preview|rc, require a numeric
        3-4 segment tag and the matching win32-x64 ZIP asset.

        GitHub returns releases newest-first, so the first release passing
        every filter IS the latest stable one and we can stop there.

        Note: a VSCodium release carries ~180 assets, so per_page=100 makes
        Invoke-RestMethod build an enormous object graph. Keep this small.
    #>
    param([int]$PerPage = 10)

    $url = "$ApiBase/repos/$UpstreamOwner/$UpstreamRepo/releases?per_page=$PerPage"
    $releases = Invoke-RestMethod -Uri $url -Headers $ApiHeaders -Method Get

    foreach ($release in $releases) {
        if ($release.draft -eq $true -or $release.prerelease -eq $true) { continue }
        $name = "$($release.name) $($release.tag_name)"
        if ($name -match '(alpha|beta|preview|rc)') { continue }
        $tag = [string]$release.tag_name
        if (-not (Test-VersionShape $tag)) { continue }

        $wanted = $ArchiveName -f $tag
        $asset = $release.assets | Where-Object { $_.name -eq $wanted } | Select-Object -First 1
        if (-not $asset) { continue }

        return [pscustomobject]@{
            Version     = $tag
            PublishedAt = $release.published_at
            DownloadUrl = $asset.browser_download_url
        }
    }

    return $null
}

function Invoke-GitSafely {
    <#
        Runs git and returns stdout only. git reports problems on stderr, which
        becomes a terminating error while $ErrorActionPreference is 'Stop', so
        redirect stderr into the pipeline and filter the noise out.
    #>
    param([string[]]$Arguments)

    $previousEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = & git @Arguments 2>&1
        return @($output | Where-Object {
            $_ -is [string] -and $_ -notmatch '^(fatal:|error:)'
        })
    } catch {
        return @()
    } finally {
        $ErrorActionPreference = $previousEap
    }
}

function Get-GitHubToken {
    <#
        Resolves a token without ever writing it to disk or echoing it.
        Order: GITHUB_TOKEN env var, then GH_TOKEN, then the git credential
        helper (same source `git push` uses).
    #>
    foreach ($var in @('GITHUB_TOKEN', 'GH_TOKEN')) {
        $v = [Environment]::GetEnvironmentVariable($var)
        if (-not [string]::IsNullOrWhiteSpace($v)) { return $v }
    }
    try {
        $helper = @(Invoke-GitSafely -Arguments @('config', '--get', 'credential.helper'))
        if ($helper.Count -gt 0) {
            $filled = @('protocol=https', 'host=github.com', '') | & git credential fill 2>$null
            foreach ($line in $filled) {
                if ("$line" -like 'password=*') { return ("$line").Substring(9).Trim() }
            }
        }
    } catch {
        # Credential helper unavailable; fall through to $null.
    }
    return $null
}

function Invoke-AutoUpdateWorkflow {
    param([string]$Token, [string]$Ref)

    $headers = @{
        'Authorization'        = "Bearer $Token"
        'Accept'               = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = '2022-11-28'
    }
    $url = "$ApiBase/repos/$UpstreamOwner/$UpstreamRepo"
    # Resolve the actual owning repo from the origin remote so forks work too.
    $origin = @(Invoke-GitSafely -Arguments @('-C', $RepoRoot, 'remote', 'get-url', 'origin'))
    if ($origin.Count -gt 0) {
        $originUrl = "$($origin[0])".Trim()
        if ($originUrl -match 'github\.com[:/](.+?)(?:\.git)?$') { $url = "$ApiBase/repos/$($Matches[1])" }
    }

    $body = @{ ref = $Ref } | ConvertTo-Json -Compress
    $headers['Content-Type'] = 'application/json'

    try {
        Invoke-RestMethod -Uri "$url/actions/workflows/auto-update.yml/dispatches" `
            -Headers $headers -Method Post -Body $body | Out-Null
    } catch {
        Write-Host "[update-vscodium] Failed to dispatch the workflow: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Check that the token has 'repo' scope and the workflow exists at $workflowFile." -ForegroundColor Yellow
        return $false
    }

    Write-Host "[update-vscodium] Workflow dispatched on ref '$Ref'." -ForegroundColor Green
    Write-Host "  Watch it here: $url/actions/workflows/auto-update.yml" -ForegroundColor DarkGray
    Write-Host "  It will bump the version, push commit + tag and publish the Release." -ForegroundColor DarkGray
    return $true
}

function Get-DominantLineEnding {
    <# Returns "`r`n" when the file mostly uses CRLF, otherwise "`n". #>
    param([Parameter(Mandatory = $true)][string]$Path)
    $raw = [System.IO.File]::ReadAllText($Path)
    $crlf = ([regex]::Matches($raw, "`r`n")).Count
    $lf   = ([regex]::Matches($raw, "(?<!`r)`n")).Count
    if ($crlf -gt $lf) { return "`r`n" }
    return "`n"
}

function Invoke-LocalBump {
    param([string]$NewVersion, [int]$NewRelease)

    # --- build.properties: rewrite app.version / app.release, no BOM --------
    $lines = Get-Content -LiteralPath $buildProps
    $lines = $lines | ForEach-Object {
        if ($_ -match '^\s*app\.version\s*=') { "app.version = $NewVersion" }
        elseif ($_ -match '^\s*app\.release\s*=') { "app.release = $NewRelease" }
        else { $_ }
    }
    # Write without BOM: Set-Content -Encoding UTF8 emits a BOM which breaks
    # Ant Properties parsing of build.properties.
    [System.IO.File]::WriteAllLines($buildProps, $lines, (New-Object System.Text.UTF8Encoding($false)))

    # --- versioninfo.json: keep ProductVersion and FileVersion in sync -------
    # Preserve the file's existing line endings so the diff stays minimal.
    $viEol = Get-DominantLineEnding -Path $versionInfo
    $vi = Get-Content -LiteralPath $versionInfo -Raw | ConvertFrom-Json
    $parts = @($NewVersion.Split('.') | ForEach-Object { [int]$_ })
    while ($parts.Count -lt 3) { $parts += 0 }
    $vi.FixedFileInfo.FileVersion.Major = $parts[0]
    $vi.FixedFileInfo.FileVersion.Minor = $parts[1]
    $vi.FixedFileInfo.FileVersion.Patch = $parts[2]
    $vi.FixedFileInfo.FileVersion.Build = $NewRelease
    $vi.StringFileInfo.ProductVersion = "$NewVersion.$NewRelease"
    $vi.StringFileInfo.FileVersion    = "$NewVersion.$NewRelease"
    $json = ($vi | ConvertTo-Json -Depth 10)
    $json = $json -replace "(?<!`r)`n", $viEol
    [System.IO.File]::WriteAllText($versionInfo, $json + $viEol, (New-Object System.Text.UTF8Encoding($false)))

    # --- bin\build\portapp.json: carries version/release too ----------------
    # check-version.ps1 compares this file, so keep it in sync when present.
    $portappJson = Join-Path $RepoRoot 'bin\build\portapp.json'
    if (Test-Path -LiteralPath $portappJson) {
        $pjEol = Get-DominantLineEnding -Path $portappJson
        $pj = Get-Content -LiteralPath $portappJson -Raw | ConvertFrom-Json
        $pj.version = $NewVersion
        $pj.release = [string]$NewRelease
        $pjJson = ($pj | ConvertTo-Json -Depth 10) -replace "(?<!`r)`n", $pjEol
        [System.IO.File]::WriteAllText($portappJson, $pjJson + $pjEol, (New-Object System.Text.UTF8Encoding($false)))
    }

    # --- Consistency check ---------------------------------------------------
    if (Test-Path -LiteralPath $checkScript) {
        Write-Host ''
        Write-Host 'Running version consistency check...' -ForegroundColor DarkGray
        & $checkScript -RepoRoot $RepoRoot
        if ($LASTEXITCODE -ne 0) {
            Write-Host '[update-vscodium] Consistency check FAILED. Review the changes with: git diff' -ForegroundColor Red
            return $false
        }
    }

    Write-Host ''
    Write-Host "[update-vscodium] Bumped locally to $NewVersion-$NewRelease." -ForegroundColor Green
    Write-Host '  Changed: build.properties, versioninfo.json' -ForegroundColor DarkGray
    if (Test-Path -LiteralPath $portappJson) {
        Write-Host '           bin\build\portapp.json' -ForegroundColor DarkGray
    }
    Write-Host '  Nothing was committed, pushed or published. Review then run:' -ForegroundColor DarkGray
    Write-Host "    git diff" -ForegroundColor DarkGray
    Write-Host "    git commit -am 'Update VSCodium to $NewVersion'" -ForegroundColor DarkGray
    return $true
}

# --- Main --------------------------------------------------------------------

if (-not (Test-Path -LiteralPath $buildProps)) {
    Write-Error "build.properties not found: $buildProps"
    exit 1
}

Write-Head 'VSCodiumPortable update check'

$currentVersion = Get-Property $buildProps 'app.version'
$currentRelease = Get-Property $buildProps 'app.release'

if (-not $currentVersion) {
    Write-Error 'app.version missing from build.properties'
    exit 1
}
if (-not $currentRelease) { $currentRelease = '0' }

Write-Host "Local version : $currentVersion (release $currentRelease)"

Write-Host 'Querying upstream VSCodium releases...' -ForegroundColor DarkGray
try {
    $latest = Get-LatestStableUpstream
} catch {
    Write-Host "[update-vscodium] Could not reach the GitHub API: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host '  Check your network connection and try again.' -ForegroundColor Yellow
    exit 1
}

if (-not $latest) {
    Write-Host '[update-vscodium] No stable upstream release with a win32-x64 ZIP was found.' -ForegroundColor Yellow
    exit 1
}

Write-Host "Upstream latest: $($latest.Version)  ($($latest.PublishedAt))"

$cmp = Compare-Version $latest.Version $currentVersion

if ($cmp -le 0) {
    Write-Host ''
    Write-Host '[update-vscodium] Already up to date. Nothing to do.' -ForegroundColor Green
    exit 0
}

Write-Host ''
Write-Host "[update-vscodium] Update available: $currentVersion -> $($latest.Version)" -ForegroundColor Yellow

if ($CheckOnly) {
    Write-Host '  (-CheckOnly: reporting only, no action taken)' -ForegroundColor DarkGray
    exit 2
}

# Resolve the target ref for a workflow dispatch.
$refOut = @(Invoke-GitSafely -Arguments @('-C', $RepoRoot, 'rev-parse', '--abbrev-ref', 'HEAD'))
$ref = if ($refOut.Count -gt 0) { "$($refOut[0])".Trim() } else { '' }
if ([string]::IsNullOrWhiteSpace($ref)) { $ref = 'master' }

if ($WorkflowOnly) {
    $token = Get-GitHubToken
    if (-not $token) {
        Write-Host '[update-vscodium] No GitHub token available (GITHUB_TOKEN / GH_TOKEN / git credential helper).' -ForegroundColor Red
        Write-Host '  Use the interactive mode to bump the version files locally instead.' -ForegroundColor Yellow
        exit 1
    }
    if (Invoke-AutoUpdateWorkflow -Token $token -Ref $ref) { exit 0 }
    exit 1
}

# --- Interactive choice ------------------------------------------------------

Write-Host ''
Write-Host 'What would you like to do?' -ForegroundColor Cyan
Write-Host '  [1] Trigger the GitHub auto-update workflow  (recommended: full CI build + Release)'
Write-Host '  [2] Bump version files locally only             (no CI, nothing published)'
Write-Host '  [3] Cancel'
$choice = Read-Host 'Choice [1-3]'

switch ($choice.Trim()) {
    '1' {
        $token = Get-GitHubToken
        if (-not $token) {
            Write-Host '[update-vscodium] No GitHub token available (GITHUB_TOKEN / GH_TOKEN / git credential helper).' -ForegroundColor Red
            Write-Host '  Create a PAT with repo scope, or choose option 2 to bump locally.' -ForegroundColor Yellow
            exit 1
        }
        if (Invoke-AutoUpdateWorkflow -Token $token -Ref $ref) { exit 0 }
        exit 1
    }
    '2' {
        $newRelease = [int]$currentRelease + 1
        if (Invoke-LocalBump -NewVersion $latest.Version -NewRelease $newRelease) { exit 0 }
        exit 1
    }
    default {
        Write-Host '[update-vscodium] Cancelled.' -ForegroundColor DarkGray
        exit 0
    }
}