# Auto Updating Wowsim Docker Container

* Windows: Install Docker Desktop and use the PowerShell commands below. No Ubuntu installation or WSL terminal is needed.
* Mac/Linux bash should be installed already, can use `./` shortcuts if currently running in bash, otherwise prepend with `bash`
* Install docker https://www.docker.com/products/docker-desktop/
* update `tz.env` file to preferred timezone, otherwise defaults to `America/Denver`
* `$ bash build.sh` to build docker container
* `$ bash run.sh` to start Forever and browse to http://localhost:3333
* `$ bash run.sh mop` to select another flavor (see below)
* `$ bash stop.sh` to stop the running container
* `$ bash bash.sh` to open a shell within container
* `$ bash version-check.sh` to check current sim version

## Windows PowerShell

Use Windows PowerShell 5.1 or PowerShell 7 with Docker Desktop running in
Linux container mode. Docker Desktop can use its managed WSL 2 backend;
you do not need to install a separate Linux distribution or configure
Docker integration with Ubuntu. These scripts call Docker directly.

```powershell
.\build.ps1
.\run.ps1              # Forever (default)
.\run.ps1 mop          # Select MoP
.\run.ps1 -Help        # List flavors and settings
.\version-check.ps1
.\bash.ps1             # Interactive shell inside the container
.\stop.ps1
```

The scripts resolve paths relative to the repository, so they also work
when invoked from another directory or a path containing spaces.
Use `Get-Help .\run.ps1 -Examples` for additional examples.
Build again after changing the nonempty `TZ=` setting in `tz.env`; an empty
setting uses the Docker image's default of `America/Denver`.

Environment settings use PowerShell syntax:

```powershell
$env:WOWSIM_FLAVOR = 'mop'
$env:WOWSIM_STARTUP_TIMEOUT = '300'
.\run.ps1
```

An explicit flavor argument overrides the environment setting. Startup
waits for readiness and prints logs on failure, just like the Bash command.
Use `docker logs -f <container-id>` after a successful start to follow logs.

If Windows blocks a downloaded script, review it and use `Unblock-File`
on the script files. If your execution policy still blocks scripts, you
can launch a command with a process-only override:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run.ps1 mop
```

Organization-managed policies may prevent an override. The project does
not change your system or user execution policy.

## Choosing a flavor

Build once with `bash build.sh`, then select a flavor at startup:

```bash
bash run.sh forever
bash run.sh mop
bash run.sh --help
```

Supported flavors: `forever` (default), `mop`, `cata`, `wotlk`, `classic`,
`sod`, `tbc` (legacy 2021 simulator), and `tbc-new` (TBC Anniversary).
Each uses the matching repository under `github.com/wowsims`.
TBC and TBC Anniversary both publish `wowsimtbc-amd64-linux.zip`;
the other flavors use `wowsim<flavor>-amd64-linux.zip`.

The startup argument overrides `WOWSIM_FLAVOR`, which overrides the Forever
default. For example, `WOWSIM_FLAVOR=cata bash run.sh` selects Cataclysm.
Starting a flavor stops the existing simulator container. One simulator runs
at a time on port 3333; switching flavors does not require rebuilding.

`run.sh` waits for the simulator to respond before reporting success and
leaving it in the background. If startup exits or times out, it prints the
container logs, removes the failed container, and returns a nonzero status.
The default startup timeout is 180 seconds; increase it for slow downloads
with `WOWSIM_STARTUP_TIMEOUT=300 bash run.sh forever`.
After a successful start, use the printed `docker logs -f <container-id>`
command to follow logs. `bash stop.sh` stops and removes the container.

For direct Docker use:

```bash
docker run --platform linux/amd64 -d --rm -p 3333:3333 -e WOWSIM_FLAVOR=mop wowsim
```

The container downloads the latest published Linux AMD64 release at startup
and checks hourly for updates. Installations and version files are separated
by flavor under `/home/root/flavors/<flavor>/current`. The version helper
reports both the active flavor and version. Containers remain disposable:
`stop.sh` or switching flavors removes their downloaded binaries and version
state. Stopping a container directly with Docker retains it until removed.

Forever is expected to publish `wowsimforever-amd64-linux.zip`, containing
`wowsimforever-amd64-linux`. Until that release exists, startup reports the
missing release or asset and exits. No source build is performed.
Failed update downloads preserve the installed simulator; executables that
exit during startup are rolled back to the previous installation.

## Validation

Run `sh tests/test.sh` in Linux with Bash, `ash` (Alpine or BusyBox), curl, jq,
unzip, Python 3, and flock installed. Tests use temporary directories, mocked
downloads, and fake simulator executables; they do not require GitHub access.

Run `.\tests\test.ps1` in PowerShell to test the native Windows commands.
It uses mocked Docker commands in temporary directories and requires no
additional test modules or running Docker daemon. Run it with both Windows
PowerShell 5.1 and PowerShell 7 when validating compatibility.
