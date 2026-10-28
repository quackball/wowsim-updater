<#
.SYNOPSIS
Stop and remove the running WoWSims container.
#>
[CmdletBinding()]
param()
. (Join-Path $PSScriptRoot 'scripts/docker-common.ps1')
try {
    Assert-DockerReady
    $containers = @(Get-SimContainers)
    if ($containers.Count) { Stop-SimContainers -Containers $containers }
    else { Write-Output 'wowsim not currently running' }
    exit 0
} catch { Exit-CommandError $_ }
