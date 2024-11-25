#!/bin/ash
exec &> >(tee wowsim.log)
set -x

if [ -n "$1" ]; then
    echo switching to directory: $1
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
fi

sim_pid=$(pgrep wowsim)

if [ -n "$sim_pid" ]; then
    pgrep wowsim | xargs kill -9
fi

echo "starting server"

./wowsimcata-amd64-linux -host 0.0.0.0:3333
