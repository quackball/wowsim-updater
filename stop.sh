#!/bin/bash

current_pid=$(docker ps -q --filter ancestor=wowsim)

if [ -n "$current_pid" ]; then
    docker stop $current_pid
else
    echo "wowsim not currently running"
fi
