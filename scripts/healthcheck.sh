#!/bin/ash
set -eu
SIM_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SIM_ROOT/flavor.sh"
resolve_flavor
# Routes follow the executable prefix, including /tbc/ for tbc-new.
curl -fsS "http://localhost:3333/${SIM_PREFIX#wowsim}/" --max-time 5 >/dev/null
