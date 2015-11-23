#!/bin/bash

CONF_DIR='/vagrant/etc'

# Import environment files from CONF_DIR
if [ -d "$CONF_DIR" ]; then
    sudo cp -fvR "$CONF_DIR"/* "/etc"
    # Reload environment
    if [ -r "/etc/profile" ]; then
        source "/etc/profile" || true
    fi
fi

source '/vagrant/scripts/distrib_properties.sh'

set -ex

# Add local IP addresses to /etc/hosts
HOST_IPS=$(ip addr | awk '/inet /{split($2, a, "/"); print a[1]}')
for IP in $HOST_IPS; do
    if ! grep "^$IP" "/etc/hosts"; then
        echo "$IP" "$(hostname)" | sudo bash -c 'cat >> "/etc/hosts"'
    fi
done

if is_ubuntu; then
    export DEBIAN_FRONTEND=noninteractive
    echo | sudo add-apt-repository cloud-archive:liberty || true
    sudo apt-get update -y
    sudo apt-get upgrade -y --force-yes
    install_package git ebtables bridge-utils dkms module-assistant\
        build-essential curl socat\
        libffi-dev libssl-dev libxml2-dev libxslt1-dev\
        python2.7 python2.7-dev python3 python3-dev python-setuptools
else
    sudo yum update -y
    sudo yum upgrade -y
    install_package git rsync bridge-utils unzip screen tar\
        libvirt libvirt-python automake gcc patch net-tools ntp socat\
        libffi-devel openssl-devel redhat-rpm-configrpm\
        python python-devel python3 python3-devel
fi

# Upgrade PIP and other Python packages
install_package python-pip || sudo easy_install -U pip
sudo pip install -U pip tox certifi pyopenssl ndg-httpsclient pyasn1

chown -fR vagrant.vagrant /home/vagrant

# Populate /opt/stack ---------------------------------------------------------
if ! cd "/opt/stack" 2> /dev/null; then
    sudo mkdir -p "/opt/stack"
    sudo chown "vagrant.vagrant" "/opt/stack"
    cd "/opt/stack"
fi

GIT_REPOS=$(ls -d /vagrant/*/.git 2> /dev/null || true)
GIT_REPOS=$(dirname $GIT_REPOS 2> /dev/null || true) 
if [[ $GIT_REPOS != "" ]]; then
    for REPO in $GIT_REPOS; do
        echo "Deploying $REPO..."
        if ! rsync -ua --delete --exclude-from="$REPO/.gitignore" "$REPO" "./"; then
            echo "Error deploying git repository $REPO to $(pwd)."
            exit 1
        fi
    done
fi

if ! [ -d "./devstack" ]; then
    git clone "https://git.openstack.org/openstack-dev/devstack" "devstack"
fi
cp -fv "/vagrant/local.conf" "/opt/stack/devstack"

echo $0': SUCCESS'
