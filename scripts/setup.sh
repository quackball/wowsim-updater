#!/bin/ash
exec &> >(tee setup-wowsim.log)
set -x

echo "$HOME"
echo "CURRENT DIR: $PWD"

rm current_version.txt
touch current_version.txt
touch /root/.profile
echo "alias ls='ls -alF --color=auto'" >> /root/.profile

temp_cron_file=/tmp/update-sim-cron
cron_string="@daily /bin/ash $PWD/update-sim.sh $PWD"

echo "$cron_string"

crontab -l > $temp_cron_file

current_cron_string=$(/bin/sed -n '/update-sim.sh/p' $temp_cron_file)

echo $current_cron_string
if [ -n "$current_cron_string" ]; then
    echo "replacing current crontab"
    sed -i -r "s|$current_cron_string|$cron_string|g" $temp_cron_file
else
    echo "adding initial crontab"
    echo "$cron_string >> /home/root/update-sim.log 2>&1" >> $temp_cron_file
fi

crontab $temp_cron_file

crontab -l

chmod +x update-sim.sh

source update-sim.sh $PWD
