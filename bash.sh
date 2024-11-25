#!/bin/bash

current_pid=$(docker ps -q --filter ancestor=wowsim)

if [ -n "$current_pid" ]; then
    docker exec -it --workdir /home/root $current_pid /bin/ash -l
else
    echo "wowsim not currently running"
fi
