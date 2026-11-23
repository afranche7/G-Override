# Main Flow skills detection and install step, dot-sourced by install.ps1 (and by windows\tests\TestSkills.ps1).

# Reads [section] key from config.local.ini, falling back to config.ini (names are case-insensitive).
function Get-IniValue([string]$Root, [string]$Section, [string]$Key) {
    foreach ($name in 'config.local.ini', 'config.ini') {
        $path = Join-Path $Root $name
        if (-not (Test-Path $path)) { continue }
        $inSection = $false
        foreach ($line in (Get-Content $path)) {
            $t = $line.Trim()
            if ($t -match '^[;#]') { continue }
            if ($t -match '^\[(.+)\]$') { $inSection = ($Matches[1].Trim() -ieq $Section); continue }
            if ($inSection -and $t -match '^([^=]+)=(.*)$' -and $Matches[1].Trim() -ieq $Key) { return $Matches[2].Trim() }
        }
    }
    return $null
}

function Get-MainFlowSkills([string]$Root) {
    $list = Get-IniValue $Root 'skills' 'main_flow'
    if (-not $list) { return @() }
    @($list -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

# A skill is present as a user skill (<home>\.claude\skills or <home>\.agents\skills, where npx skills installs)
# or inside an installed plugin (<home>\.claude\plugins\cache, or the Claude desktop app's own plugin folder
# <home>\AppData\Roaming\Claude\rpm), at any depth.
function Test-SkillPresent([string]$Name, [string]$UserHome) {
    foreach ($dir in '.claude\skills', '.agents\skills') {
        if (Test-Path (Join-Path $UserHome "$dir\$Name\SKILL.md")) { return $true }
    }
    foreach ($dir in '.claude\plugins\cache', 'AppData\Roaming\Claude\rpm') {
        $root = Join-Path $UserHome $dir
        if (-not (Test-Path $root)) { continue }
        $hit = Get-ChildItem -Path $root -Recurse -Filter SKILL.md -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Directory.Name -ieq $Name } | Select-Object -First 1
        if ($hit) { return $true }
    }
    return $false
}

function Get-SkillStatus([string]$Root, [string]$UserHome) {
    Get-MainFlowSkills $Root | ForEach-Object {
        [pscustomobject]@{ Name = $_; Present = (Test-SkillPresent $_ $UserHome) }
    }
}

$script:SkillsNpxArgs = @('skills@latest', 'add', 'mattpocock/skills', '--skill=setup-matt-pocock-skills')

# Returns 'skipped', 'present', 'no-npx', 'installed' or 'failed'. Never throws.
# -Npx and -Runner are seams for tests: the npx path (or $null) and a scriptblock that runs it with the args.
function Install-MainFlowSkills([string]$Root, [string]$UserHome, [switch]$Skip, $Npx, [scriptblock]$Runner) {
    if ($Skip) { return 'skipped' }
    $skills = @(Get-SkillStatus $Root $UserHome)
    if (-not $skills -or ($skills | Where-Object Present)) { return 'present' }
    if (-not $Npx) { return 'no-npx' }
    try {
        & $Runner $Npx $script:SkillsNpxArgs
        if ($LASTEXITCODE -ne 0) { return 'failed' }
        return 'installed'
    } catch { return 'failed' }
}
