#!/bin/bash

current_pid=$(docker ps -q --filter ancestor=wowsim)

if [ -n "$current_pid" ]; then
    docker stop $current_pid
    for container in $current_pid; do
        if docker inspect "$container" >/dev/null 2>&1; then
            docker rm "$container" >/dev/null
        fi
    done
else
    echo "wowsim not currently running"
fi
