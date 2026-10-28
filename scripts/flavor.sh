#!/bin/sh
# Shared by the Bash launcher and Alpine ash scripts.
resolve_flavor() {
    WOWSIM_FLAVOR=${1:-${WOWSIM_FLAVOR:-forever}}
    flavor_config="${SIM_ROOT:-${script_dir:-.}/scripts}/flavors.csv"
    supported=
    while IFS=, read -r flavor repository binary_prefix; do
        [ "$flavor" != flavor ] || continue
        supported="$supported $flavor"
        if [ "$WOWSIM_FLAVOR" = "$flavor" ]; then
            SIM_REPO=$repository
            SIM_PREFIX=$binary_prefix
            SIM_BINARY="$SIM_PREFIX-amd64-linux"
            SIM_ARCHIVE="$SIM_BINARY.zip"
            export WOWSIM_FLAVOR
            return 0
        fi
    done < "$flavor_config"
    echo "Unknown flavor: $WOWSIM_FLAVOR. Supported:$supported" >&2
    return 1
}

init_sim_paths() {
    SIM_STATE_DIR="$SIM_ROOT/flavors/$WOWSIM_FLAVOR"
    SIM_INSTALL_DIR="$SIM_STATE_DIR/current"
    SIM_PID_FILE="$SIM_STATE_DIR/sim.pid"
}

sim_running() {
    [ -f "$SIM_PID_FILE" ] || return 1
    sim_pid=$(cat "$SIM_PID_FILE")
    case "$sim_pid" in ''|0|1|*[!0-9]*) return 1 ;; esac
    kill -0 "$sim_pid" 2>/dev/null || return 1
    # A dead child can remain a zombie until its parent reaps it.
    [ -r "/proc/$sim_pid/status" ] || return 1
    grep -q '^State:.*Z' "/proc/$sim_pid/status" && return 1
    tr '\000' '\n' < "/proc/$sim_pid/cmdline" | grep -Fxq "$SIM_INSTALL_DIR/$SIM_BINARY" || return 1
    return 0
}
