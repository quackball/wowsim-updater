#!/bin/ash
set -eu
SIM_ROOT=$(CDPATH= cd -- "${1:-$(dirname -- "$0")}" && pwd)
. "$SIM_ROOT/flavor.sh"
resolve_flavor
init_sim_paths
mkdir -p "$SIM_STATE_DIR"

# flock releases the lock even if the updater is interrupted.
exec 9>"$SIM_STATE_DIR/update.lock"
flock -n 9 || exit 0
stage=
cleanup() { [ -z "$stage" ] || rm -rf -- "$stage"; }
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

start_sim() {
    if sim_running; then
        echo "$WOWSIM_FLAVOR: sim already running"
        return 0
    fi
    [ -x "$SIM_INSTALL_DIR/$SIM_BINARY" ] || return 1
    echo "$WOWSIM_FLAVOR: starting $SIM_BINARY"
    # Do not let the child retain the updater lock.
    "$SIM_INSTALL_DIR/$SIM_BINARY" -host 0.0.0.0:3333 9>&- &
    echo "$!" > "$SIM_PID_FILE"
    sleep 1
    sim_running
}

update_failed() {
    echo "$WOWSIM_FLAVOR: $1 (expected $SIM_ARCHIVE from $SIM_REPO)" >&2
    # Network failures must not prevent an installed sim from running.
    start_sim || exit 1
    exit 0
}

metadata=$(curl -fsSL "https://api.github.com/repos/$SIM_REPO/releases/latest") || update_failed "cannot fetch latest release; it may not be published yet"
remote_version=$(printf '%s' "$metadata" | jq -er '.tag_name | select(type == "string" and length > 0)') || update_failed "invalid release tag"
asset_url=$(printf '%s' "$metadata" | jq -er --arg name "$SIM_ARCHIVE" '[.assets[]? | select(.name == $name) | .browser_download_url | select(type == "string" and startswith("https://"))][0] // empty') || update_failed "release has no matching download"
current_version=$(cat "$SIM_INSTALL_DIR/current_version.txt" 2>/dev/null || true)

if [ "$current_version" = "$remote_version" ] && [ -x "$SIM_INSTALL_DIR/$SIM_BINARY" ]; then
    start_sim
    exit 0
fi

stage=$(mktemp -d "$SIM_STATE_DIR/staging.XXXXXX")
curl -fsSL "$asset_url" -o "$stage/$SIM_ARCHIVE" || update_failed "download failed"
unzip -q "$stage/$SIM_ARCHIVE" "$SIM_BINARY" -d "$stage" || update_failed "archive is corrupt or missing executable"
[ -f "$stage/$SIM_BINARY" ] && [ ! -L "$stage/$SIM_BINARY" ] || update_failed "archive is missing executable"
chmod +x "$stage/$SIM_BINARY"
rm "$stage/$SIM_ARCHIVE"
printf '%s\n' "$remote_version" > "$stage/current_version.txt"

ash "$SIM_ROOT/stop-sim.sh" "$SIM_ROOT"
backup="$SIM_STATE_DIR/previous"
rm -rf -- "$backup"
if [ -d "$SIM_INSTALL_DIR" ]; then mv "$SIM_INSTALL_DIR" "$backup"; fi
mv "$stage" "$SIM_INSTALL_DIR"
stage=
if start_sim; then
    rm -rf -- "$backup"
    echo "$WOWSIM_FLAVOR: updated to $remote_version"
else
    echo "$WOWSIM_FLAVOR: new executable failed to start; restoring previous installation" >&2
    rm -rf -- "$SIM_INSTALL_DIR"
    if [ -d "$backup" ]; then
        mv "$backup" "$SIM_INSTALL_DIR"
        start_sim || exit 1
    else
        exit 1
    fi
fi
