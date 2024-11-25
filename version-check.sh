#!/bin/bash

current_pid=$(docker ps -q --filter ancestor=wowsim)

if [ -n "$current_pid" ]; then
    docker exec --workdir /home/root $current_pid cat current_version.txt
else
    echo "wowsim not currently running"
fi
