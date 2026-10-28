#!/bin/bash
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/scripts/flavor.sh"
if [ "${1:-}" = --help ] && [ "$#" -eq 1 ]; then
    echo "Usage: bash run.sh [flavor]"
    echo "Flavors: forever (default), mop, cata, wotlk, classic, sod, tbc, tbc-new"
    echo "Selection: argument > WOWSIM_FLAVOR > forever"
    echo "Waits for startup; WOWSIM_STARTUP_TIMEOUT sets the timeout in seconds (default: 180)."
    exit 0
fi
[ "$#" -le 1 ] || { echo "Usage: bash run.sh [flavor]" >&2; exit 1; }
resolve_flavor "${1:-}"
startup_timeout=${WOWSIM_STARTUP_TIMEOUT:-180}
case "$startup_timeout" in
    ''|*[!0-9]*|0) echo "WOWSIM_STARTUP_TIMEOUT must be a positive number of seconds" >&2; exit 1 ;;
esac
current_pid=$(docker ps -q --filter ancestor=wowsim)
if [ -n "$current_pid" ]; then
    docker stop $current_pid
    # Older containers used --rm and may already have disappeared.
    for container in $current_pid; do
        if docker inspect "$container" >/dev/null 2>&1; then
            docker rm "$container" >/dev/null
        fi
    done
fi

echo "Starting $WOWSIM_FLAVOR; waiting up to ${startup_timeout}s for the simulator..."
# Retain the container until startup has been checked so early failures keep logs.
container_id=$(docker run --platform linux/amd64 -d -p 3333:3333 -e "WOWSIM_FLAVOR=$WOWSIM_FLAVOR" wowsim)
deadline=$((SECONDS + 10#$startup_timeout))
while [ "$SECONDS" -lt "$deadline" ]; do
    state=$(docker inspect --format '{{.State.Status}}' "$container_id") || break
    [ "$state" = running ] || break
    if docker exec "$container_id" ash /home/root/healthcheck.sh >/dev/null 2>&1; then
        echo "$WOWSIM_FLAVOR is ready at http://localhost:3333/${SIM_PREFIX#wowsim}/"
        echo "Container: $container_id"
        echo "View logs: docker logs -f $container_id"
        exit 0
    fi
    sleep 1
done

echo "$WOWSIM_FLAVOR failed to become ready. Container startup logs:" >&2
docker logs "$container_id" >&2 || true
echo "Removing failed container $container_id" >&2
docker rm -f "$container_id" >/dev/null || true
exit 1
