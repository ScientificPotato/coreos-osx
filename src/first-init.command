#!/bin/bash

#  first-init.command
#

#
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source "${DIR}"/functions.sh

# get App's Resources folder
res_folder=$(cat ~/coreos-osx/.env/resouces_path)

# path to the bin folder where we store our binary files
export PATH=${HOME}/coreos-osx/bin:$PATH

echo " "
echo "Setting up CoreOS VM on OS X"

# add ssh key to *.toml files
sshkey

# add ssh key to Keychain
ssh-add -K ~/.ssh/id_rsa &>/dev/null

# save user password to Keychain
save_password
#

# Set release channel
release_channel

# create ROOT disk
create_data_disk

# Stop docker registry first just in case it was running
kill $(ps aux | grep "[r]egistry config.yml" | awk {'print $2'}) >/dev/null 2>&1 &
#
sleep 1

# Start docker registry
cd ~/coreos-osx/registry
echo " "
"${res_folder}"/docker_registry.sh start

# get password for sudo
my_password=$(security find-generic-password -wa coreos-osx-app)
# reset sudo
sudo -k > /dev/null 2>&1

# Start VM
cd ~/coreos-osx
echo " "
echo "Starting VM ..."
echo " "
echo -e "$my_password\n" | sudo -Sv > /dev/null 2>&1
#
sudo "${res_folder}"/bin/corectl load settings/core-01.toml 2>&1 | tee ~/coreos-osx/logs/first-init_vm_up.log
CHECK_VM_STATUS=$(cat ~/coreos-osx/logs/first-init_vm_up.log | grep "started")
#
if [[ "$CHECK_VM_STATUS" == "" ]]; then
    echo " "
    echo "VM have not booted, please check '~/coreos-osx/logs/first-init_vm_up.log' and report the problem !!! "
    echo " "
    pause 'Press [Enter] key to continue...'
    exit 0
else
    echo "VM successfully started !!!" >> ~/coreos-osx/logs/first-init_vm_up.log
fi

# check id /Users/homefolder is mounted, if not mount it
"${res_folder}"/bin/corectl ssh core-01 'source /etc/environment; if df -h | grep ${HOMEDIR}; then echo 0; else sudo systemctl restart ${HOMEDIR}; fi' > /dev/null 2>&1

# get VM IP
vm_ip=$("${res_folder}"/bin/corectl q -i core-01)
# save VM's IP
"${res_folder}"/bin/corectl q -i core-01 | tr -d "\n" > ~/coreos-osx/.env/ip_address
#

echo " "
# download latest versions of etcdctl, fleetctl and docker clients
download_osx_clients
#

# Set the environment variables
# docker daemon
export DOCKER_HOST=tcp://$vm_ip:2375

# set etcd endpoint
export ETCDCTL_PEERS=http://$vm_ip:2379
# wait till VM is ready
echo " "
echo "Waiting for VM to be ready..."
spin='-\|/'
i=0
until curl -o /dev/null http://$vm_ip:2379 >/dev/null 2>&1; do i=$(( (i+1) %4 )); printf "\r${spin:$i:1}"; sleep .1; done
#
sleep 2
echo " "
echo "etcdctl ls /:"
etcdctl --no-sync ls /
#

# set fleetctl endpoint and install fleet units
export FLEETCTL_TUNNEL=
export FLEETCTL_ENDPOINT=http://$vm_ip:2379
export FLEETCTL_DRIVER=etcd
export FLEETCTL_STRICT_HOST_KEY_CHECKING=false
echo " "
echo "fleetctl list-machines:"
fleetctl list-machines
echo " "
#
deploy_fleet_units
#

echo "Installation has finished, CoreOS VM is up and running !!!"
echo " "
echo "Assigned static IP for VM: $vm_ip"
echo " "
echo "Docker Registry is on: 192.168.64.1:5000 "
echo " "
echo "You can control this App via status bar icon... "
echo " "

#
cd ~/coreos-osx

# open bash shell
/bin/bash



