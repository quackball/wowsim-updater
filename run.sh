#!/bin/bash

current_pid=$(docker ps -q --filter ancestor=wowsim)

if [ -n "$current_pid" ]; then
    docker stop $current_pid
fi

docker run --platform linux/amd64 -itd --rm -p 3333:3333 wowsim
