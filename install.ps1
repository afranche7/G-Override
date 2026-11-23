<#
.SYNOPSIS
  Installs the G-Override Helper on Windows (safe to re-run).

.DESCRIPTION
  - Installs AutoHotkey v2 via winget if it's missing
  - Resolves the Claude App's launch id into config.local.ini
  - Registers the Helper to start at login (Startup folder shortcut) and starts it now
  Run with -Doctor to check an existing install without changing anything.

.EXAMPLE
  .\install.ps1
  .\install.ps1 -Doctor
#>
[CmdletBinding()]
param(
    [switch]$Doctor,
    [switch]$SkipSkills,
    [switch]$NoStart
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$HelperScript = Join-Path $Root 'windows\g-override.ahk'
$LocalIni = Join-Path $Root 'config.local.ini'
$StartupShortcut = Join-Path ([Environment]::GetFolderPath('Startup')) 'G-Override.lnk'

function Find-AutoHotkey {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\AutoHotkey\v2\AutoHotkey64.exe'),
        (Join-Path $env:ProgramFiles 'AutoHotkey\v2\AutoHotkey64.exe')
    )
    foreach ($key in 'HKCU:\Software\AutoHotkey', 'HKLM:\Software\AutoHotkey') {
        $dir = (Get-ItemProperty -Path $key -Name InstallDir -ErrorAction SilentlyContinue).InstallDir
        if ($dir) { $candidates += (Join-Path $dir 'v2\AutoHotkey64.exe') }
    }
    $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}

function Get-ClaudeAppId {
    (Get-StartApps | Where-Object { $_.AppID -like 'Claude_*!*' } | Select-Object -First 1).AppID
}

function Get-HelperProcess {
    Get-CimInstance Win32_Process -Filter "Name LIKE 'AutoHotkey%'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*g-override.ahk*' -and $_.CommandLine -notlike '*--check*' }
}

# Minimal INI writer: sets [section] key=value in config.local.ini, keeping everything else.
function Set-LocalIniValue([string]$Section, [string]$Key, [string]$Value) {
    $lines = [System.Collections.Generic.List[string]]::new()
    if (Test-Path $LocalIni) { (Get-Content $LocalIni) | ForEach-Object { $lines.Add($_) } }
    else { $lines.Add('; Machine-specific G-Override overrides (git-ignored). Same sections/keys as config.ini.') }

    $sectionStart = -1
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i].Trim() -ieq "[$Section]") { $sectionStart = $i; break } }
    if ($sectionStart -lt 0) {
        $lines.Add(''); $lines.Add("[$Section]"); $lines.Add("$Key=$Value")
    } else {
        $end = $lines.Count
        for ($i = $sectionStart + 1; $i -lt $lines.Count; $i++) { if ($lines[$i].Trim() -match '^\[.+\]$') { $end = $i; break } }
        $found = $false
        for ($i = $sectionStart + 1; $i -lt $end; $i++) {
            if ($lines[$i] -match "^\s*$([regex]::Escape($Key))\s*=") { $lines[$i] = "$Key=$Value"; $found = $true; break }
        }
        if (-not $found) { $lines.Insert($end, "$Key=$Value") }
    }
    Set-Content -Path $LocalIni -Value $lines -Encoding Unicode  # UTF-16 so AutoHotkey's IniRead handles any characters
}

function Invoke-HelperCheck([string]$Ahk) {
    $out = [IO.Path]::GetTempFileName()
    try {
        $p = Start-Process -FilePath $Ahk -ArgumentList '/ErrorStdOut', "`"$HelperScript`"", '--check' `
            -Wait -PassThru -NoNewWindow -RedirectStandardOutput $out
        [pscustomobject]@{ Ok = ($p.ExitCode -eq 0); Output = (Get-Content $out -Raw) }
    } finally { Remove-Item $out -ErrorAction SilentlyContinue }
}

