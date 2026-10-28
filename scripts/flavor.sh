#!/bin/sh
# Shared by the Bash launcher and Alpine ash scripts.
resolve_flavor() {
    WOWSIM_FLAVOR=${1:-${WOWSIM_FLAVOR:-forever}}
    case "$WOWSIM_FLAVOR" in
        forever|mop|cata|wotlk|classic|sod|tbc) SIM_REPO="wowsims/$WOWSIM_FLAVOR"; SIM_PREFIX="wowsim$WOWSIM_FLAVOR" ;;
        tbc-new) SIM_REPO=wowsims/tbc-new; SIM_PREFIX=wowsimtbc ;;
        *) echo "Unknown flavor: $WOWSIM_FLAVOR. Supported: forever mop cata wotlk classic sod tbc tbc-new" >&2; return 1 ;;
    esac
    SIM_BINARY="$SIM_PREFIX-amd64-linux"
    SIM_ARCHIVE="$SIM_BINARY.zip"
    export WOWSIM_FLAVOR
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
