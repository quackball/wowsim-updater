#!/bin/ash
set -eu
SIM_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SIM_ROOT/flavor.sh"
resolve_flavor
# crond and its hourly updater inherit the validated flavor.
ash "$SIM_ROOT/update-sim.sh" "$SIM_ROOT"
exec crond -f
