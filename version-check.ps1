<#
.SYNOPSIS
Show the running simulator flavor and installed version.
#>
[CmdletBinding()]
param()
. (Join-Path $PSScriptRoot 'scripts/docker-common.ps1')
try {
    Assert-DockerReady
    $containers = @(Get-SimContainers)
    if ($containers.Count -gt 1) { throw 'Multiple WoWSims containers are running; stop extras before checking the version.' }
    if ($containers.Count) {
        Invoke-DockerCommand -Arguments @('exec', '--workdir', '/home/root', $containers[0], 'ash', './version.sh')
    } else { Write-Output 'wowsim not currently running' }
    exit 0
} catch { Exit-CommandError $_ }
