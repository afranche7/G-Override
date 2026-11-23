# Runs the Windows Helper tests and prints the results. Exit code = number of failures.
#   powershell -File windows\tests\run.ps1
$ahk = Join-Path $env:LOCALAPPDATA 'Programs\AutoHotkey\v2\AutoHotkey64.exe'
if (-not (Test-Path $ahk)) { $ahk = Join-Path $env:ProgramFiles 'AutoHotkey\v2\AutoHotkey64.exe' }
$out = [IO.Path]::GetTempFileName()
try {
    $p = Start-Process $ahk -ArgumentList '/ErrorStdOut', "`"$PSScriptRoot\run.ahk`"" -Wait -PassThru -NoNewWindow `
        -RedirectStandardOutput $out -RedirectStandardError "$out.err"
    Get-Content $out
    Get-Content "$out.err"
    $failures = $p.ExitCode
    # Installer-side (PowerShell) tests
    powershell -NoProfile -File (Join-Path $PSScriptRoot 'TestSkills.ps1')
    exit ($failures + $LASTEXITCODE)
} finally {
    Remove-Item $out, "$out.err" -ErrorAction SilentlyContinue
}
