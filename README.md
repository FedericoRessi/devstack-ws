Simple workspace for running code and tests on vagrant provisioned VM

## Goal

Prepare workspace toolset for working with DevStack and Vagrant.

The workspace works as a parent folder for projects supported
by devstack. It provides configuration files to build a virtual
machine to run devstack inside with repositories from workspace.
The workspace can handle continous integrations inside jenkins.


## Usage

TODO: ([issue #8](https://github.com/FedericoRessi/devstack-ws/issues/8))

## Implemented features
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
