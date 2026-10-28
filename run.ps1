<#
.SYNOPSIS
Start a selected WoWSims flavor and wait for readiness.
.EXAMPLE
.\run.ps1 mop
.EXAMPLE
$env:WOWSIM_STARTUP_TIMEOUT = '300'; .\run.ps1 forever
#>
[CmdletBinding()]
param([Parameter(Position = 0)][string]$Flavor, [switch]$Help)
. (Join-Path $PSScriptRoot 'scripts/docker-common.ps1')
try {
    if ($Help) {
        Write-Output 'Usage: .\run.ps1 [flavor] [-Help]'
        $flavors = Import-Csv -LiteralPath (Join-Path $PSScriptRoot 'scripts/flavors.csv')
        Write-Output "Flavors: $($flavors.flavor -join ', ') (default: forever)"
        Write-Output 'Selection: argument > WOWSIM_FLAVOR > forever'
        Write-Output 'WOWSIM_STARTUP_TIMEOUT sets the timeout in seconds (default: 180).'
        exit 0
    }
    $selected = Get-SimFlavor $Flavor
    $timeout = 180
    if (-not [string]::IsNullOrEmpty($env:WOWSIM_STARTUP_TIMEOUT)) {
        if ($env:WOWSIM_STARTUP_TIMEOUT -notmatch '^[0-9]+$' -or
            -not [int]::TryParse($env:WOWSIM_STARTUP_TIMEOUT, [ref]$timeout) -or $timeout -le 0) {
            throw 'WOWSIM_STARTUP_TIMEOUT must be a positive number of seconds.'
        }
    }
    Assert-DockerReady
    Stop-SimContainers -Containers @(Get-SimContainers)
    Write-Output "Starting $($selected.flavor); waiting up to ${timeout}s for the simulator..."
    $containerId = (@(Invoke-DockerCommand -Arguments @('run', '--platform', 'linux/amd64', '-d', '-p', '3333:3333', '-e', "WOWSIM_FLAVOR=$($selected.flavor)", 'wowsim')) -join '').Trim()
    if (-not $containerId) { throw 'Docker did not return a container ID.' }
    $clock = [Diagnostics.Stopwatch]::StartNew()
    while ($clock.Elapsed.TotalSeconds -lt $timeout) {
        $state = @(Invoke-DockerCommand -Arguments @('inspect', '--format', '{{.State.Status}}', $containerId) -AllowFailure 2>$null)
        if ($LASTEXITCODE -ne 0 -or ($state -join '').Trim() -ne 'running') { break }
        $null = Invoke-DockerCommand -Arguments @('exec', $containerId, 'ash', '/home/root/healthcheck.sh') -AllowFailure 2>$null
        if ($LASTEXITCODE -eq 0) {
            $route = $selected.binary_prefix.Substring('wowsim'.Length)
            Write-Output "$($selected.flavor) is ready at http://localhost:3333/$route/"
            Write-Output "Container: $containerId"
            Write-Output "View logs: docker logs -f $containerId"
            exit 0
        }
        Start-Sleep -Seconds 1
    }
    Write-Output "$($selected.flavor) failed to become ready. Container startup logs:"
    try {
        Invoke-DockerCommand -Arguments @('logs', $containerId) -AllowFailure
    } finally {
        $null = Invoke-DockerCommand -Arguments @('rm', '-f', $containerId) -AllowFailure
    }
    exit 1
} catch { Exit-CommandError $_ }
