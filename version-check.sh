#!/bin/bash
set -eu
current_pid=$(docker ps -q --filter ancestor=wowsim)
if [ -n "$current_pid" ]; then
    docker exec --workdir /home/root $current_pid ash ./version.sh
else
    echo "wowsim not currently running"
fi
