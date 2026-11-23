# Runs the macOS Helper tests (busted) and prints the results. Exit code is non-zero on failure.
#   powershell -File mac\tests\run.ps1
# Uses busted if it's installed; otherwise runs it in a Docker container (image built on first use).
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if (Get-Command busted -ErrorAction SilentlyContinue) {
    Push-Location $root
    try { busted; exit $LASTEXITCODE } finally { Pop-Location }
}
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error 'Need busted (https://lunarmodules.github.io/busted/) or Docker to run the macOS tests.'
    exit 2
}
docker image inspect g-override-busted *> $null
if ($LASTEXITCODE -ne 0) {
    docker build -q -f "$root\mac\tests\Dockerfile" -t g-override-busted $root | Out-Null
}
docker run --rm -v "${root}:/repo:ro" g-override-busted
exit $LASTEXITCODE
