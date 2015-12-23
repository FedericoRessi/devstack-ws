Simple workspace for running code and tests on vagrant provisioned VM

## Goal

Prepare workspace toolset for working with devstack and vagrant. 

## Usage

TODO: ([issue #8](https://github.com/FedericoRessi/devstack-ws/issues/8))

## Implemented features
* [Deploy OpenStack](docs/features/deploy-openstack.md) repos to /opt/stack
* Support multiple [Linux distributions](docs/features/linux-distributions.md)
* Provide VMs with [devstack dependencies](docs/features/devstack-dependencies.md)
* Network configuration (UNDOCUMENTED)
* Provide [proxy auto-confguration](docs/features/proxy-autoconf.md)
* Run stack.sh in VM (UNDOCUMENTED)
* Writes log files to workspace directory (UNDOCUMENTED)

## Planned features
* Integrate with autoenv ([issue #1](https://github.com/FedericoRessi/devstack-ws/issues/1))
* Run tox on vagrant: PLANNED
* Support GIT subrepos: PLANNED
* Run on jenkins: PLANNED
* Support offline mode with local mirrors: PLANNED
* Framework for vagrant based test cases: PLANNED
* Jenkins multi-step build: PLANNED
* Cloud VMs build: PLANNED
