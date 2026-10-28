#!/bin/ash
set -eu
SIM_ROOT=$(CDPATH= cd -- "${1:-$(dirname -- "$0")}" && pwd)
. "$SIM_ROOT/flavor.sh"
resolve_flavor
init_sim_paths
if sim_running; then
    kill -TERM "$sim_pid" 2>/dev/null || true
    attempts=0
    while sim_running; do
        attempts=$((attempts + 1))
        if [ "$attempts" -ge 10 ]; then
            kill -KILL "$sim_pid" 2>/dev/null || true
            break
        fi
        sleep 1
    done
fi
rm -f "$SIM_PID_FILE"
