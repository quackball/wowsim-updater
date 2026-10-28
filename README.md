# Auto Updating Wowsim Docker Container

* Windows: Intall WSL https://learn.microsoft.com/en-us/windows/wsl/install and use WSL terminal (WIN+wsl)
* Mac/Linux bash should be installed already, can use `./` shortcuts if currently running in bash, otherwise prepend with `bash`
* Install docker https://www.docker.com/products/docker-desktop/
* update `tz.env` file to preferred timezone, otherwise defaults to `America/Denver`
* `$ bash build.sh` to build docker container
* `$ bash run.sh` to start Forever and browse to http://localhost:3333
* `$ bash run.sh mop` to select another flavor (see below)
* `$ bash stop.sh` to stop the running container
* `$ bash bash.sh` to open a shell within container
* `$ bash version-check.sh` to check current sim version

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
