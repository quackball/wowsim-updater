#!/bin/ash
set -eu
SIM_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SIM_ROOT/flavor.sh"
resolve_flavor
init_sim_paths
version=$(cat "$SIM_INSTALL_DIR/current_version.txt" 2>/dev/null || printf 'not installed')
printf '%s: %s\n' "$WOWSIM_FLAVOR" "$version"
