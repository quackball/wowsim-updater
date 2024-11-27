#!/bin/ash

source update-sim.sh $PWD &
crond -f -l 2
