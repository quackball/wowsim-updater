#!/bin/ash
exec &> >(tee stop-wowsim.log)
set -x

pgrep wowsim | xargs kill -9
