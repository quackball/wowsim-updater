[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$engine = (Get-Process -Id $PID).Path
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('wowsim-powershell-' + [guid]::NewGuid().ToString('N'))
$testRepo = Join-Path $testRoot 'repo with spaces'
$savedEnvironment = @{}
$environmentNames = @('MOCK_DOCKER_LOG', 'MOCK_DOCKER_MODE', 'MOCK_SCRIPT_PATH', 'MOCK_SCRIPT_ARGS', 'WOWSIM_FLAVOR', 'WOWSIM_STARTUP_TIMEOUT')
foreach ($name in $environmentNames) { $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
function Invoke-TestCommand {
    param([string]$Name, [string[]]$Arguments = @(), [string]$Mode = 'ok')
    $env:MOCK_SCRIPT_PATH = Join-Path $testRepo $Name
    $env:MOCK_SCRIPT_ARGS = ConvertTo-Json -InputObject $Arguments -Compress
    $env:MOCK_DOCKER_MODE = $Mode
    Set-Content -LiteralPath $env:MOCK_DOCKER_LOG -Value ''
    $previousErrorAction = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $engine -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'mock-session.ps1') 2>&1)
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousErrorAction }
    $calls = @(Get-Content -LiteralPath $env:MOCK_DOCKER_LOG | Where-Object { $_ } | ForEach-Object { ,(ConvertFrom-Json $_) })
    [pscustomobject]@{ Code = $code; Output = ($output -join "`n"); Calls = $calls }
}

