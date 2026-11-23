<#
.SYNOPSIS
  Removes what install.ps1 added: the Startup shortcut, and stops the running Helper.
  Leaves AutoHotkey, Claude skills (never removed), config.local.ini and the repo itself untouched.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$StartupShortcut = Join-Path ([Environment]::GetFolderPath('Startup')) 'G-Override.lnk'

if (Test-Path $StartupShortcut) {
    Remove-Item $StartupShortcut
    Write-Host "Removed $StartupShortcut"
} else {
    Write-Host 'No Startup shortcut to remove.'
}

$procs = Get-CimInstance Win32_Process -Filter "Name LIKE 'AutoHotkey%'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like '*g-override.ahk*' }
foreach ($p in $procs) {
    Stop-Process -Id $p.ProcessId -Force
    Write-Host "Stopped Helper (pid $($p.ProcessId))"
}

Write-Host 'G-Override uninstalled. (AutoHotkey and Claude skills were left installed.)'
