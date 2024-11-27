#!/bin/ash
exec &> >(tee setup.log)
set -x

echo "alias ls='ls -alF --color=auto'" >> /root/.profile

chmod +x update-sim.sh

cp update-sim.sh /etc/periodic/daily/update-sim

source update-sim.sh $PWD
