# Tests for windows\lib\Skills.ps1. Exit code = number of failures.
#   powershell -File windows\tests\TestSkills.ps1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\Skills.ps1')
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$script:fail = 0

function Test([string]$Name, [scriptblock]$Body) {
    $home_ = Join-Path ([IO.Path]::GetTempPath()) ("g-override-skills-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $home_ | Out-Null
    try { & $Body $home_; Write-Output "ok   $Name" }
    catch { $script:fail++; Write-Output "FAIL $Name`n     $($_.Exception.Message)" }
    finally { Remove-Item $home_ -Recurse -Force -ErrorAction SilentlyContinue }
}
function AssertEq($Actual, $Expected) { if ($Actual -ne $Expected) { throw "expected <$Expected> but got <$Actual>" } }
function AddSkill([string]$Dir) { New-Item -ItemType Directory -Force -Path $Dir | Out-Null; Set-Content (Join-Path $Dir 'SKILL.md') 'x' }

$calls = [System.Collections.Generic.List[string]]::new()
$ok = { param($npx, $a) $calls.Add("$npx $($a -join ' ')"); $global:LASTEXITCODE = 0 }
$bad = { param($npx, $a) $global:LASTEXITCODE = 1 }

Test 'reads the Main Flow skill list from config.ini' {
    AssertEq ((Get-MainFlowSkills $RepoRoot) -join ',') 'grill-with-docs,to-spec,to-tickets,implement,code-review,retro'
}
Test 'finds a skill installed as a user skill' { param($h)
    AddSkill "$h\.claude\skills\implement"
    AssertEq (Test-SkillPresent 'implement' $h) $true
    AssertEq (Test-SkillPresent 'retro' $h) $false
}
Test 'finds a skill installed by npx skills under .agents' { param($h)
    AddSkill "$h\.agents\skills\retro"
    AssertEq (Test-SkillPresent 'retro' $h) $true
}
Test 'finds a skill inside an installed plugin, at any depth' { param($h)
    AddSkill "$h\.claude\plugins\cache\mk\mattpocock-skills\1.0\skills\engineering\to-spec"
    AssertEq (Test-SkillPresent 'to-spec' $h) $true
}
Test 'finds a skill in a plugin installed through the Claude desktop app' { param($h)
    AddSkill "$h\AppData\Roaming\Claude\rpm\a\b\plugin_1\skills\engineering\implement"
    AssertEq (Test-SkillPresent 'implement' $h) $true
}
Test 'ignores a plugin marketplace checkout that is not installed' { param($h)
    AddSkill "$h\.claude\plugins\marketplaces\mk\skills\to-spec"
    AssertEq (Test-SkillPresent 'to-spec' $h) $false
}
Test 'a directory with the right name but no SKILL.md is not a skill' { param($h)
    New-Item -ItemType Directory -Force "$h\.claude\skills\implement" | Out-Null
    AssertEq (Test-SkillPresent 'implement' $h) $false
}
Test 'does not run npx when a Main Flow skill is already present' { param($h)
    AddSkill "$h\.claude\skills\implement"; $calls.Clear()
    AssertEq (Install-MainFlowSkills $RepoRoot $h -Npx 'npx' -Runner $ok) 'present'
    AssertEq $calls.Count 0
}
Test 'runs the documented npx command when none are present' { param($h)
    $calls.Clear()
    AssertEq (Install-MainFlowSkills $RepoRoot $h -Npx 'npx' -Runner $ok) 'installed'
    AssertEq ($calls -join ';') 'npx skills@latest add mattpocock/skills --skill=setup-matt-pocock-skills'
}
Test 'reports a hint-able no-npx result without failing' { param($h)
    AssertEq (Install-MainFlowSkills $RepoRoot $h -Npx $null -Runner $ok) 'no-npx'
}
Test 'a failing npx is reported, not thrown' { param($h)
    AssertEq (Install-MainFlowSkills $RepoRoot $h -Npx 'npx' -Runner $bad) 'failed'
}
Test 'the skip flag runs nothing' { param($h)
    $calls.Clear()
    AssertEq (Install-MainFlowSkills $RepoRoot $h -Skip -Npx 'npx' -Runner $ok) 'skipped'
    AssertEq $calls.Count 0
}
Test 'doctor status lists each skill as present or missing' { param($h)
    AddSkill "$h\.claude\skills\implement"
    $s = @(Get-SkillStatus $RepoRoot $h)
    AssertEq $s.Count 6
    AssertEq (($s | Where-Object Name -eq 'implement').Present) $true
    AssertEq (($s | Where-Object Name -eq 'retro').Present) $false
}

exit $script:fail
