#!/bin/bash

CONF_DIR='/vagrant/etc'

set -ex

# Move git proxy wrapper
export GIT_PROXY_WRAPPER=${GIT_PROXY_WRAPPER:-"/home/vagrant/git_proxy_wrapper"}
if [ -x "$GIT_PROXY_WRAPPER" ]; then
    if sudo mv "$GIT_PROXY_WRAPPER" "/etc/default/git_proxy_wrapper"; then
        export GIT_PROXY_WRAPPER="/etc/default/git_proxy_wrapper"
    fi
fi

# Import environment files from CONF_DIR
if [ -d "$CONF_DIR" ]; then
    sudo cp -fvR "$CONF_DIR"/* "/etc"
    # Reload environment
    if [ -r "/etc/profile" ]; then
        set +ex; source "/etc/profile"; set -ex
    else
        echo "Unable to source '/etc/profile'!"
        exit 1
    fi
fi

set +x; source "/vagrant/scripts/distrib_properties.sh"; set -x

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
    install_package --force-yes git ebtables bridge-utils dkms module-assistant\
        build-essential curl socat fdutils linux-generic-lts-vivid\
        libffi-dev libssl-dev libxml2-dev libxslt1-dev\
        python2.7 python2.7-dev python3 python3-dev python-setuptools wget

    # Disable app armor
    if [ -r /lib/apparmor/functions ]; then
        sudo service apparmor stop
        sudo update-rc.d -f apparmor remove
        sudo apt-get remove -y apparmor apparmor-utils
    fi
else
    sudo $PACKAGER update -y 
    install_package git rsync bridge-utils unzip screen tar\
        libvirt libvirt-python automake gcc patch net-tools ntp socat\
        libffi-devel openssl-devel redhat-rpm-configrpm\
        python python-devel python3 python3-devel wget
fi

# Install PIP
wget https://bootstrap.pypa.io/get-pip.py
sudo python get-pip.py

# use vagrant cachier with pip-accel
PIP_ACCEL_DIR=/tmp/vagrant-cache/pip-accel
sudo mkdir -p $PIP_ACCEL_DIR/root $PIP_ACCEL_DIR/vagrant
sudo ln -sfn $PIP_ACCEL_DIR/root /var/cache/pip-accel
sudo ln -sfn $PIP_ACCEL_DIR/vagrant ~/.pip-accel
sudo pip install -U pip pip-accel 
sudo ln -sfn pip-accel /usr/local/bin/pip2.7
sudo pip-accel install -U tox certifi pyopenssl ndg-httpsclient pyasn1

sudo chown -fR vagrant.vagrant /home/vagrant

# Populate /opt/stack ---------------------------------------------------------
if ! cd "/opt/stack" 2> /dev/null; then
    sudo mkdir -p "/opt/stack"
    cd "/opt/stack"
fi

sudo chown "vagrant.vagrant" "."

# This is required by submodules
sudo rsync -ua /vagrant/.git .

GIT_REPOS=$(ls -d /vagrant/*/.git 2> /dev/null || true)
GIT_REPOS=$(dirname $GIT_REPOS 2> /dev/null || true) 
if [[ $GIT_REPOS != "" ]]; then
    for REPO in $GIT_REPOS; do
        echo "Deploying $REPO..."
        if ! rsync -ua --delete --exclude=.tox --exclude-from="$REPO/.gitignore" "$REPO" "./"; then
            echo "Error deploying git repository $REPO to $(pwd)."
            exit 1
        fi
    done
fi

if ! [ -d "./devstack" ]; then
    git clone "https://git.openstack.org/openstack-dev/devstack" "devstack"
fi

case $(hostname) in
    control* )
        cp -fv "/vagrant/control.local.conf"\
               "/opt/stack/devstack/local.conf";;
    compute* )
        cp -fv "/vagrant/compute.local.conf"\
               "/opt/stack/devstack/local.conf";;
esac

if is_ubuntu; then
    sudo apt-get autoremove -y
fi

echo $0': SUCCESS'
