Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-DockerCommand {
    param([string[]]$Arguments, [switch]$AllowFailure)
    # Native failures do not throw automatically in Windows PowerShell 5.1.
    $previousErrorAction = $ErrorActionPreference
    try {
        # PS 5.1 can turn redirected native stderr into terminating errors.
        $ErrorActionPreference = 'Continue'
        & docker @Arguments
        $dockerExitCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousErrorAction }
    $global:LASTEXITCODE = $dockerExitCode
    if ($dockerExitCode -ne 0 -and -not $AllowFailure) {
        $failure = New-Object System.Exception "Docker command '$($Arguments[0])' failed (exit $dockerExitCode)."
        $failure.Data['ExitCode'] = $dockerExitCode
        throw $failure
    }
}

function Exit-CommandError {
    param($Failure)
    Write-Error -Message $Failure.Exception.Message -ErrorAction Continue
    $code = 1
    if ($Failure.Exception.Data.Contains('ExitCode')) {
        $code = [int]$Failure.Exception.Data['ExitCode']
    }
    exit $code
}

function Assert-DockerReady {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw 'Docker was not found. Install Docker Desktop and reopen PowerShell.'
    }
    try {
        $engine = @(Invoke-DockerCommand -Arguments @('info', '--format', '{{.OSType}}'))
    } catch {
        throw 'Cannot connect to Docker. Start Docker Desktop and wait for its engine to be ready.'
    }
    if (($engine -join '').Trim() -ne 'linux') {
        throw 'Docker must use Linux containers. Switch Docker Desktop to Linux containers and retry.'
    }
}

function Get-SimFlavor {
    param([string]$Flavor)
    if ([string]::IsNullOrEmpty($Flavor)) { $Flavor = $env:WOWSIM_FLAVOR }
    if ([string]::IsNullOrEmpty($Flavor)) { $Flavor = 'forever' }
    $flavors = @(Import-Csv -LiteralPath (Join-Path $PSScriptRoot 'flavors.csv'))
    $selected = @($flavors | Where-Object { $_.flavor -ceq $Flavor })
    if ($selected.Count -ne 1) {
        throw "Unknown flavor: $Flavor. Supported: $($flavors.flavor -join ' ')"
    }
    return $selected[0]
}

function Get-SimContainers {
    @(Invoke-DockerCommand -Arguments @('ps', '-q', '--filter', 'ancestor=wowsim')) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
}

function Stop-SimContainers {
    param([string[]]$Containers)
    foreach ($container in $Containers) {
        Invoke-DockerCommand -Arguments @('stop', $container)
        # Containers created by older launchers may remove themselves on stop.
        $null = Invoke-DockerCommand -Arguments @('inspect', $container) -AllowFailure 2>$null
        if ($LASTEXITCODE -eq 0) {
            $null = Invoke-DockerCommand -Arguments @('rm', $container)
        }
    }
}
