<#
.SYNOPSIS
Build the WoWSims Linux container image using Docker Desktop.
#>
[CmdletBinding()]
param()
. (Join-Path $PSScriptRoot 'scripts/docker-common.ps1')
try {
    Assert-DockerReady
    $buildArguments = @('build', '--platform', 'linux/amd64', '--rm', '-t', 'wowsim')
    foreach ($line in Get-Content -LiteralPath (Join-Path $PSScriptRoot 'tz.env')) {
        if ($line -match '^\s*TZ\s*=\s*(.*?)\s*$') {
            $timezone = $Matches[1].Trim('"', "'")
            if ($timezone) { $buildArguments += @('--build-arg', "TZ=$timezone") }
        }
    }
    Invoke-DockerCommand -Arguments ($buildArguments + $PSScriptRoot)
    exit 0
} catch { Exit-CommandError $_ }
