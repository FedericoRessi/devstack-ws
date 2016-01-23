Workspace for running and testing your openstack code with Devstack and Vagrant.

## Goals

Run DevStack inside a virtual machine provided using Vagrant. 

The workspace works as a parent folder for projects supported
by devstack. It provides configuration files to build a virtual
machine and run devstack inside with repositories from workspace.
The workspace can handle continous integrations inside jenkins.

## Getting started

Before using it you should install project dependencies as pecified [here](docs/features/install-dependencies.md).

## Features
* [Deploy OpenStack](docs/features/deploy-openstack.md) repos to /opt/stack
* Provide VMs with [devstack dependencies](docs/features/devstack-dependencies.md)
* Network configuration (UNDOCUMENTED)
* Provide [proxy auto-configuration](docs/features/proxy-autoconf.md)
* Cache installation files on shared folders (UNDOCUMENTED)
* Run stack.sh in VM (UNDOCUMENTED)
* Organize log files into workspace sub-directory (UNDOCUMENTED)
* Gerrit trigger integration (UNDOCUMENTED)

## Planned features
* Support multiple [Linux distributions](docs/features/linux-distributions.md)
* Support offline mode with local mirrors: PLANNED
* Framework for vagrant based test cases: PLANNED
* Jenkins multi-step build: PLANNED
* Cloud VMs build: PLANNED
* Integrate with autoenv ([issue #1](https://github.com/FedericoRessi/devstack-ws/issues/1))
* Share files using NFS


## How it works
TODO: ([issue #8](https://github.com/FedericoRessi/devstack-ws/issues/8))
