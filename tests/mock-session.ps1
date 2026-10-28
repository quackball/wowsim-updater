# Run a public command in a separate PowerShell session with Docker mocked.
$global:LASTEXITCODE = 0
function global:docker {
    $commandArguments = @($args | ForEach-Object { [string]$_ })
    ConvertTo-Json -InputObject $commandArguments -Compress | Add-Content -LiteralPath $env:MOCK_DOCKER_LOG
    $global:LASTEXITCODE = 0
    $mode = $env:MOCK_DOCKER_MODE
    switch ($commandArguments[0]) {
        'info' {
            if ($mode -eq 'offline') { $global:LASTEXITCODE = 1 }
            elseif ($mode -eq 'windows') { 'windows' }
            else { 'linux' }
        }
        'ps' {
            if ($mode -eq 'multiple') { 'old-one'; 'old-two' }
            elseif ($mode -ne 'empty') { 'old-container' }
        }
        'run' {
            if ($mode -eq 'run-failure') { $global:LASTEXITCODE = 125 }
            else { 'new-container' }
        }
        'inspect' {
            if ($commandArguments[-1] -like 'old*' -and $mode -eq 'auto-remove') { $global:LASTEXITCODE = 1 }
            elseif ($commandArguments[-1] -eq 'new-container' -and $mode -eq 'exited') { 'exited' }
            else { 'running' }
        }
        'exec' {
            if ($mode -eq 'timeout') { $global:LASTEXITCODE = 1 }
            elseif ($mode -eq 'exec-failure') { $global:LASTEXITCODE = 42 }
            elseif ($commandArguments[-1] -eq './version.sh') { 'mop: v1' }
            elseif ($commandArguments[-1] -eq '-l') { 'interactive shell' }
        }
        'logs' { 'forever: cannot fetch latest release; expected wowsimforever-amd64-linux.zip' }
        'build' { if ($mode -eq 'build-failure') { $global:LASTEXITCODE = 23 } }
        'stop' { if ($mode -eq 'stop-failure') { $global:LASTEXITCODE = 24 } }
        'rm' { if ($mode -eq 'remove-failure') { $global:LASTEXITCODE = 25 } }
    }
}
if ($env:MOCK_DOCKER_MODE -eq 'missing') {
    # Hide both the mock and a real Docker executable from discovery.
    function global:Get-Command {
        param($Name, $ErrorAction)
        if ($Name -ne 'docker') { Microsoft.PowerShell.Core\Get-Command $Name }
    }
}
$commandArguments = @()
if ($env:MOCK_SCRIPT_ARGS) {
    $decodedArguments = ConvertFrom-Json $env:MOCK_SCRIPT_ARGS
    $commandArguments = @($decodedArguments | ForEach-Object { [string]$_ })
}
$namedArguments = @{}
if ($commandArguments -contains '-Help') {
    $namedArguments.Help = $true
    $commandArguments = @($commandArguments | Where-Object { $_ -ne '-Help' })
}
try { & $env:MOCK_SCRIPT_PATH @namedArguments @commandArguments }
catch { Write-Error $_ -ErrorAction Continue; exit 1 }
exit $LASTEXITCODE
