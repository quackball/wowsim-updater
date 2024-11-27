#!/bin/ash
# set -x

if [ -n "$1" ]; then
    cd $1
fi

touch current_version.txt

current_version=$(cat "current_version.txt")
remote_version=$(curl -L https://api.github.com/repos/wowsims/cata/releases/latest | jq .tag_name)

if [ -z $current_version ]; then
    current_version="temp"

    echo $current_version >> current_version.txt
fi

if [ "$current_version" != "$remote_version" ]; then
    wget -O wowsimcata-amd64-linux.zip https://github.com/wowsims/cata/releases/latest/download/wowsimcata-amd64-linux.zip

    unzip -o wowsimcata-amd64-linux.zip -d /home/root

    sed -i -r "s/$current_version/$remote_version/g" current_version.txt

    echo "Updated to version: $remote_version"

    sim_pid=$(ps aux | grep '[w]owsimcata' | awk '{print $1}')

    if [ -n "$sim_pid" ]; then
        echo "killing pid: $sim_pid"

        source stop-sim.sh "$sim_pid"
    fi

    echo "starting sim post update"
    ./wowsimcata-amd64-linux -host 0.0.0.0:3333 &
else
    sim_pid=$(ps aux | grep '[w]owsimcata' | awk '{print $1}')

    if [ -z $sim_pid ]; then
        echo "starting sim"

        ./wowsimcata-amd64-linux -host 0.0.0.0:3333 &
    else
        echo "sim already running"
    fi
fi