function Start-Helper([string]$Ahk) {
    # The Helper closes any copy that's already running when it starts.
    Start-Process -FilePath $Ahk -ArgumentList "`"$HelperScript`""
}

function Write-Check([bool]$Ok, [string]$Label, [string]$Hint = '') {
    if ($Ok) { Write-Host "  [ok] $Label" -ForegroundColor Green }
    else { Write-Host "  [!!] $Label" -ForegroundColor Red; if ($Hint) { Write-Host "       $Hint" -ForegroundColor DarkGray } }
    return $Ok
}

function Invoke-Doctor {
    Write-Host "G-Override doctor ($Root)" -ForegroundColor Cyan
    $allOk = $true
    $ahk = Find-AutoHotkey
    $allOk = (Write-Check ([bool]$ahk) "AutoHotkey v2 installed $(if ($ahk) { "($ahk)" })" 'Run .\install.ps1') -and $allOk
    if ($ahk) {
        $check = Invoke-HelperCheck $ahk
        $allOk = (Write-Check $check.Ok 'Config and palette parse' ($check.Output -replace '\s+$', '')) -and $allOk
    }
    $allOk = (Write-Check ([bool](Get-HelperProcess)) 'Helper is running' 'Run .\install.ps1 (or start windows\g-override.ahk)') -and $allOk
    $allOk = (Write-Check (Test-Path $StartupShortcut) 'Starts at login (Startup shortcut)' 'Run .\install.ps1') -and $allOk
    $appId = Get-ClaudeAppId
    $allOk = (Write-Check ([bool]$appId) "Claude App found $(if ($appId) { "($appId)" })" 'Install the Claude desktop app from https://claude.ai/download') -and $allOk
    if ($allOk) { Write-Host 'All good.' -ForegroundColor Green } else { Write-Host 'Some checks failed.' -ForegroundColor Yellow }
    return $allOk
}

if ($Doctor) {
    if (Invoke-Doctor) { exit 0 } else { exit 1 }
}

Write-Host 'Installing G-Override (Windows)...' -ForegroundColor Cyan

# 1. AutoHotkey v2
$ahk = Find-AutoHotkey
if (-not $ahk) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'AutoHotkey v2 is missing and winget is unavailable. Install it from https://www.autohotkey.com and re-run.'
    }
    Write-Host '  Installing AutoHotkey v2 via winget...'
    winget install --id AutoHotkey.AutoHotkey -e --source winget --accept-package-agreements --accept-source-agreements --silent | Out-Host
    $ahk = Find-AutoHotkey
    if (-not $ahk) { throw 'AutoHotkey v2 install did not complete. Install it from https://www.autohotkey.com and re-run.' }
}
Write-Host "  AutoHotkey: $ahk"

# 2. Claude App launch id
$appId = Get-ClaudeAppId
if ($appId) {
    Set-LocalIniValue 'claude' 'windows_app_id' $appId
    Write-Host "  Claude App: $appId"
} else {
    Write-Warning 'Claude desktop app not found. G6 will not be able to launch it until it is installed (https://claude.ai/download). Re-run this installer afterwards.'
}

# 3. Validate config before wiring anything up
$check = Invoke-HelperCheck $ahk
if (-not $check.Ok) { throw "Config check failed:`n$($check.Output)" }

# 4. Start at login
$shell = New-Object -ComObject WScript.Shell
$lnk = $shell.CreateShortcut($StartupShortcut)
$lnk.TargetPath = $ahk
$lnk.Arguments = "`"$HelperScript`""
$lnk.WorkingDirectory = $Root
$lnk.Description = 'G-Override: G502 G6/G7/G8 -> Claude'
$lnk.Save()
Write-Host "  Starts at login: $StartupShortcut"

# 5. Start (or restart) the Helper now
if (-not $NoStart) {
    Start-Helper $ahk
    Write-Host '  Helper started.'
}

Write-Host ''
Write-Host 'Tip (VS Code): G7 with nothing selected should snip, but VS Code copies the whole line on an' -ForegroundColor DarkGray
Write-Host '  empty selection. Turn that off: Settings > "editor.emptySelectionClipboard" = false.' -ForegroundColor DarkGray
Write-Host ''
Write-Host 'Done. Next: in G HUB, map G6/G7/G8 to F17/F18/F19 in the mouse''s Onboard Profile and turn on onboard memory mode,' -ForegroundColor Green
Write-Host 'then check everything with: .\install.ps1 -Doctor' -ForegroundColor Green
