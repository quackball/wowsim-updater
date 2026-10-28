<#
.SYNOPSIS
Open an interactive ash shell inside the running WoWSims container.
#>
[CmdletBinding()]
param()
. (Join-Path $PSScriptRoot 'scripts/docker-common.ps1')
try {
    Assert-DockerReady
    $containers = @(Get-SimContainers)
    if ($containers.Count -gt 1) { throw 'Multiple WoWSims containers are running; stop extras before opening a shell.' }
    if ($containers.Count) {
        Invoke-DockerCommand -Arguments @('exec', '-it', '--workdir', '/home/root', $containers[0], '/bin/ash', '-l')
    } else { Write-Output 'wowsim not currently running' }
    exit 0
} catch { Exit-CommandError $_ }
