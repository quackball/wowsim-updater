#!/bin/ash
# set -x

if [[ -n "$1" ]]; then
    sim_pid="$1"
else
    sim_pid=$(ps aux | grep '[w]owsimcata' | awk '{print $1}')
fi

if [[ -n $sim_pid ]]; then 
    kill -1 $sim_pid
    
    while kill -0 $sim_pid; do
        sleep 1
    done
fi
