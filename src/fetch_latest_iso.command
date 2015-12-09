#!/bin/bash

#  fetch latest iso
#
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source "${DIR}"/functions.sh

# path to the bin folder where we store our binary files
export PATH=${HOME}/coreos-osx/bin:$PATH

# get channel from the config file
CHANNEL=$(cat ~/coreos-osx/settings/core-01.toml | grep "channel =" | head -1 | cut -f2 -d"=" | sed -e 's/ "\(.*\)"/\1/')

echo " "
echo "Fetching lastest CoreOS $CHANNEL channel ISO ..."
echo " "
#
corectl pull --channel="$CHANNEL"
#
echo " "
echo "You need to reload your VM to be booted from the lastest version !!! "
echo " "
pause 'Press [Enter] key to continue...'