try {
    $null = New-Item -ItemType Directory -Path (Join-Path $testRepo 'scripts') -Force
    Get-ChildItem -LiteralPath $repo -Filter '*.ps1' | Copy-Item -Destination $testRepo
    Copy-Item -LiteralPath (Join-Path $repo 'scripts/docker-common.ps1'), (Join-Path $repo 'scripts/flavors.csv') -Destination (Join-Path $testRepo 'scripts')
    Copy-Item -LiteralPath (Join-Path $repo 'tz.env') -Destination $testRepo
    $env:MOCK_DOCKER_LOG = Join-Path $testRoot 'docker.jsonl'
    $env:WOWSIM_FLAVOR = $null
    $env:WOWSIM_STARTUP_TIMEOUT = $null

    # Run from another directory; the copied repository also contains spaces.
    Push-Location $testRoot
    try {
        $flavors = Import-Csv -LiteralPath (Join-Path $repo 'scripts/flavors.csv')
        foreach ($flavor in $flavors) {
            $result = Invoke-TestCommand 'run.ps1' @($flavor.flavor)
            Assert-True ($result.Code -eq 0) $result.Output
            $launch = @($result.Calls | Where-Object { $_[0] -eq 'run' })
            Assert-True ($launch.Count -eq 1 -and $launch[0] -contains "WOWSIM_FLAVOR=$($flavor.flavor)") "Incorrect flavor passed to Docker: $(ConvertTo-Json -InputObject $result -Compress -Depth 5)"
            $route = $flavor.binary_prefix.Substring(6)
            Assert-True ($result.Output.Contains("http://localhost:3333/$route/")) 'Incorrect flavor route'
        }
        $result = Invoke-TestCommand 'run.ps1'
        Assert-True ($result.Code -eq 0 -and $result.Output.Contains('/forever/')) 'Default flavor failed'
        $env:WOWSIM_FLAVOR = 'mop'
        $result = Invoke-TestCommand 'run.ps1'
        Assert-True ($result.Code -eq 0 -and $result.Output.Contains('/mop/')) 'Environment flavor failed'
        $result = Invoke-TestCommand 'run.ps1' @('cata')
        Assert-True ($result.Code -eq 0 -and $result.Output.Contains('/cata/')) 'Argument precedence failed'
        $env:WOWSIM_FLAVOR = $null
        foreach ($invalid in @(@('invalid'), @('mop', 'extra'))) {
            $result = Invoke-TestCommand 'run.ps1' $invalid
            Assert-True ($result.Code -ne 0 -and $result.Calls.Count -eq 0) 'Invalid arguments touched Docker'
        }
        $result = Invoke-TestCommand 'run.ps1' @('-Help')
        Assert-True ($result.Code -eq 0 -and $result.Calls.Count -eq 0) 'Help touched Docker'
        $env:WOWSIM_STARTUP_TIMEOUT = 'invalid'
        $result = Invoke-TestCommand 'run.ps1'
        Assert-True ($result.Code -ne 0 -and $result.Calls.Count -eq 0) 'Invalid timeout touched Docker'
        $env:WOWSIM_STARTUP_TIMEOUT = '1'
        foreach ($mode in 'exited', 'timeout') {
            $result = Invoke-TestCommand 'run.ps1' @('forever') $mode
            Assert-True ($result.Code -eq 1 -and $result.Output.Contains('cannot fetch latest release')) 'Startup error logs missing'
            Assert-True (($result.Calls[-1] -join ' ') -eq 'rm -f new-container') 'Failed container not cleaned up'
        }
        $env:WOWSIM_STARTUP_TIMEOUT = $null
        foreach ($mode in 'missing', 'offline', 'windows') {
            $result = Invoke-TestCommand 'run.ps1' @() $mode
            Assert-True ($result.Code -ne 0 -and $result.Output -match 'Docker') 'Docker prerequisite failure missing'
            Assert-True (@($result.Calls | Where-Object { $_[0] -eq 'run' -or $_[0] -eq 'stop' }).Count -eq 0) 'Prerequisite failure changed containers'
        }
        foreach ($case in @(@('run.ps1', 'run-failure', 125), @('run.ps1', 'stop-failure', 24), @('stop.ps1', 'remove-failure', 25), @('build.ps1', 'build-failure', 23), @('bash.ps1', 'exec-failure', 42))) {
            $result = Invoke-TestCommand $case[0] @() $case[1]
            Assert-True ($result.Code -eq $case[2]) "Native failure exit code lost: $($result.Output)"
        }
        foreach ($name in 'stop.ps1', 'bash.ps1', 'version-check.ps1') {
            $result = Invoke-TestCommand $name
            Assert-True ($result.Code -eq 0) $result.Output
            $result = Invoke-TestCommand $name @() 'empty'
            Assert-True ($result.Code -eq 0 -and $result.Output.Contains('not currently running')) 'Empty container handling failed'
        }
        $result = Invoke-TestCommand 'stop.ps1' @() 'auto-remove'
        Assert-True ($result.Code -eq 0) 'Auto-removed container handling failed'
        $result = Invoke-TestCommand 'stop.ps1' @() 'multiple'
        Assert-True (@($result.Calls | Where-Object { $_[0] -eq 'stop' }).Count -eq 2) 'Multiple containers were not stopped'
        foreach ($name in 'bash.ps1', 'version-check.ps1') {
            $result = Invoke-TestCommand $name @() 'multiple'
            Assert-True ($result.Code -ne 0) 'Ambiguous interactive/version target accepted'
        }
        $result = Invoke-TestCommand 'build.ps1'
        Assert-True ($result.Code -eq 0 -and $result.Calls[-1][-1] -eq $testRepo) 'Build context path failed'
        Set-Content -LiteralPath (Join-Path $testRepo 'tz.env') -Value 'TZ="Europe/London"'
        $result = Invoke-TestCommand 'build.ps1'
        Assert-True ($result.Code -eq 0 -and $result.Calls[-1] -contains 'TZ=Europe/London') 'Timezone build argument missing'
    } finally { Pop-Location }
    Write-Output "PASS: PowerShell commands, flavors, startup failures, Docker errors, paths, and timezone ($($PSVersionTable.PSVersion))"
} finally {
    foreach ($name in $environmentNames) { [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process') }
    $resolvedRoot = [IO.Path]::GetFullPath($testRoot)
    $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolvedRoot.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unexpected test cleanup path' }
    if (Test-Path -LiteralPath $resolvedRoot) { Remove-Item -LiteralPath $resolvedRoot -Recurse -Force }
}
