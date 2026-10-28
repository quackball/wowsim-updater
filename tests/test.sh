#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
for tool in bash ash curl jq unzip flock python3; do
    command -v "$tool" >/dev/null || { echo "Missing test dependency: $tool" >&2; exit 1; }
done
tmp=$(mktemp -d)
cleanup() {
    for state in "$tmp"/runtime/flavors/*; do
        [ -d "$state" ] || continue
        WOWSIM_FLAVOR=${state##*/} ash "$tmp/runtime/stop-sim.sh" "$tmp/runtime" || true
    done
    rm -rf -- "$tmp"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
mkdir -p "$tmp/bin" "$tmp/runtime" "$tmp/fixtures"
cp "$repo"/scripts/*.sh "$tmp/runtime/"
cp "$repo/scripts/flavors.csv" "$tmp/runtime/"
export SIM_ROOT="$tmp/runtime" MOCK_ROOT="$tmp" MOCK_MODE=ok MOCK_TAG=v1
export PATH="$tmp/bin:$PATH"

cat > "$tmp/bin/curl" <<'EOF'
#!/bin/sh
set -eu
echo "$*" >> "$MOCK_ROOT/curl.log"
case "$2" in
    http://localhost:3333/*) exit 0 ;;
    https://api.github.com/repos/*)
        [ "$MOCK_MODE" != unavailable ] || exit 22
        [ "$MOCK_MODE" != invalid-json ] || { echo 'not json'; exit 0; }
        [ "$MOCK_MODE" != invalid-tag ] || { echo '{"tag_name":null}'; exit 0; }
        if [ "$MOCK_MODE" = missing-asset ]; then
            printf '{"tag_name":"%s","assets":[]}' "$MOCK_TAG"
        else
            printf '{"tag_name":"%s","assets":[{"name":"%s","browser_download_url":"https://example.test/%s"}]}' "$MOCK_TAG" "$SIM_ARCHIVE" "$SIM_ARCHIVE"
        fi ;;
    https://example.test/*)
        [ "$MOCK_MODE" != download-failure ] || exit 22
        if [ "$MOCK_MODE" = corrupt ]; then echo broken > "$4"
        elif [ "$MOCK_MODE" = wrong-binary ]; then cp "$MOCK_ROOT/fixtures/wrong.zip" "$4"
        elif [ "$MOCK_MODE" = broken-binary ]; then cp "$MOCK_ROOT/fixtures/broken.zip" "$4"
        else cp "$MOCK_ROOT/fixtures/$SIM_ARCHIVE" "$4"; fi ;;
    *) exit 99 ;;
esac
EOF
cat > "$tmp/bin/docker" <<'EOF'
#!/bin/sh
echo "$*" >> "$MOCK_ROOT/docker.log"
case "$1" in
    ps) echo existing-container ;;
    run) echo new-container ;;
    inspect)
        if [ "${MOCK_DOCKER_MODE:-ok}" = exited ]; then echo exited
        else echo running; fi ;;
    exec) [ "${MOCK_DOCKER_MODE:-ok}" != timeout ] ;;
    logs) echo 'forever: cannot fetch latest release (expected wowsimforever-amd64-linux.zip)' ;;
esac
EOF
cat > "$tmp/bin/crond" <<'EOF'
#!/bin/sh
set -eu
echo "$WOWSIM_FLAVOR" > "$MOCK_ROOT/cron-flavor"
# Exercise the actual hourly command with its inherited environment.
command=$(sed "s|/home/root|$SIM_ROOT|g" "$MOCK_ROOT/crontab" | cut -d ' ' -f 6-)
ash -c "$command"
EOF
chmod +x "$tmp/bin/"*
cp "$repo/crontab" "$tmp/crontab"

python3 - "$tmp/fixtures" <<'PY'
import pathlib, sys, zipfile
root = pathlib.Path(sys.argv[1])
for flavor in ['forever', 'mop', 'cata', 'wotlk', 'classic', 'sod', 'tbc']:
    name = f'wowsim{flavor}-amd64-linux'
    with zipfile.ZipFile(root / f'{name}.zip', 'w') as archive:
        archive.writestr(name, '#!/usr/bin/python3\nimport time\ntime.sleep(3600)\n')
with zipfile.ZipFile(root / 'wrong.zip', 'w') as archive:
    archive.writestr('wrong-executable', 'wrong')
with zipfile.ZipFile(root / 'broken.zip', 'w') as archive:
    archive.writestr('wowsimforever-amd64-linux', '#!/bin/sh\nexit 1\n')
PY

. "$repo/scripts/flavor.sh"
unset WOWSIM_FLAVOR
resolve_flavor
[ "$WOWSIM_FLAVOR" = forever ]
WOWSIM_FLAVOR=mop
resolve_flavor
[ "$SIM_REPO" = wowsims/mop ]
resolve_flavor cata
[ "$SIM_REPO" = wowsims/cata ]
export SIM_ARCHIVE

# Invalid selection must not touch Docker or interrupt a running container.
if bash "$repo/run.sh" invalid > "$tmp/output" 2>&1; then exit 1; fi
if bash "$repo/run.sh" mop extra > "$tmp/output" 2>&1; then exit 1; fi
bash "$repo/run.sh" --help > "$tmp/output"
[ ! -e "$tmp/docker.log" ]
unset WOWSIM_FLAVOR
bash "$repo/run.sh"
grep -q 'WOWSIM_FLAVOR=forever' "$tmp/docker.log"
WOWSIM_FLAVOR=mop bash "$repo/run.sh"
grep -q 'WOWSIM_FLAVOR=mop' "$tmp/docker.log"
WOWSIM_FLAVOR=mop bash "$repo/run.sh" cata
grep '^run ' "$tmp/docker.log" | tail -1 | grep -q 'WOWSIM_FLAVOR=cata'
echo 'PASS: launcher validation and selection precedence'

for mode in exited timeout; do
    if MOCK_DOCKER_MODE=$mode WOWSIM_STARTUP_TIMEOUT=1 bash "$repo/run.sh" forever > "$tmp/output" 2>&1; then exit 1; fi
    grep -q 'failed to become ready' "$tmp/output"
    grep -q 'cannot fetch latest release' "$tmp/output"
    tail -1 "$tmp/docker.log" | grep -q '^rm -f new-container$'
done
before=$(wc -l < "$tmp/docker.log")
if WOWSIM_STARTUP_TIMEOUT=invalid bash "$repo/run.sh" > "$tmp/output" 2>&1; then exit 1; fi
[ "$(wc -l < "$tmp/docker.log")" = "$before" ]
echo 'PASS: launcher prints startup failures and timeouts and cleans failed containers'

for flavor in forever mop cata wotlk classic sod tbc tbc-new; do
    resolve_flavor "$flavor"
    init_sim_paths
    [ "$SIM_REPO" = "wowsims/$flavor" ]
    expected=$flavor
    [ "$flavor" != tbc-new ] || expected=tbc
    [ "$SIM_BINARY" = "wowsim$expected-amd64-linux" ]
    ash "$tmp/runtime/healthcheck.sh"
    tail -1 "$tmp/curl.log" | grep -q "http://localhost:3333/$expected/"
    ash "$tmp/runtime/update-sim.sh" "$SIM_ROOT" > "$tmp/output" 2>&1
    [ "$(cat "$SIM_INSTALL_DIR/current_version.txt")" = v1 ]
    sim_running
    original_pid=$sim_pid
    ash "$tmp/runtime/update-sim.sh" "$SIM_ROOT" > "$tmp/output" 2>&1
    sim_running
    [ "$sim_pid" = "$original_pid" ]
    ash "$tmp/runtime/version.sh" | grep -q "^$flavor: v1$"
    ash "$tmp/runtime/stop-sim.sh" "$SIM_ROOT"
done
echo 'PASS: all mappings, isolated versions, first install and unchanged releases'

resolve_flavor forever
init_sim_paths
ash "$tmp/runtime/update-sim.sh" "$SIM_ROOT" > "$tmp/output" 2>&1
sim_running
original_pid=$sim_pid
MOCK_TAG=v2
export MOCK_TAG
for mode in unavailable invalid-json invalid-tag missing-asset download-failure corrupt wrong-binary; do
    MOCK_MODE=$mode ash "$tmp/runtime/update-sim.sh" "$SIM_ROOT" > "$tmp/output" 2>&1
    [ "$(cat "$SIM_INSTALL_DIR/current_version.txt")" = v1 ]
    sim_running
    [ "$sim_pid" = "$original_pid" ]
done
echo 'PASS: failed updates preserve the installed version and running process'

ash "$tmp/runtime/update-sim.sh" "$SIM_ROOT" > "$tmp/output" 2>&1
[ "$(cat "$SIM_INSTALL_DIR/current_version.txt")" = v2 ]
sim_running
[ "$sim_pid" != "$original_pid" ]
ash "$tmp/runtime/stop-sim.sh" "$SIM_ROOT"
MOCK_MODE=unavailable ash "$tmp/runtime/update-sim.sh" "$SIM_ROOT" > "$tmp/output" 2>&1
sim_running
echo 'PASS: successful update and offline restart'

MOCK_TAG=v3 MOCK_MODE=broken-binary ash "$tmp/runtime/update-sim.sh" "$SIM_ROOT" > "$tmp/output" 2>&1
[ "$(cat "$SIM_INSTALL_DIR/current_version.txt")" = v2 ]
sim_running
echo 'PASS: failed executable startup restores the previous installation'

# The inherited environment must reach both setup and the hourly command.
resolve_flavor mop
init_sim_paths
ash "$tmp/runtime/setup.sh" > "$tmp/output" 2>&1
[ "$(cat "$tmp/cron-flavor")" = mop ]
sim_running
echo 'PASS: startup and hourly cron use the selected flavor'

# A first installation with no release must fail clearly.
resolve_flavor sod
init_sim_paths
ash "$tmp/runtime/stop-sim.sh" "$SIM_ROOT"
rm -rf -- "$SIM_STATE_DIR"
if MOCK_MODE=unavailable ash "$tmp/runtime/setup.sh" > "$tmp/output" 2>&1; then exit 1; fi
grep -q "expected $SIM_ARCHIVE from $SIM_REPO" "$tmp/output"
echo 'PASS: unavailable release fails initial startup'

resolve_flavor forever
init_sim_paths
(
    flock 9
    MOCK_TAG=v4 ash "$tmp/runtime/update-sim.sh" "$SIM_ROOT"
    # Keep this lock-owning shell alive while the child opens its own FD 9.
    echo held > "$tmp/lock-held"
) 9>"$SIM_STATE_DIR/update.lock"
[ "$(cat "$SIM_INSTALL_DIR/current_version.txt")" = v2 ]
echo 'PASS: overlapping updater is skipped'

for script in "$repo"/*.sh; do bash -n "$script"; done
for script in "$repo"/scripts/*.sh; do ash -n "$script"; done
echo 'PASS: Bash and ash syntax checks'
